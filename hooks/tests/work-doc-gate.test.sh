#!/bin/bash
# Fixture tests for work-doc-gate.sh. Run: bash hooks/tests/work-doc-gate.test.sh
# WORK_DOC_GATE_SH points the test at another copy of the script, for a watched failure; the
# copy needs hook-input.sh, progress-log.sh and path-kind.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${WORK_DOC_GATE_SH:-$here/../work-doc-gate.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
REPO="$WORK/repo"
mkdir -p "$REPO/docs/work/done" "$REPO/src"
git -C "$REPO" init -q 2>/dev/null

# edit <path>: what the gate answers when that path is about to be edited.
edit() {
  jq -cn --arg p "$1" --arg c "$REPO" '{hook_event_name:"PreToolUse",tool_name:"Edit",cwd:$c,tool_input:{file_path:$p,old_string:"a",new_string:"b"}}' | bash "$SCRIPT"
}

# doc <ledger item> <backlog block> <updates block>: writes the one live work-doc.
doc() {
  { printf -- '---\nstatus: implementing\n---\n\n## 0. Phase ledger\n\n'
    printf -- '- [x] 1  Phase 1. Clarify\n%s\n\n## 5. Sprint Backlog\n\n' "$1"
    printf -- '%s\n\n## 6. Daily Updates\n\n%s\n' "$2" "$3"
  } > "$REPO/docs/work/2026-09-20-a-task.md"
}

OPEN3='- [>] 4  Phase 3. Implement'
OPEN2='- [>] 2  Phase 2. Plan + gate'
# The backlog's file and verify fields are in backticks in the template (7.2), and the tick is
# built rather than typed so the fixture keeps the real shape with no lint directive.
tick=$(printf '\140')
task() { printf -- '- [%s] **%s**, %s: does a thing. Files: %s%s%s. -> verify: %snpm test%s' "$1" "$2" "$3" "$tick" "$4" "$tick" "$tick" "$tick"; }
T1DONE=$(task x T1 first src/a.ts)
T2RUN=$(task '>' T2 second src/b.ts)
T2OPEN=$(task ' ' T2 second src/b.ts)
T3RUN=$(task '>' T3 third src/c.ts)
WROTE1='### T1 (first, done 2026-09-20 10:00)

- **Notes:** it landed.'

test_a_doc_that_agrees_lets_the_edit_through() {
  doc "$OPEN3" "$T1DONE
$T2RUN" "$WROTE1"
  assert_eq "the open phase writes code, the task is next and the ticked one is written up" "" "$(edit "$REPO/src/b.ts")"
}

test_no_live_work_doc_is_never_gated() {
  rm -f "$REPO"/docs/work/*.md
  assert_eq "quick mode and a repo with no work-doc pass silently" "" "$(edit "$REPO/src/b.ts")"
  printf -- '# archived\n' > "$REPO/docs/work/done/2026-09-01-old.md"
  assert_eq "an archived doc is not a live one" "" "$(edit "$REPO/src/b.ts")"
}

test_prose_is_never_gated() {
  doc "$OPEN2" "$T2OPEN" ""
  assert_eq "the work-doc itself stays editable" "" "$(edit "$REPO/docs/work/2026-09-20-a-task.md")"
  assert_eq "the README stays editable" "" "$(edit "$REPO/README.md")"
}

test_a_phase_that_does_not_write_code_refuses() {
  doc "$OPEN2" "$T2OPEN" ""
  out=$(edit "$REPO/src/b.ts")
  assert_contains "the refusal is a permission decision" '"permissionDecision":"deny"' "$out"
  assert_contains "it names the open phase" "Phase 2. Plan + gate" "$out"
  assert_contains "it says where code may land" "Code lands in Phase 3" "$out"
  assert_contains "it is logged" "gate | work-doc | deny | wrong-phase" "$(cat "$LOG" 2>/dev/null)"
}

test_an_out_of_order_task_refuses() {
  doc "$OPEN3" "$T2OPEN
$T3RUN" ""
  out=$(edit "$REPO/src/c.ts")
  assert_contains "a task taken while an earlier one waits is refused" "is still waiting" "$out"
  assert_contains "and it names the task" "T3, third" "$out"
}

# Independent stages go to their builders in one message (5.5), so several tasks may run at
# once; what the order rule forbids is a later task starting while an earlier one waits.
test_parallel_tasks_at_the_front_are_allowed() {
  doc "$OPEN3" "$T2RUN
$T3RUN" ""
  assert_eq "two tasks in progress, both at the front, pass" "" "$(edit "$REPO/src/c.ts")"
}

test_a_tick_with_nothing_written_refuses() {
  doc "$OPEN3" "$T1DONE
$T2RUN" ""
  out=$(edit "$REPO/src/b.ts")
  assert_contains "a ticked task with no Daily Updates entry is refused" "Task T1 is ticked" "$out"
  assert_contains "and it cites the law" "no tick at all (1.4)" "$out"
}

test_a_ledger_that_says_nothing_refuses() {
  doc '- [ ] 4  Phase 3. Implement' "$T2RUN" ""
  assert_contains "no phase in progress is refused" "is in progress" "$(edit "$REPO/src/b.ts")"
  doc "$OPEN3
$OPEN2" "$T2RUN" ""
  assert_contains "two phases in progress are refused" "items in progress" "$(edit "$REPO/src/b.ts")"
  printf -- '# no ledger at all\n' > "$REPO/docs/work/2026-09-20-a-task.md"
  assert_contains "a doc with no phase ledger is refused" "has no phase ledger" "$(edit "$REPO/src/b.ts")"
}

test_two_live_docs_refuse() {
  doc "$OPEN3" "$T2RUN" ""
  cp "$REPO/docs/work/2026-09-20-a-task.md" "$REPO/docs/work/2026-09-20-b-task.md"
  assert_contains "a task has exactly one map" "live work-docs" "$(edit "$REPO/src/b.ts")"
  rm -f "$REPO/docs/work/2026-09-20-b-task.md"
}

test_other_events_and_tools_are_ignored() {
  doc "$OPEN2" "$T2OPEN" ""
  out=$(jq -cn --arg c "$REPO" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$c,tool_input:{command:"ls"}}' | bash "$SCRIPT")
  assert_eq "the shell is not judged here" "" "$out"
  out=$(jq -cn --arg c "$REPO" --arg p "$REPO/src/b.ts" '{hook_event_name:"PostToolUse",tool_name:"Edit",cwd:$c,tool_input:{file_path:$p}}' | bash "$SCRIPT")
  assert_eq "only PreToolUse is judged" "" "$out"
  assert_eq "broken input is nothing to judge" "" "$(printf 'not json' | bash "$SCRIPT")"
}

test_a_doc_that_agrees_lets_the_edit_through
test_no_live_work_doc_is_never_gated
test_prose_is_never_gated
test_a_phase_that_does_not_write_code_refuses
test_an_out_of_order_task_refuses
test_parallel_tasks_at_the_front_are_allowed
test_a_tick_with_nothing_written_refuses
test_a_ledger_that_says_nothing_refuses
test_two_live_docs_refuse
test_other_events_and_tools_are_ignored
report
