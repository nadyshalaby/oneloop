#!/bin/bash
# Fixture tests for scope-check.sh. Run: bash hooks/tests/scope-check.test.sh
# Each case writes the checklist, docs/oneloop-todos/TODO.md, of a scratch git repo (and, for the
# visible-output cases, a session transcript of the harness's real-shape lines) and feeds the
# guard one edit event, then reads what it printed: `fix` when it pointed at the edit (context
# for Claude that says what to fix, no decision, so nothing blocks; 14.0.0, the user's words:
# "nothing should block file edits … auto-pilot mode with self-control", "hooks shall point and
# claude fixes raised problems"), `pass` for silence. The scope is the `scope:` of every `- [~]`
# line of the checklist, joined: an edit to a file none covers (by name, or by a folder it is
# under) is pointed at with that scope and the fix (put the file on the task line); one made
# while no line is in flight is pointed at with the fix (add or flip a line; and, while a root
# TODO.md exists and the checklist does not, git mv it there first). A `- [ ]` line is parked and
# counts for nothing, a ticked line too, and a TODO.md anywhere else, the root included, is not
# the checklist; backticks, bold marks and the closing parenthesis around the files are stripped,
# and an absolute path inside the repository counts by its relative form. Once the scope passes
# (14.1.0), the reply text stored for the turn must carry the scope line and the explanation, and
# (14.2.0) the explanation's pseudocode as a fenced block, since numbered steps in prose are not
# it (a real session printed those in its place): the
# turn is what follows the last human message (typed, as a string or as text blocks, or queued
# mid-turn; injected text, compaction summaries, tool results and task notifications are not
# human messages), its reply text is the assistant text blocks alone, a progress line is not a
# scope line, and a big transcript is read from its tail; a turn with no stored reply text, no
# transcript, or one that cannot be read, is not judged (some transcripts keep none of the text
# sent along with a tool call), nor (16.0.1) is a turn with a message stored reworded, a thinking
# block with text in place of its text block, as real transcripts keep it, while an empty signed
# thinking block beside a text block changes nothing. The checklist and its archive themselves,
# files outside the repository, other tools and events and unreadable input are nothing to
# judge, and the guard never prints a decision. SCOPE_CHECK_SH points the test at another copy
# of the script, for a watched failure; the copy needs hook-input.sh and progress-log.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${SCOPE_CHECK_SH:-$here/../scope-check.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
P="$WORK/p"
T=""
TICK=$(printf '\140')
TODO="docs/oneloop-todos/TODO.md"

build_fixture() {
  mkdir -p "$P/src/util" "$P/src/cart" "$P/docs/oneloop-todos" "$WORK/elsewhere" || return 1
  git init -q "$P" && : > "$P/src/util/math.ts" && : > "$P/src/cart/summary.ts" && : > "$P/README.md" && : > "$WORK/elsewhere/x.ts"
}

# checklist <line>...: the checklist's whole content, one line per argument.
checklist() { printf '%s\n' "$@" > "$P/$TODO"; }

# human_line <text>: a message the user typed, as the transcript stores it.
human_line() { jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: $t}}'; }

# blocks_line <text>: a message the user typed with an image, stored as an array of blocks.
blocks_line() { jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: [{type: "text", text: $t}, {type: "image", source: {type: "base64", data: "AAAA"}}]}}'; }

# summary_line <text>: the compaction summary Claude Code inserts as a user message.
summary_line() { jq -cn --arg t "$1" '{type: "user", isCompactSummary: true, message: {role: "user", content: $t}}'; }

# meta_line <text>: a skill's or hook's injected text, marked isMeta.
meta_line() { jq -cn --arg t "$1" '{type: "user", isMeta: true, message: {role: "user", content: [{type: "text", text: $t}]}}'; }

# result_line <text>: a tool result, stored as a user message.
result_line() { jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: "t1", content: $t}]}}'; }

# queued_line <text>: a message the user typed while Claude was working, delivered as a queued command.
queued_line() { jq -cn --arg t "$1" '{type: "attachment", attachment: {type: "queued_command", humanTurn: true, origin: {kind: "human"}, commandMode: "prompt", prompt: $t}}'; }

# notification_line <text>: a queued task notification, the same attachment shape without a human turn.
notification_line() { jq -cn --arg t "$1" '{type: "attachment", attachment: {type: "queued_command", commandMode: "task-notification", prompt: $t}}'; }

