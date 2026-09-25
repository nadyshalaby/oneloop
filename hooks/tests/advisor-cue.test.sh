#!/bin/bash
# Fixture tests for advisor-cue.sh. Run: bash hooks/tests/advisor-cue.test.sh
# ADVISOR_CUE_SH points the test at another copy of the script, for a watched failure; the copy
# needs hook-input.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${ADVISOR_CUE_SH:-$here/../advisor-cue.sh}"
# The cue is printed into every prompt of every session, so its size is part of its contract.
# 900 from 4.2.0 (the logic-first gate added) until 9.2.0 cut it to one line.
CUE_BYTE_CAP=320

# submit <prompt>: what the hook prints for a prompt submission.
submit() {
  jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:"/tmp/proj",session_id:"s1"}' | bash "$SCRIPT"
}

test_every_prompt_carries_the_rule() {
  out=$(submit "fix the login bug")
  assert_contains "names itself and the rule it speaks for" "engineering-rules advisor cue (law 1.4):" "$out"
  assert_contains "carries the logic-first gate" "logic first: explain a new task's logic (the explain skill) and get the user's yes before changing anything" "$out"
  assert_contains "a complete-sounding ask is not a yes" 'a detailed or fixed ask, or "commit when done", is not a yes' "$out"
  assert_contains "names the advisor's moments" "Advisor (when listed) before a plan, ranked options, anything hard to undo, or done." "$out"
  count=$((count + 1))
  bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
  if [ "$bytes" -le "$CUE_BYTE_CAP" ]; then printf 'ok   the cue stays under %s bytes (%s)\n' "$CUE_BYTE_CAP" "$bytes"
  else printf 'FAIL the cue is %s bytes, over the %s it costs every prompt\n' "$bytes" "$CUE_BYTE_CAP"; failures=$((failures + 1)); fi
}

test_a_short_prompt_carries_it_too() {
  assert_contains "a one-word prompt gets the same cue" "engineering-rules advisor cue" "$(submit cont)"
  assert_eq "the cue is one line" "1" "$(submit cont | grep -c .)"
}

test_other_events_and_bad_input_print_nothing() {
  out=$(jq -cn '{hook_event_name:"Stop",cwd:"/tmp/proj"}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
  out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit"}' | bash "$SCRIPT")
  assert_eq "a tool event prints nothing" "" "$out"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints nothing" "advisor cue" "$out"
}

test_it_never_refuses_a_prompt() {
  submit "deploy to production now" > /dev/null 2>&1
  assert_eq "a prompt submission always exits 0" "0" "$?"
}

test_every_prompt_carries_the_rule
test_a_short_prompt_carries_it_too
test_other_events_and_bad_input_print_nothing
test_it_never_refuses_a_prompt
report
