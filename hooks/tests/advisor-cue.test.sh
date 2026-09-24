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
# 700 until 4.2.0 added the logic-first gate, at the user's approved cost of about 60 tokens.
CUE_BYTE_CAP=900

# submit <prompt>: what the hook prints for a prompt submission.
submit() {
  jq -cn --arg p "$1" '{hook_event_name:"UserPromptSubmit",prompt:$p,cwd:"/tmp/proj",session_id:"s1"}' | bash "$SCRIPT"
}

# ref_path <output>: the protocol path the cue ends on.
ref_path() { printf '%s\n' "$1" | sed -E 's/.*Protocol: //'; }

test_every_prompt_carries_the_rule() {
  out=$(submit "fix the login bug")
  assert_contains "names itself" "engineering-rules advisor cue." "$out"
  assert_contains "keys on the tool list" "When your tools include an advisor" "$out"
  assert_contains "names the decision moments" "before you settle an approach or a plan" "$out"
  assert_contains "covers the recommendation to the user" "rank the options you put to the user" "$out"
  assert_contains "covers the irreversible move" "do anything hard to undo" "$out"
  assert_contains "covers the claim of done" "or call anything done" "$out"
  assert_contains "asks for the decision to be stated first" "State the decision, its options and your evidence first" "$out"
  assert_contains "ranks the answer under the evidence" "a report, never proof" "$out"
  assert_contains "keeps a session without one working" "No advisor in the tool list is not an error" "$out"
  assert_contains "forbids a verdict for a call never made" "never write a verdict for a call you did not make" "$out"
  assert_contains "carries the logic-first gate" "Logic first (law 1.4): before changing anything for a new task, explain it with the demystify skill and wait for the user's yes" "$out"
  assert_contains "a complete-sounding ask is not a yes" "a detailed or fixed ask, or one that says to commit when done, is not a yes" "$out"
  count=$((count + 1))
  bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
  if [ "$bytes" -le "$CUE_BYTE_CAP" ]; then printf 'ok   the cue stays under %s bytes (%s)\n' "$CUE_BYTE_CAP" "$bytes"
  else printf 'FAIL the cue is %s bytes, over the %s it costs every prompt\n' "$bytes" "$CUE_BYTE_CAP"; failures=$((failures + 1)); fi
}

test_a_short_prompt_carries_it_too() {
  assert_contains "a one-word prompt gets the same cue" "engineering-rules advisor cue." "$(submit cont)"
  assert_eq "the cue is one line" "1" "$(submit cont | grep -c .)"
}

test_the_path_it_names_is_the_protocol() {
  path=$(ref_path "$(submit hello)")
  if [ -f "$path" ]; then found=exists; else found="missing: $path"; fi
  assert_contains "the path it names is a real file" "exists" "$found"
  case "$path" in /*) shape=absolute ;; *) shape="relative: $path" ;; esac
  assert_contains "and an absolute one" "absolute" "$shape"
  assert_contains "and it is the advisor protocol" "5.7-the-advisor.md" "$path"
  out=$(jq -cn '{hook_event_name:"UserPromptSubmit",prompt:"hi"}' | ENGINEERING_RULES_HOME=/opt/er bash "$SCRIPT")
  assert_contains "the home variable decides the path" "/opt/er/references/" "$out"
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
test_the_path_it_names_is_the_protocol
test_other_events_and_bad_input_print_nothing
test_it_never_refuses_a_prompt
report
