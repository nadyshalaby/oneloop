#!/bin/bash
# Fixture tests for re-anchor.sh. Run: bash hooks/tests/re-anchor.test.sh
# After a compaction or a resume the hook prints three lines: read the law from disk, read the
# code rules before writing code, and resume the loop at the step it was in with nothing from
# before the loss counting as proof. It reads no transcript and keeps no position (10.0.0: the
# phase ledger and the work-doc went with the one loop). RE_ANCHOR_SH points the test at
# another copy of the script, for a watched failure; the copy needs hook-input.sh and
# progress-log.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${RE_ANCHOR_SH:-$here/../re-anchor.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"

# start <how_started>: what the hook prints for that session start.
start() {
  jq -cn --arg h "$1" '{hook_event_name:"SessionStart",how_started:$h,cwd:"/tmp/proj",transcript_path:"/nonexistent/t.jsonl"}' | bash "$SCRIPT"
}

# nth <n> <output>: one line of it.
nth() { printf '%s\n' "$2" | sed -n "${1}p"; }

# law_path <output>: the path the first line tells Claude to read.
law_path() { nth 1 "$1" | sed -E 's/.*before the next step: //'; }

test_compact_prints_the_three_lines() {
  out=$(start compact)
  assert_eq "exactly three lines" "3" "$(start compact | wc -l | tr -d ' ')"
  assert_contains "the first names the event" "engineering-rules re-anchor (context was compacted)" "$(nth 1 "$out")"
  assert_contains "and says a summary is not the law" "A summary of the law is not the law" "$(nth 1 "$out")"
  path=$(law_path "$out")
  if [ -f "$path" ]; then found=exists; else found="missing: $path"; fi
  assert_contains "the law path it names is a real file" "exists" "$found"
  case "$path" in /*) shape=absolute ;; *) shape="relative: $path" ;; esac
  assert_contains "and an absolute one" "absolute" "$shape"
  assert_eq "the second names the code rules in the config dir" "The code rules are part of it: before writing code, read them from disk unless they are verbatim in your context: $WORK/config/rules/engineering-code.md" "$(nth 2 "$out")"
  assert_eq "the third resumes the loop, with no proof carried over" "A task that was in flight resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof." "$(nth 3 "$out")"
  assert_missing "no ledger position is looked for" "ledger" "$out"
  assert_missing "and no work-doc" "work-doc" "$out"
  assert_contains "is logged" " proj | anchor | compact" "$(tail -n 1 "$LOG")"
}

test_resume() {
  out=$(start resume)
  assert_contains "names the event" "engineering-rules re-anchor (session resumed)" "$(nth 1 "$out")"
  assert_eq "the same three lines" "3" "$(start resume | wc -l | tr -d ' ')"
  assert_contains "is logged" " proj | anchor | resume" "$(tail -n 1 "$LOG")"
}

test_other_starts_and_bad_input_print_nothing() {
  assert_eq "a fresh start prints nothing" "" "$(start startup)"
  assert_eq "a cleared session prints nothing" "" "$(start clear)"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints nothing" "re-anchor" "$out"
  out=$(jq -cn '{hook_event_name:"Stop",cwd:"/tmp/proj"}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
}

test_source_field_and_the_home_variable() {
  out=$(jq -cn '{hook_event_name:"SessionStart",source:"resume",cwd:"/tmp/proj"}' | bash "$SCRIPT")
  assert_contains "the older source field still starts it" "(session resumed)" "$out"
  out=$(jq -cn '{hook_event_name:"SessionStart",how_started:"compact",cwd:"/tmp/proj"}' | ENGINEERING_RULES_HOME=/opt/er bash "$SCRIPT")
  assert_contains "the home variable decides the path" "/opt/er/law/engineering-law.md" "$out"
}

test_compact_prints_the_three_lines
test_resume
test_other_starts_and_bad_input_print_nothing
test_source_field_and_the_home_variable
report
