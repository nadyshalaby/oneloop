#!/bin/bash
# Fixture tests for scope-check.sh. Run: bash hooks/tests/scope-check.test.sh
# Each case builds a transcript from the harness's real-shape lines (a message the user typed,
# a reply Claude wrote, a tool call and its result, a skill's injected text, a compaction
# summary) and feeds the guard one edit event against a scratch git repo, then reads the
# decision: an edit before any approved scope line asks; the user's reply after a scope line is
# the yes; "go" in the user's message pre-approves the first scope line after it and no later
# one; a folder on the line covers the files under it; a scope line quoted in a tool result, a
# summary or an injected text is not a reply; TODO.md must hold an open line; TODO.md and
# TODO.archive.md themselves, files outside the repository, other tools and events, a missing
# transcript and unreadable input are nothing to judge. SCOPE_CHECK_SH points the test at
# another copy of the script, for a watched failure; the copy needs hook-input.sh and
# progress-log.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${SCOPE_CHECK_SH:-$here/../scope-check.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
P="$WORK/p"
T="$WORK/transcript.jsonl"
TICK=$(printf '\140')

build_fixture() {
  mkdir -p "$P/src/util" "$P/src/cart" "$WORK/elsewhere" || return 1
  git init -q "$P" && : > "$P/src/util/math.ts" && : > "$P/src/cart/summary.ts" && : > "$P/README.md" && : > "$WORK/elsewhere/x.ts"
}

# human_line <text>: a message the user typed, as the transcript stores it.
human_line() { jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: $t}}'; }

# summary_line <text>: the compaction summary Claude Code inserts as a user message.
summary_line() { jq -cn --arg t "$1" '{type: "user", isCompactSummary: true, message: {role: "user", content: $t}}'; }

# meta_line <text>: a skill's or hook's injected text, marked isMeta.
meta_line() { jq -cn --arg t "$1" '{type: "user", isMeta: true, message: {role: "user", content: [{type: "text", text: $t}]}}'; }

# open_task: TODO.md with one task in flight.
open_task() { printf -- '- [~] rename runningSum to sum\n' > "$P/TODO.md"; }

# event_json <tool> <path>: the edit event as Claude Code sends it, pointing at the transcript.
event_json() {
  jq -cn --arg t "$1" --arg p "$2" --arg c "$P" --arg tr "$T" \
    '{hook_event_name: "PreToolUse", tool_name: $t, cwd: $c, session_id: "s1", transcript_path: $tr,
      tool_input: (if $t == "NotebookEdit" then {notebook_path: $p} else {file_path: $p, new_string: "x"} end)}'
}

# decide <tool> <path>: `ask` for a prompt, `pass` for silence, the raw decision otherwise; the
# whole output is kept in last.json for the field readers below.
decide() {
  out=$(event_json "$1" "$2" | bash "$SCRIPT")
  printf '%s' "$out" > "$WORK/last.json"
  if [ -z "$out" ]; then printf 'pass'; return; fi
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unreadable"'
}

# last <field>: one field of the last decision's hookSpecificOutput.
last() { jq -r ".hookSpecificOutput.$1 // empty" "$WORK/last.json"; }

test_no_transcript_is_nothing_to_judge() {
  rm -f "$T"; open_task
  assert_eq "an edit with no readable transcript passes" pass "$(decide Edit "$P/src/util/math.ts")"
}

