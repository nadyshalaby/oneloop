#!/bin/bash
# Fixture tests for risk-zone.sh. Run: bash hooks/tests/risk-zone.test.sh
# Each case feeds the guard one edit event against a scratch git repo and reads the decision:
# the first edit to a risk-zone path in a session is a permission prompt (`ask`) naming the
# matched word; an edit that went through (PostToolUse) is recorded, so the next one to that
# file in the same session passes; a denied one is asked about again; another session asks
# afresh; a path outside the zones, another tool, another event or unreadable input prints
# nothing. The regex comes from settings/loop.json unless the repo's CLAUDE.md sets its own
# `risk_regex:` line. RISK_ZONE_SH points the test at another copy of the script, for a watched
# failure; the copy needs hook-input.sh, progress-log.sh and path-kind.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${RISK_ZONE_SH:-$here/../risk-zone.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config" TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"
LOG="$WORK/config/progress.log"
P="$WORK/p"
TICK=$(printf '\140')

build_fixture() {
  mkdir -p "$P/src/auth" "$P/src/ui" "$P/.github/workflows" "$P/infra" || return 1
  git init -q "$P" && : > "$P/README.md" && git -C "$P" add README.md \
    && git -C "$P" -c user.name=t -c user.email=t@example.com commit -q -m base || return 1
  : > "$P/src/auth/login.ts"; : > "$P/src/ui/Button.tsx"
}

# event_json <event> <tool> <path> <session>: the event as Claude Code sends it.
event_json() {
  jq -cn --arg e "$1" --arg t "$2" --arg p "$3" --arg s "$4" --arg c "$P" \
    'if $t == "NotebookEdit" then {hook_event_name:$e,tool_name:$t,cwd:$c,session_id:$s,tool_input:{notebook_path:$p,new_source:"x"}}
     else {hook_event_name:$e,tool_name:$t,cwd:$c,session_id:$s,tool_input:{file_path:$p,old_string:"a",new_string:"b"}} end'
}

# decide <json>: `ask` for a prompt, `pass` for silence, the raw decision otherwise; the whole
# output is kept in last.json for the field readers below.
decide() {
  out=$(printf '%s' "$1" | bash "$SCRIPT")
  printf '%s' "$out" > "$WORK/last.json"
  if [ -z "$out" ]; then printf 'pass'; return; fi
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unreadable"'
}

# last <field>: one field of the last decision's hookSpecificOutput.
last() { jq -r ".hookSpecificOutput.$1 // empty" "$WORK/last.json"; }

pre()  { decide "$(event_json PreToolUse "$1" "$2" "$3")"; }
post() { event_json PostToolUse "$1" "$2" "$3" | bash "$SCRIPT"; }

test_first_edit_asks_and_names_the_word() {
  assert_eq "the first edit to an auth path asks" ask "$(pre Edit "$P/src/auth/login.ts" s1)"
  assert_eq "the decision is for PreToolUse" PreToolUse "$(last hookEventName)"
  assert_contains "the reason names the path and the word" "src/auth/login.ts is a risk zone (its path matches ${TICK}auth${TICK})" "$(last permissionDecisionReason)"
  assert_contains "and says it is the first edit" "This is the first edit to it in this session" "$(last permissionDecisionReason)"
  assert_contains "the context tells Claude the approval is the yes" "the user is being asked to approve this first edit, which is the yes the law requires" "$(last additionalContext)"
  assert_contains "it is logged" " p | guard | risk | ask | src/auth/login.ts | matches auth" "$(tail -n 1 "$LOG")"
}

test_a_denied_edit_asks_again_and_one_that_went_through_does_not() {
  assert_eq "asked again while no edit went through" ask "$(pre Edit "$P/src/auth/login.ts" s1)"
  post Edit "$P/src/auth/login.ts" s1
  assert_contains "an edit that went through is logged" " p | guard | risk | edited | src/auth/login.ts" "$(tail -n 1 "$LOG")"
  assert_eq "the next edit in the same session passes" pass "$(pre Edit "$P/src/auth/login.ts" s1)"
  assert_eq "a Write to the same file passes too" pass "$(pre Write "$P/src/auth/login.ts" s1)"
  assert_eq "another session asks afresh" ask "$(pre Edit "$P/src/auth/login.ts" s2)"
  assert_eq "another risk file in the recorded session still asks" ask "$(pre Edit "$P/infra/main.tf" s1)"
}

