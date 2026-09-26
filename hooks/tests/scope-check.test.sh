#!/bin/bash
# Fixture tests for scope-check.sh. Run: bash hooks/tests/scope-check.test.sh
# Each case writes the checklist, docs/oneloop-todos/TODO.md, of a scratch git repo and feeds
# the guard one edit event, then reads what it printed: `fix` when it pointed at the edit
# (context for Claude that says what to fix, no decision, so nothing blocks; 14.0.0, the user's
# words: "nothing should block file edits … auto-pilot mode with self-control", "hooks shall
# point and claude fixes raised problems"), `pass` for silence. The scope is the `scope:` of
# every `- [~]` line of the checklist, joined: an edit to a file none covers (by name, or by a
# folder it is under) is pointed at with that scope and the fix (put the file on the task line);
# one made while no line is in flight is pointed at with the fix (add or flip a line; and, while
# a root TODO.md exists and the checklist does not, git mv it there first). A `- [ ]` line is
# parked and counts for nothing, a ticked line too, and a TODO.md anywhere else, the root
# included, is not the checklist; backticks, bold marks and the closing parenthesis around the
# files are stripped, and an absolute path inside the repository counts by its relative form.
# The checklist and its archive themselves, files outside the repository, other tools and events
# and unreadable input are nothing to judge, and the guard never prints a decision.
# SCOPE_CHECK_SH points the test at another copy of the script, for a watched failure; the copy
# needs hook-input.sh and progress-log.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${SCOPE_CHECK_SH:-$here/../scope-check.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
P="$WORK/p"
TICK=$(printf '\140')
TODO="docs/oneloop-todos/TODO.md"

build_fixture() {
  mkdir -p "$P/src/util" "$P/src/cart" "$P/docs/oneloop-todos" "$WORK/elsewhere" || return 1
  git init -q "$P" && : > "$P/src/util/math.ts" && : > "$P/src/cart/summary.ts" && : > "$P/README.md" && : > "$WORK/elsewhere/x.ts"
}

# checklist <line>...: the checklist's whole content, one line per argument.
checklist() { printf '%s\n' "$@" > "$P/$TODO"; }

# event_json <tool> <path>: the edit event as Claude Code sends it.
event_json() {
  jq -cn --arg t "$1" --arg p "$2" --arg c "$P" \
    '{hook_event_name: "PreToolUse", tool_name: $t, cwd: $c, session_id: "s1",
      tool_input: (if $t == "NotebookEdit" then {notebook_path: $p} else {file_path: $p, new_string: "x"} end)}'
}

# decide <tool> <path>: `fix` for a pointer, `pass` for silence, a stray decision or anything
# else as it is; the whole output is kept in last.json for the field readers below.
decide() {
  out=$(event_json "$1" "$2" | bash "$SCRIPT")
  printf '%s' "$out" > "$WORK/last.json"
  if [ -z "$out" ]; then printf 'pass'; return; fi
  printf '%s' "$out" | jq -r '.hookSpecificOutput as $h | if $h.permissionDecision then "decision:" + $h.permissionDecision elif (($h.additionalContext // "") | contains("Fix it now:")) then "fix" else "unreadable" end'
}

# last <field>: one field of the last pointer's hookSpecificOutput.
last() { jq -r ".hookSpecificOutput.$1 // empty" "$WORK/last.json"; }

test_no_task_in_flight_is_pointed_at() {
  checklist "- [ ] a parked task (scope: src/util/math.ts)"
  assert_eq "a parked line counts for nothing" fix "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "the pointer is for PreToolUse" PreToolUse "$(last hookEventName)"
  assert_eq "and carries no decision, so nothing blocks" "" "$(last permissionDecision)"
  assert_contains "it says what to fix" "engineering law (the loop): no task in flight in docs/oneloop-todos/TODO.md. Fix it now: add ${TICK}- [~] <task> (scope: <files>)${TICK} to it, or flip its parked ${TICK}- [ ]${TICK} line for this work, then go on; nothing blocks this edit." "$(last additionalContext)"
  assert_missing "and, with no root TODO.md, says nothing of a move" "old home" "$(last additionalContext)"
  assert_contains "it is logged" " p | guard | scope | fix | src/util/math.ts | no task in flight" "$(tail -n 1 "$LOG")"
  checklist "- [x] a done task (scope: src/util/math.ts)"
  assert_eq "a ticked line counts for nothing" fix "$(decide Edit "$P/src/util/math.ts")"
  rm -f "$P/$TODO"
  assert_eq "no checklist at all" fix "$(decide Edit "$P/src/util/math.ts")"
  printf -- '- [~] an old task (scope: src/util/math.ts)\n' > "$P/TODO.md"
  assert_eq "an in-flight line in a root TODO.md, the old home, does not count" fix "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "and the fix starts with the move" "Fix it now: git mv the root TODO.md and its archive into docs/oneloop-todos/ (their old home), then add ${TICK}- [~] <task> (scope: <files>)${TICK} to it" "$(last additionalContext)"
  checklist "- [x] an earlier task"
  assert_eq "a checklist with no line in flight, beside a root TODO.md" fix "$(decide Edit "$P/src/util/math.ts")"
  assert_missing "and once the checklist exists the move is not mentioned" "old home" "$(last additionalContext)"
  rm -f "$P/TODO.md"
}

