#!/bin/bash
# Fixture tests for loop-reminder.sh. Run: bash hooks/tests/loop-reminder.test.sh
# The reminder is the one line the law puts into every prompt (10.0.0, the user's words: "exactly
# one line"): it is that line, byte for byte, once, on UserPromptSubmit, and nothing on anything
# else. LOOP_REMINDER_SH points the test at another copy of the script, for a watched failure;
# the copy needs hook-input.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${LOOP_REMINDER_SH:-$here/../loop-reminder.sh}"
LINE='one loop · auto-pilot: a guard points, you fix · proof required · ask only a clarification or a critical logic change'

# run_event <event>: what the hook prints for that event.
run_event() {
  jq -cn --arg e "$1" '{hook_event_name:$e,cwd:"/tmp/proj",prompt:"rename x to y"}' | bash "$SCRIPT"
}

test_exactly_one_line_per_prompt() {
  out=$(run_event UserPromptSubmit)
  assert_eq "the reminder is the law's line, byte for byte" "$LINE" "$out"
  assert_eq "and exactly one line" "1" "$(run_event UserPromptSubmit | wc -l | tr -d ' ')"
  assert_eq "three separators, so four rules" "3" "$(printf '%s' "$out" | grep -oF '·' | wc -l | tr -d ' ')"
}

test_nothing_else_prints() {
  assert_eq "another event prints nothing" "" "$(run_event Stop)"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  out=$(printf '' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "empty stdin exits 0 with no output" "exit=0" "$out"
  mkdir -p "$WORK/nobin"
  out=$(jq -cn '{hook_event_name:"UserPromptSubmit"}' | env PATH="$WORK/nobin" /bin/bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "no jq: exit 0 with no output" "exit=0" "$out"
}

# The checks can fail: a copy that prints a second line is caught by the count, and a copy
# with one word changed by the byte match.
test_a_changed_copy_is_named() {
  mkdir -p "$WORK/copy"; cp "$here/../hook-input.sh" "$WORK/copy/"
  sed 's/^exit 0$/printf "%s\\n" "and a second line"; exit 0/' "$SCRIPT" > "$WORK/copy/loop-reminder.sh"
  lines=$(jq -cn '{hook_event_name:"UserPromptSubmit"}' | bash "$WORK/copy/loop-reminder.sh" | wc -l | tr -d ' ')
  assert_eq "a two-line copy is caught by the count" "2" "$lines"
  sed 's/proof required/proof optional/' "$SCRIPT" > "$WORK/copy/loop-reminder.sh"
  out=$(jq -cn '{hook_event_name:"UserPromptSubmit"}' | bash "$WORK/copy/loop-reminder.sh")
  if [ "$out" = "$LINE" ]; then verdict=same; else verdict=differ; fi
  assert_eq "a changed word is caught by the byte match" differ "$verdict"
}

test_exactly_one_line_per_prompt
test_nothing_else_prints
test_a_changed_copy_is_named
report