# text_line <text>: reply text Claude wrote, one assistant text block.
text_line() { jq -cn --arg t "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "text", text: $t}]}}'; }

# thinking_line <text>: one thinking block under the message id the reworded lines share; empty,
# with its signature, it is the shape most thinking blocks are kept in (seen 2026-09-28).
thinking_line() { jq -cn --arg t "$1" '{type: "assistant", message: {id: "msg_r1", role: "assistant", content: [{type: "thinking", thinking: $t, signature: "c2ln"}]}}'; }

# reworded_lines <text>: a message as real transcripts keep some of them (seen 2026-09-28), one
# block per line under one message id: the empty signed thinking block, a thinking block holding
# a reworded copy of the text Claude printed, and the tool call; no text block.
reworded_lines() {
  thinking_line ""
  thinking_line "$1"
  jq -cn '{type: "assistant", message: {id: "msg_r1", role: "assistant", content: [{type: "tool_use", id: "r1", name: "Read", input: {file_path: "src/util/math.ts"}}]}}'
}

# edit_line <path>: an edit Claude made, as the transcript stores the call.
edit_line() { jq -cn --arg p "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "e1", name: "Edit", input: {file_path: $p, old_string: "a", new_string: "b"}}]}}'; }

EXPLANATION="The problem. runningSum says how, not what.
${TICK}${TICK}${TICK}
FUNCTION computeTotal(prices)
  sum ← 0                      -- renamed
  RETURN sum
${TICK}${TICK}${TICK}
Effect: the same total, a clearer name. Risk: a string reference to the old name."

# The shape a real session printed on 2026-09-26: the four parts, the pseudocode as numbered
# prose steps, no fenced block.
PROSE_EXPLANATION="The problem: the sum's name says how, not what.
How it will work:
1. computeTotal starts the sum at 0.
2. It returns the sum.
The effect: the same total, a clearer name.
The risks: a string reference to the old name."

# event_json <tool> <path>: the edit event as Claude Code sends it, with the transcript when the
# case has one.
event_json() {
  jq -cn --arg t "$1" --arg p "$2" --arg c "$P" --arg tr "$T" \
    '{hook_event_name: "PreToolUse", tool_name: $t, cwd: $c, session_id: "s1",
      tool_input: (if $t == "NotebookEdit" then {notebook_path: $p} else {file_path: $p, new_string: "x"} end)}
     + (if $tr == "" then {} else {transcript_path: $tr} end)'
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

test_the_scope_line_and_the_explanation_must_be_visible() {
  checklist "- [~] rename runningSum (scope: src/util/math.ts)"
  T="$WORK/transcript.jsonl"
  human_line "Rename runningSum to sum in src/util/math.ts." > "$T"
  assert_eq "a turn with no stored reply text is not judged" pass "$(decide Edit "$P/src/util/math.ts")"
  text_line "🔵 Scope ⚪ Edit ⚪ Check ⚪ Commit" >> "$T"
  assert_eq "stored reply text without a scope line is pointed at (a progress line is not one)" fix "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "with no decision" "" "$(last permissionDecision)"
  assert_contains "the pointer says what to print" "no scope line is visible in this turn (your thinking is invisible). Fix it now: print the progress line, ${TICK}scope: <files>${TICK}, the note of at most 3 lines and the explanation (the problem, the pseudocode as a fenced block, the effect, the risks) as chat text, then go on; nothing blocks this edit." "$(last additionalContext)"
  assert_contains "and is logged" " p | guard | scope | fix | src/util/math.ts | scope line not visible" "$(tail -n 1 "$LOG")"
  text_line "Renaming it now." >> "$T"
  assert_eq "more text without the line is still pointed at" fix "$(decide Edit "$P/src/util/math.ts")"
  text_line "scope: src/util/math.ts
- runningSum becomes sum in computeTotal, one file, nothing else reads it." >> "$T"
  assert_eq "the scope line and the note alone are still pointed at" fix "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "for the explanation" "the explanation is not visible in this turn (your thinking is invisible). Fix it now: print it as chat text, the problem, the pseudocode as a fenced block, the effect, the risks, then go on; nothing blocks this edit." "$(last additionalContext)"
  assert_contains "and logged as such" " p | guard | scope | fix | src/util/math.ts | explanation not visible" "$(tail -n 1 "$LOG")"
  text_line "$PROSE_EXPLANATION" >> "$T"
  assert_eq "an explanation whose pseudocode is numbered prose steps, no fenced block, is pointed at" fix "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "for the pseudocode" "the pseudocode is not visible in this turn: the explanation has no fenced block, and numbered steps in prose are not pseudocode. Fix it now: print the pseudocode as chat text, a fenced block in IF, FOR, RETURN and ←, then go on; nothing blocks this edit." "$(last additionalContext)"
  assert_contains "and logged as pseudocode not visible" " p | guard | scope | fix | src/util/math.ts | pseudocode not visible" "$(tail -n 1 "$LOG")"
  text_line "$EXPLANATION" >> "$T"
  assert_eq "scope line, note and the explanation with its fenced pseudocode visible: the edit passes" pass "$(decide Edit "$P/src/util/math.ts")"
  edit_line "$P/src/util/math.ts" >> "$T"
  assert_eq "and the next edit in the same turn passes too" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Also do the cart summary."; text_line "✅ Scope 🔵 Edit ⚪ Check ⚪ Commit"; } >> "$T"
  assert_eq "a new message from the user starts a new turn, so the old text no longer counts" fix "$(decide Edit "$P/src/util/math.ts")"
  { text_line "scope: src/util/math.ts"; text_line "$EXPLANATION"; } >> "$T"
  assert_eq "printed again, it passes" pass "$(decide Edit "$P/src/util/math.ts")"
  { notification_line "<task-notification>the job is done</task-notification>"; meta_line "one loop · auto-pilot"; summary_line "Summary: the user asked for a rename"; result_line "ok"; } >> "$T"
  assert_eq "a task notification, an injected text, a compaction summary and a tool result are not the user" pass "$(decide Edit "$P/src/util/math.ts")"
  { queued_line "and the caller too"; text_line "On it."; } >> "$T"
  assert_eq "a message typed mid-turn starts a new turn" fix "$(decide Edit "$P/src/util/math.ts")"
  { blocks_line "here is a screenshot"; text_line "Looking."; } >> "$T"
  assert_eq "a message with an image, stored as blocks, is the user and does not break the reader" fix "$(decide Edit "$P/src/util/math.ts")"
  result_line "scope: src/util/math.ts $EXPLANATION" >> "$T"
  assert_eq "scope: inside a tool result is not reply text" fix "$(decide Edit "$P/src/util/math.ts")"
  { text_line "scope: src/util/math.ts"; text_line "$EXPLANATION"; } >> "$T"
  assert_eq "reply text after all that passes" pass "$(decide Edit "$P/src/util/math.ts")"
  human_line "Rename it." > "$T"
  assert_eq "a file outside the scope gets the scope pointer first" fix "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "not the visibility one" "is outside the scope of the task in flight" "$(last additionalContext)"
  assert_eq "the checklist itself is never judged" pass "$(decide Write "$P/$TODO")"
  T="$WORK/missing.jsonl"
  assert_eq "a transcript that does not exist skips the check" pass "$(decide Edit "$P/src/util/math.ts")"
  T=""
  assert_eq "no transcript path skips the check" pass "$(decide Edit "$P/src/util/math.ts")"
}

test_a_turn_stored_reworded_is_not_judged() {
  checklist "- [~] rename runningSum (scope: src/util/math.ts)"
  T="$WORK/reworded.jsonl"
  { human_line "Rename runningSum to sum."; thinking_line ""; text_line "🔵 Scope ⚪ Edit ⚪ Check ⚪ Commit"; } > "$T"
  assert_eq "an empty signed thinking block beside kept text changes nothing: no scope line is pointed at" fix "$(decide Edit "$P/src/util/math.ts")"
  reworded_lines "Printed the scope line and explained the rename before editing." >> "$T"
  assert_eq "a message stored reworded, a thinking block with text and no text block, leaves the turn unjudged" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Now the caller."; text_line "scope: src/util/math.ts"; reworded_lines "Explained the problem, the effect and the risks."; } >> "$T"
  assert_eq "so does one after a kept scope line, where the explanation may have been" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Go on."; text_line "On it."; } >> "$T"
  assert_eq "a reworded message in an earlier turn does not count in the next one" fix "$(decide Edit "$P/src/util/math.ts")"
  T=""
}

test_a_big_transcript_is_read_from_its_tail() {
  checklist "- [~] rename runningSum (scope: src/util/math.ts)"
  T="$WORK/big.jsonl"
  yes '{"type":"progress","data":{"n":1}}' | head -n 90000 > "$T"
  { human_line "Rename it."; text_line "scope: src/util/math.ts"; text_line "$EXPLANATION"; } >> "$T"
  assert_eq "the fixture is over the tail size" yes "$(if [ "$(wc -c < "$T" | tr -d ' ')" -gt 2000000 ]; then printf yes; else printf no; fi)"
  assert_eq "a turn at the end of a big transcript is read" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Now the cart."; text_line "Sure."; } >> "$T"
  assert_eq "and a new turn there, with text but no scope line, is pointed at" fix "$(decide Edit "$P/src/util/math.ts")"
  printf 'this line is not JSON\n' >> "$T"
  { text_line "scope: src/util/math.ts"; text_line "$EXPLANATION"; } >> "$T"
  assert_eq "a line that is not JSON does not abort the reader" pass "$(decide Edit "$P/src/util/math.ts")"
  T=""
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
test_the_scope_line_and_the_explanation_must_be_visible
test_a_turn_stored_reworded_is_not_judged
test_a_big_transcript_is_read_from_its_tail
test_the_checklist_itself_and_files_outside_are_not_judged
test_a_new_file_in_a_new_folder_is_judged_by_its_repository
test_other_tools_events_and_bad_input
report