test_the_in_flight_lines_are_the_scope() {
  checklist "- [x] done (scope: README.md)" "- [~] rename runningSum (scope: src/util/math.ts)" "- [ ] parked (scope: src/cart/summary.ts)"
  assert_eq "the in-flight line's file passes" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "a Write to it passes too" pass "$(decide Write "$P/src/util/math.ts")"
  assert_eq "the parked line's file is pointed at" fix "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "with the file, the scope in flight and the fix" "src/cart/summary.ts is outside the scope of the task in flight (scope: src/util/math.ts). Fix it now: add src/cart/summary.ts to that task line in docs/oneloop-todos/TODO.md and restate the scope in one line, then go on; nothing blocks this edit." "$(last additionalContext)"
  assert_contains "and is logged as outside scope" " p | guard | scope | fix | src/cart/summary.ts | outside scope" "$(tail -n 1 "$LOG")"
  assert_eq "the ticked line's file is pointed at too" fix "$(decide Edit "$P/README.md")"
  checklist "- [~] first (scope: src/util/math.ts)" "- [~] second (scope: src/cart/summary.ts)"
  assert_eq "two lines in flight: the first one's file passes" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "and the second one's" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "a file on neither is pointed at" fix "$(decide Edit "$P/README.md")"
  assert_contains "with both scopes joined" "(scope: src/util/math.ts, src/cart/summary.ts)" "$(last additionalContext)"
  checklist "## Now" "- [~] two files (scope: src/util/math.ts, src/cart/summary.ts)" "" "## Later" "- [ ] parked (scope: README.md)"
  assert_eq "a line with two files covers the first" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "and the second" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "headings and blank lines change nothing" fix "$(decide Edit "$P/README.md")"
}

test_the_forms_a_scope_is_written_in() {
  checklist "- [~] tidy (scope: ${TICK}src/util/${TICK}, ${TICK}src/cart/summary.ts${TICK})"
  assert_eq "a file under a listed folder passes" pass "$(decide Write "$P/src/util/new.ts")"
  assert_eq "a listed file passes, backticks stripped" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "a file outside both is pointed at" fix "$(decide Edit "$P/README.md")"
  assert_contains "with the scope as written, backticks gone" "(scope: src/util/, src/cart/summary.ts)" "$(last additionalContext)"
  checklist "- [~] tidy (scope: src/cart)"
  assert_eq "a folder without its slash covers its files" pass "$(decide Edit "$P/src/cart/summary.ts")"
  checklist "- [~] tidy (scope: $P/src/util/math.ts)"
  assert_eq "an absolute path inside the repository counts by its relative form" pass "$(decide Edit "$P/src/util/math.ts")"
  checklist "- [~] **tidy** (scope: **src/util/math.ts**)"
  assert_eq "bold marks are stripped" pass "$(decide Edit "$P/src/util/math.ts")"
  checklist "- [~] tidy (scope: app/(shop)/page.tsx)"
  mkdir -p "$P/app/(shop)"
  assert_eq "a path with parentheses keeps them" pass "$(decide Write "$P/app/(shop)/page.tsx")"
  checklist "- [~] tidy, scope: src/util/math.ts"
  assert_eq "a scope without parentheses is read too" pass "$(decide Edit "$P/src/util/math.ts")"
}

test_the_checklist_itself_and_files_outside_are_not_judged() {
  checklist "- [~] t (scope: src/util/math.ts)"
  assert_eq "the checklist itself is never judged" pass "$(decide Write "$P/$TODO")"
  assert_eq "nor is its archive" pass "$(decide Write "$P/docs/oneloop-todos/TODO.archive.md")"
  assert_eq "a root TODO.md is judged like any other file" fix "$(decide Write "$P/TODO.md")"
  assert_eq "and so is a TODO.md in another folder" fix "$(decide Write "$P/src/TODO.md")"
  rm -f "$P/$TODO"
  assert_eq "writing the checklist when there is none passes" pass "$(decide Write "$P/$TODO")"
  before=$(wc -l < "$LOG" | tr -d ' ')
  assert_eq "a file in a folder with no repository passes" pass "$(decide Edit "$WORK/elsewhere/x.ts")"
  assert_eq "and logs nothing" "$before" "$(wc -l < "$LOG" | tr -d ' ')"
}

test_a_new_file_in_a_new_folder_is_judged_by_its_repository() {
  checklist "- [~] t (scope: src/util/math.ts)"
  assert_eq "a Write into a folder that does not exist yet is judged" fix "$(decide Write "$P/src/new/deep/thing.ts")"
  assert_contains "by its path in the repository" "src/new/deep/thing.ts is outside the scope of the task in flight" "$(last additionalContext)"
  assert_eq "a NotebookEdit is judged by its notebook path" fix "$(decide NotebookEdit "$P/src/cart/notes.ipynb")"
}

test_other_tools_events_and_bad_input() {
  out=$(jq -cn --arg c "$P" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $c, tool_input: {command: "ls"}}' | bash "$SCRIPT")
  assert_eq "Bash is not judged here" "" "$out"
  out=$(jq -cn --arg c "$P" --arg p "$P/src/cart/summary.ts" '{hook_event_name: "PostToolUse", tool_name: "Edit", cwd: $c, tool_input: {file_path: $p}}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  out=$(jq -cn --arg c "$P" '{hook_event_name: "PreToolUse", tool_name: "Edit", cwd: $c, tool_input: {}}' | bash "$SCRIPT")
  assert_eq "an edit with no path prints nothing" "" "$out"
  assert_missing "the log never says ask" "| ask |" "$(cat "$LOG")"
  assert_missing "nor deny" "| deny |" "$(cat "$LOG")"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_no_task_in_flight_is_pointed_at
test_the_in_flight_lines_are_the_scope
test_the_forms_a_scope_is_written_in
test_the_checklist_itself_and_files_outside_are_not_judged
test_a_new_file_in_a_new_folder_is_judged_by_its_repository
test_other_tools_events_and_bad_input
report