test_a_scope_line_waits_for_the_yes() {
  { human_line "Rename runningSum to sum in src/util/math.ts."; reply_line "scope: src/util/math.ts
- runningSum becomes sum in computeTotal, one file, nothing else reads it."; } > "$T"
  open_task
  assert_eq "an edit before the yes asks" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "the decision is for PreToolUse" PreToolUse "$(last hookEventName)"
  assert_contains "the reason says no scope line is approved yet" "no approved scope line yet: print ${TICK}scope: <files>${TICK} and the note, then wait for the yes" "$(last permissionDecisionReason)"
  assert_contains "the context tells Claude the approval is the yes" "their approval is the yes" "$(last additionalContext)"
  assert_contains "it is logged" " p | guard | scope | ask | src/util/math.ts | no scope" "$(tail -n 1 "$LOG")"
}

test_the_users_reply_is_the_yes_for_the_line_that_stood() {
  human_line "yes" >> "$T"
  assert_eq "the scoped file passes after the reply" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "a Write to it passes too" pass "$(decide Write "$P/src/util/math.ts")"
  assert_eq "a file outside the line asks" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "the reason names the file and the approved line" "src/cart/summary.ts is outside the approved scope line (scope: src/util/math.ts): restate the scope and wait for the yes" "$(last permissionDecisionReason)"
  assert_contains "and is logged as outside scope" " p | guard | scope | ask | src/cart/summary.ts | outside scope" "$(tail -n 1 "$LOG")"
}

test_go_pre_approves_the_first_scope_line_after_it_only() {
  { human_line "Rename computeTotal to calcTotal in src/util/math.ts, go."; reply_line "scope: src/util/math.ts"; } > "$T"
  assert_eq "the first scope line after go passes without a reply" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "a file it does not name asks" ask "$(decide Edit "$P/src/cart/summary.ts")"
  reply_line "scope: src/util/math.ts, src/cart/summary.ts
- the caller moves too." >> "$T"
  assert_eq "a restated scope line still asks until the user replies" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "the reason still names the approved line, not the restated one" "(scope: src/util/math.ts)" "$(last permissionDecisionReason)"
  human_line "yes" >> "$T"
  assert_eq "the reply approves the restated line" pass "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "Also rename the summary function. Go ahead."; reply_line "scope: src/cart/summary.ts"; } >> "$T"
  assert_eq "a later message with Go pre-approves its own first scope line" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "and the earlier file is now outside it" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it in golang style too."; reply_line "scope: src/util/math.ts"; } >> "$T"
  assert_eq "golang is not the word go" ask "$(decide Edit "$P/src/util/math.ts")"
}

test_folders_globs_and_markdown_on_the_line() {
  { human_line "Tidy the util folder, go"; reply_line "**scope:** ${TICK}src/util/${TICK}, ${TICK}src/cart/summary.ts${TICK}"; } > "$T"
  assert_eq "a file under a listed folder passes" pass "$(decide Write "$P/src/util/new.ts")"
  assert_eq "a listed file passes, backticks and bold stripped" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "a file outside both asks" ask "$(decide Edit "$P/README.md")"
  { human_line "go"; reply_line "scope: src/cart"; } >> "$T"
  assert_eq "a folder without its slash covers its files" pass "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "go"; reply_line "scope: $P/src/util/math.ts"; } >> "$T"
  assert_eq "an absolute path inside the repository counts by its relative form" pass "$(decide Edit "$P/src/util/math.ts")"
}

test_quoted_injected_and_summary_lines_are_not_replies() {
  { human_line "Rename it, go."; quoted_line "scope: src/cart/summary.ts"; } > "$T"
  assert_eq "a scope line in a tool call or result is not a reply" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "so no scope line is approved" "no approved scope line yet" "$(last permissionDecisionReason)"
  { summary_line "Summary: the user said go and the scope was src/util/math.ts"; reply_line "scope: src/util/math.ts"; } > "$T"
  assert_eq "a compaction summary saying go is not the user's go" ask "$(decide Edit "$P/src/util/math.ts")"
  { meta_line "go go go"; reply_line "scope: src/util/math.ts"; } > "$T"
  assert_eq "an injected text saying go is not the user's go" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it, go."; reply_line "The law says: print one line ${TICK}scope: <files>${TICK} first."; } > "$T"
  assert_eq "a sentence that mentions the scope line is not one" ask "$(decide Edit "$P/src/util/math.ts")"
}

test_the_checklist_must_hold_an_open_line() {
  { human_line "go"; reply_line "scope: src/util/math.ts"; } > "$T"
  rm -f "$P/TODO.md"
  assert_eq "no TODO.md asks" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "the reason says to add the line" "TODO.md has no open task line: add ${TICK}- [ ] <task>${TICK} first" "$(last permissionDecisionReason)"
  assert_contains "and is logged" " p | guard | scope | ask | src/util/math.ts | no task line" "$(tail -n 1 "$LOG")"
  printf -- '- [x] an earlier task\n' > "$P/TODO.md"
  assert_eq "only ticked lines ask too" ask "$(decide Edit "$P/src/util/math.ts")"
  printf -- '- [x] an earlier task\n- [ ] rename computeTotal\n' > "$P/TODO.md"
  assert_eq "an open line passes" pass "$(decide Edit "$P/src/util/math.ts")"
  rm -f "$P/TODO.md"
  assert_eq "both reasons come together, outside scope and no line" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "the reason carries both" "outside the approved scope line (scope: src/util/math.ts): restate the scope and wait for the yes; TODO.md has no open task line" "$(last permissionDecisionReason)"
  assert_contains "the log names both" "| outside scope + no task line" "$(tail -n 1 "$LOG")"
  human_line "Start something new." > "$T"
  assert_eq "TODO.md itself is never judged" pass "$(decide Write "$P/TODO.md")"
  assert_eq "nor is the archive" pass "$(decide Write "$P/TODO.archive.md")"
}

test_outside_the_repository_is_not_judged() {
  human_line "hello" > "$T"
  assert_eq "a file in a folder with no repository passes" pass "$(decide Edit "$WORK/elsewhere/x.ts")"
  before=$(wc -l < "$LOG" | tr -d ' ')
  assert_eq "and logs nothing" "$before" "$(wc -l < "$LOG" | tr -d ' ')"
}

test_a_new_file_in_a_new_folder_is_judged_by_its_repository() {
  { human_line "go"; reply_line "scope: src/util/math.ts"; } > "$T"; open_task
  assert_eq "a Write into a folder that does not exist yet is judged" ask "$(decide Write "$P/src/new/deep/thing.ts")"
  assert_contains "by its path in the repository" "src/new/deep/thing.ts is outside the approved scope line" "$(last permissionDecisionReason)"
  assert_eq "a NotebookEdit is judged by its notebook path" ask "$(decide NotebookEdit "$P/src/cart/notes.ipynb")"
}

test_other_tools_events_and_bad_input() {
  out=$(jq -cn --arg c "$P" --arg tr "$T" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $c, transcript_path: $tr, tool_input: {command: "ls"}}' | bash "$SCRIPT")
  assert_eq "Bash is not judged here" "" "$out"
  out=$(jq -cn --arg c "$P" --arg p "$P/src/cart/summary.ts" '{hook_event_name: "PostToolUse", tool_name: "Edit", cwd: $c, tool_input: {file_path: $p}}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  out=$(jq -cn --arg c "$P" '{hook_event_name: "PreToolUse", tool_name: "Edit", cwd: $c, tool_input: {}}' | bash "$SCRIPT")
  assert_eq "an edit with no path prints nothing" "" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_no_transcript_is_nothing_to_judge
test_a_scope_line_waits_for_the_yes
test_the_users_reply_is_the_yes_for_the_line_that_stood
test_go_pre_approves_the_first_scope_line_after_it_only
test_folders_globs_and_markdown_on_the_line
test_quoted_injected_and_summary_lines_are_not_replies
test_the_checklist_must_hold_an_open_line
test_outside_the_repository_is_not_judged
test_a_new_file_in_a_new_folder_is_judged_by_its_repository
test_other_tools_events_and_bad_input
report