test_every_edit_tool_and_only_those() {
  assert_eq "Write asks" ask "$(pre Write "$P/.env" s3)"
  assert_eq "MultiEdit asks" ask "$(pre MultiEdit "$P/Dockerfile" s3)"
  assert_eq "NotebookEdit asks on its notebook path" ask "$(pre NotebookEdit "$P/deploy/notes.ipynb" s3)"
  out=$(jq -cn --arg c "$P" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$c,session_id:"s3",tool_input:{command:"rm -rf infra"}}' | bash "$SCRIPT")
  assert_eq "Bash is not judged here" "" "$out"
  out=$(jq -cn --arg c "$P" --arg p "$P/src/auth/login.ts" '{hook_event_name:"Stop",tool_name:"Edit",cwd:$c,session_id:"s3",tool_input:{file_path:$p}}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
}

test_paths_outside_the_zones_pass() {
  before=$(wc -l < "$LOG" | tr -d ' ')
  assert_eq "a component passes" pass "$(pre Edit "$P/src/ui/Button.tsx" s4)"
  assert_eq "a README passes" pass "$(pre Write "$P/README.md" s4)"
  assert_eq "and nothing is logged for them" "$before" "$(wc -l < "$LOG" | tr -d ' ')"
}

test_the_matched_word_is_the_first_alternative_that_matches() {
  assert_eq "a payment session path asks" ask "$(pre Edit "$P/src/payment/session.ts" s5)"
  assert_contains "and the word is the regex's first match, in its order" "matches ${TICK}session${TICK}" "$(last permissionDecisionReason)"
  assert_eq "a workflow file asks" ask "$(pre Edit "$P/.github/workflows/ci.yml" s5)"
  assert_contains "with its own word" "matches ${TICK}\\.github/workflows${TICK}" "$(last permissionDecisionReason)"
}

test_the_map_overrides_the_default_regex() {
  printf '# map\n- lint: none\nrisk_regex: ui/\n' > "$P/CLAUDE.md"
  assert_eq "a path the map's regex names asks" ask "$(pre Edit "$P/src/ui/Button.tsx" s6)"
  assert_contains "with the map's word" "matches ${TICK}ui/${TICK}" "$(last permissionDecisionReason)"
  assert_eq "a default zone the map left out passes" pass "$(pre Edit "$P/src/auth/login.ts" s6)"
  rm "$P/CLAUDE.md"
}

test_the_config_is_the_default_and_no_regex_is_silence() {
  mkdir -p "$WORK/er/settings"
  printf '{"risk_regex":"ui/"}\n' > "$WORK/er/settings/loop.json"
  out=$(event_json PreToolUse Edit "$P/src/ui/Button.tsx" s7 | ONELOOP_HOME="$WORK/er" bash "$SCRIPT")
  assert_contains "the regex comes from the home's loop.json" '"permissionDecision":"ask"' "$out"
  out=$(event_json PreToolUse Edit "$P/src/auth/login.ts" s7 | ONELOOP_HOME=/nonexistent bash "$SCRIPT")
  assert_eq "no config and no map line: nothing to judge" "" "$out"
}

test_bad_input() {
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Edit",cwd:"/tmp/proj",tool_input:{}}' | bash "$SCRIPT")
  assert_eq "an edit with no path prints nothing" "" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_first_edit_asks_and_names_the_word
test_a_denied_edit_asks_again_and_one_that_went_through_does_not
test_every_edit_tool_and_only_those
test_paths_outside_the_zones_pass
test_the_matched_word_is_the_first_alternative_that_matches
test_the_map_overrides_the_default_regex
test_the_config_is_the_default_and_no_regex_is_silence
test_bad_input
report
