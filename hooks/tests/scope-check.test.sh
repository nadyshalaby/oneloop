#!/bin/bash
# Fixture tests for scope-check.sh. Run: bash hooks/tests/scope-check.test.sh
# Each case builds a transcript from the harness's real-shape lines (a message the user typed,
# a reply Claude wrote, a tool call and its result, a skill's injected text, a compaction
# summary, a pick-list answer, a queued message) and feeds the guard one edit event against a
# scratch git repo, then reads the decision. The scope is the `- [ ] <task> (scope: <files>)`
# line Claude adds to the checklist, docs/oneloop-todos/TODO.md, read from that Edit, Write or
# MultiEdit in the transcript; a scope line in Claude's chat text, in another file's edit (a
# root TODO.md, the old home, included), in a tool result, a summary or an injected text is not
# one, nor is a line the edit's old text already held or a line turning `[~]`. An edit before
# any approved scope asks; the user's reply after a proposal is the yes, whether typed, picked
# in a pick-list (stored as the AskUserQuestion tool's result) or sent while Claude was working
# (stored as a queued command); a pick-list option whose description carries `scope: <files>`
# is itself a proposal of that scope when the user picks it (the pick is its yes; an option
# without one, a typed answer matching no option and an unanswered question propose nothing);
# another tool's result or a queued task notification is not a
# reply; "go" in the user's message pre-approves the first proposal after it and no later one;
# a folder on the scope covers the files under it; the checklist must hold an open line, and an
# open line in a root TODO.md does not count (the reason then says to git mv it); the checklist
# and its archive themselves, files outside the repository, other tools and events, a missing
# transcript and unreadable input are nothing to judge; a TODO.md anywhere else is judged like
# any other file. SCOPE_CHECK_SH
# points the test at another copy of the script, for a watched failure; the copy needs
# hook-input.sh and progress-log.sh beside it.
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
TODO="docs/oneloop-todos/TODO.md"

build_fixture() {
  mkdir -p "$P/src/util" "$P/src/cart" "$P/docs/oneloop-todos" "$WORK/elsewhere" || return 1
  git init -q "$P" && : > "$P/src/util/math.ts" && : > "$P/src/cart/summary.ts" && : > "$P/README.md" && : > "$WORK/elsewhere/x.ts"
}

# human_line <text>: a message the user typed, as the transcript stores it.
human_line() { jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: $t}}'; }

# summary_line <text>: the compaction summary Claude Code inserts as a user message.
summary_line() { jq -cn --arg t "$1" '{type: "user", isCompactSummary: true, message: {role: "user", content: $t}}'; }

# meta_line <text>: a skill's or hook's injected text, marked isMeta.
meta_line() { jq -cn --arg t "$1" '{type: "user", isMeta: true, message: {role: "user", content: [{type: "text", text: $t}]}}'; }

# ask_line <id> <question>: Claude asking through AskUserQuestion, as the transcript stores the call.
ask_line() {
  jq -cn --arg i "$1" --arg q "$2" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: $i, name: "AskUserQuestion", input: {questions: [{question: $q}]}}]}}'
}

# ask_options <id> <question> <label> <description> [<label> <description>]: a pick-list whose
# options carry descriptions, as the transcript stores the call.
ask_options() {
  jq -cn --arg i "$1" --arg q "$2" --arg l1 "$3" --arg d1 "$4" --arg l2 "${5:-}" --arg d2 "${6:-}" \
    '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: $i, name: "AskUserQuestion", input: {questions: [{question: $q, options: ([{label: $l1, description: $d1}] + (if $l2 != "" then [{label: $l2, description: $d2}] else [] end))}]}}]}}'
}

# picked <question> <label>: the answer text Claude Code stores for one pick.
picked() { printf '"%s"="%s"' "$1" "$2"; }

# answer_line <id> <text>: the user's pick-list answer, which Claude Code stores as that call's result.
answer_line() {
  jq -cn --arg i "$1" --arg t "$2" '{type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: $i, content: ("Your questions have been answered: " + $t)}]}}'
}

# queued_line <text>: a message the user typed while Claude was working, delivered as a queued command.
queued_line() {
  jq -cn --arg t "$1" '{type: "attachment", attachment: {type: "queued_command", humanTurn: true, origin: {kind: "human"}, commandMode: "prompt", prompt: $t}}'
}

# notification_line <text>: a queued task notification, the same attachment shape without a human turn.
notification_line() {
  jq -cn --arg t "$1" '{type: "attachment", attachment: {type: "queued_command", commandMode: "task-notification", prompt: $t}}'
}

# todo_add <files> [file]: Claude adding a task line with its scope to the checklist (default)
# or to another file, as the transcript stores the Edit.
todo_add() {
  jq -cn --arg p "${2:-$P/$TODO}" --arg f "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "e1", name: "Edit", input: {file_path: $p, old_string: "", new_string: ("- [ ] a task (scope: " + $f + ")")}}]}}'
}

# todo_write <content>: Claude rewriting TODO.md whole.
todo_write() {
  jq -cn --arg p "$P/$TODO" --arg c "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "w1", name: "Write", input: {file_path: $p, content: $c}}]}}'
}

# todo_flip <files>: the task line turning [~], an Edit whose old text holds the [ ] line.
todo_flip() {
  jq -cn --arg p "$P/$TODO" --arg f "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "e2", name: "Edit", input: {file_path: $p, old_string: ("- [ ] a task (scope: " + $f + ")"), new_string: ("- [~] a task (scope: " + $f + ")")}}]}}'
}

# todo_multi <files>: the task line added through a MultiEdit.
todo_multi() {
  jq -cn --arg p "$P/$TODO" --arg f "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "m1", name: "MultiEdit", input: {file_path: $p, edits: [{old_string: "## Later", new_string: ("## Later\n- [ ] a task (scope: " + $f + ")")}]}}]}}'
}

# open_task: the checklist with one task in flight.
open_task() { printf -- '- [~] rename runningSum to sum (scope: src/util/math.ts)\n' > "$P/$TODO"; }

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

test_a_proposal_waits_for_the_yes() {
  { human_line "Rename runningSum to sum in src/util/math.ts."; todo_add "src/util/math.ts"; reply_line "scope: src/util/math.ts
- runningSum becomes sum in computeTotal, one file, nothing else reads it."; } > "$T"
  open_task
  assert_eq "an edit before the yes asks" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "the decision is for PreToolUse" PreToolUse "$(last hookEventName)"
  assert_contains "the reason says no scope is approved yet" "no approved scope yet: add ${TICK}- [ ] <task> (scope: <files>)${TICK} to docs/oneloop-todos/TODO.md, print the scope line and the note, then wait for the yes" "$(last permissionDecisionReason)"
  assert_contains "the context tells Claude the approval is the yes" "their approval is the yes" "$(last additionalContext)"
  assert_contains "it is logged" " p | guard | scope | ask | src/util/math.ts | no scope" "$(tail -n 1 "$LOG")"
}

test_the_users_reply_is_the_yes_for_the_proposal_that_stood() {
  human_line "yes" >> "$T"
  assert_eq "the scoped file passes after the reply" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "a Write to it passes too" pass "$(decide Write "$P/src/util/math.ts")"
  assert_eq "a file outside the scope asks" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "the reason names the file and the approved scope" "src/cart/summary.ts is outside the approved scope (scope: src/util/math.ts): restate the scope on the task line in docs/oneloop-todos/TODO.md and wait for the yes" "$(last permissionDecisionReason)"
  assert_contains "and is logged as outside scope" " p | guard | scope | ask | src/cart/summary.ts | outside scope" "$(tail -n 1 "$LOG")"
}

test_go_pre_approves_the_first_proposal_after_it_only() {
  { human_line "Rename computeTotal to calcTotal in src/util/math.ts, go."; todo_add "src/util/math.ts"; } > "$T"
  assert_eq "the first proposal after go passes without a reply" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "a file it does not name asks" ask "$(decide Edit "$P/src/cart/summary.ts")"
  todo_add "src/util/math.ts, src/cart/summary.ts" >> "$T"
  assert_eq "a restated scope still asks until the user replies" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "the reason still names the approved scope, not the restated one" "(scope: src/util/math.ts)" "$(last permissionDecisionReason)"
  human_line "yes" >> "$T"
  assert_eq "the reply approves the restated scope" pass "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "Also rename the summary function. Go ahead."; todo_add "src/cart/summary.ts"; } >> "$T"
  assert_eq "a later message with Go pre-approves its own first proposal" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "and the earlier file is now outside it" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it in golang style too."; todo_add "src/util/math.ts"; } >> "$T"
  assert_eq "golang is not the word go" ask "$(decide Edit "$P/src/util/math.ts")"
}

test_a_pick_list_answer_and_a_queued_message_are_replies() {
  { human_line "Rename runningSum to sum in src/util/math.ts."; todo_add "src/util/math.ts"; ask_line q1 "Approve this scope?"; answer_line q1 "\"Approve this scope?\"=\"Yes (Recommended)\""; } > "$T"; open_task
  assert_eq "a pick-list answer approves the proposal that stood" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; quoted_line "yes"; } > "$T"
  assert_eq "another tool's result is not a reply" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; queued_line "yes"; } > "$T"
  assert_eq "a message typed while Claude worked is a reply" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; queued_line "also the caller, go"; todo_add "src/util/math.ts, src/cart/summary.ts"; } > "$T"
  assert_eq "a queued go pre-approves the first proposal after it" pass "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; notification_line "<task-notification>the job is done, go on</task-notification>"; } > "$T"
  assert_eq "a queued task notification is not a reply" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it, go."; todo_add "src/util/math.ts"; ask_line q2 "Widen to the caller?"; answer_line q2 "\"Widen to the caller?\"=\"go\""; todo_add "src/util/math.ts, src/cart/summary.ts"; } > "$T"
  assert_eq "a pick-list answer saying go pre-approves the next proposal" pass "$(decide Edit "$P/src/cart/summary.ts")"
}

test_a_picked_option_carrying_the_scope_is_the_proposal() {
  open_task
  { human_line "Resume."; ask_options q3 "Resume which task?" "Rename runningSum (Recommended)" "scope: src/util/math.ts. Not started, from Edit" "Cart summary" "scope: ${TICK}src/cart/${TICK}; edited, from Check"; answer_line q3 "$(picked "Resume which task?" "Rename runningSum (Recommended)")"; } > "$T"
  assert_eq "the scope in the picked option is approved" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "the other option's scope is not" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "and the reason names the picked scope" "(scope: src/util/math.ts)" "$(last permissionDecisionReason)"
  { human_line "Resume."; ask_options q3 "Resume which task?" "Rename runningSum (Recommended)" "scope: src/util/math.ts. Not started, from Edit" "Cart summary" "scope: ${TICK}src/cart/${TICK}; edited, from Check"; answer_line q3 "$(picked "Resume which task?" "Cart summary")"; } > "$T"
  assert_eq "picking the other option approves its scope, backticks stripped, the words after ; dropped" pass "$(decide Write "$P/src/cart/new.ts")"
  assert_eq "and not the first option's" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Resume."; ask_options q4 "Resume which task?" "Rename runningSum" "Not started, from Edit"; answer_line q4 "$(picked "Resume which task?" "Rename runningSum")"; } > "$T"
  assert_eq "an option without scope: approves nothing" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Resume."; ask_options q5 "Resume which task?" "Rename runningSum" "scope: src/util/math.ts"; answer_line q5 "$(picked "Resume which task?" "something I typed myself")"; } > "$T"
  assert_eq "a typed answer that matches no option approves nothing" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Resume."; ask_options q6 "Resume which task?" "Rename runningSum" "scope: src/util/math.ts"; } > "$T"
  assert_eq "an unanswered pick-list approves nothing" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it."; todo_add "src/cart/summary.ts"; ask_options q7 "Approve?" "Yes (Recommended)" "scope: src/util/math.ts"; answer_line q7 "$(picked "Approve?" "Yes (Recommended)")"; } > "$T"
  assert_eq "the picked scope is the last proposal before the reply, over an earlier task line" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "so the earlier line's file asks" ask "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; ask_options q8 "Approve?" "Yes (Recommended)" "The smallest diff, one file."; answer_line q8 "$(picked "Approve?" "Yes (Recommended)")"; } > "$T"
  assert_eq "a pick without scope: leaves the task line's proposal approved" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Resume."; ask_options q9 "Resume which task?" "Rename runningSum" "scope: src/util/math.ts, ${TICK}src/cart/summary.ts${TICK}."; answer_line q9 "$(picked "Resume which task?" "Rename runningSum")"; } > "$T"
  assert_eq "a scope list ending in a full stop keeps its last file" pass "$(decide Edit "$P/src/cart/summary.ts")"
}

test_where_the_scope_is_read_from() {
  { human_line "Rename it, go."; reply_line "scope: src/util/math.ts"; } > "$T"; open_task
  assert_eq "a scope line in Claude's chat text alone is not a proposal" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "so no scope is approved" "no approved scope yet" "$(last permissionDecisionReason)"
  { human_line "Rename it, go."; todo_add "src/util/math.ts" "$P/README.md"; } > "$T"
  assert_eq "a task line written into another file is not one either" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it, go."; todo_add "src/util/math.ts" "$P/TODO.md"; } > "$T"
  assert_eq "nor is one written into a root TODO.md, the old home" ask "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it, go."; todo_write "## Now
- [x] an old task (scope: src/cart/summary.ts)
- [ ] a task (scope: src/util/math.ts)"; } > "$T"
  assert_eq "a Write of the whole TODO.md proposes its open line" pass "$(decide Edit "$P/src/util/math.ts")"
  assert_eq "and not a ticked one" ask "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "Rename it, go."; todo_write "- [ ] first (scope: src/cart/summary.ts)
- [ ] a task (scope: src/util/math.ts)"; } > "$T"
  assert_eq "with two open lines the last one written is the proposal" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it, go."; todo_multi "src/util/math.ts"; } > "$T"
  assert_eq "a MultiEdit proposes too" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; human_line "yes"; todo_flip "src/util/math.ts"; } > "$T"
  assert_eq "the line turning [~] after the yes is not a new proposal" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "Rename it."; todo_add "src/util/math.ts"; human_line "yes"; todo_write "- [~] a task (scope: src/util/math.ts)"; } > "$T"
  assert_eq "nor is a rewrite that holds only the [~] line" pass "$(decide Edit "$P/src/util/math.ts")"
}

test_folders_and_markdown_on_the_scope() {
  { human_line "Tidy the util folder, go"; todo_add "${TICK}src/util/${TICK}, ${TICK}src/cart/summary.ts${TICK}"; } > "$T"
  assert_eq "a file under a listed folder passes" pass "$(decide Write "$P/src/util/new.ts")"
  assert_eq "a listed file passes, backticks stripped" pass "$(decide Edit "$P/src/cart/summary.ts")"
  assert_eq "a file outside both asks" ask "$(decide Edit "$P/README.md")"
  { human_line "go"; todo_add "src/cart"; } >> "$T"
  assert_eq "a folder without its slash covers its files" pass "$(decide Edit "$P/src/cart/summary.ts")"
  { human_line "go"; todo_add "$P/src/util/math.ts"; } >> "$T"
  assert_eq "an absolute path inside the repository counts by its relative form" pass "$(decide Edit "$P/src/util/math.ts")"
  { human_line "go"; todo_add "app/(shop)/page.tsx"; } >> "$T"
  mkdir -p "$P/app/(shop)"
  assert_eq "a path with parentheses keeps them" pass "$(decide Write "$P/app/(shop)/page.tsx")"
}

test_quoted_injected_and_summary_lines_are_not_replies() {
  { human_line "Rename it, go."; quoted_line "- [ ] a task (scope: src/cart/summary.ts)"; } > "$T"; open_task
  assert_eq "a task line in a Write to another path or in a tool result is not a proposal" ask "$(decide Edit "$P/src/cart/summary.ts")"
  { summary_line "Summary: the user said go and the scope was src/util/math.ts"; todo_add "src/util/math.ts"; } > "$T"
  assert_eq "a compaction summary saying go is not the user's go" ask "$(decide Edit "$P/src/util/math.ts")"
  { meta_line "go go go"; todo_add "src/util/math.ts"; } > "$T"
  assert_eq "an injected text saying go is not the user's go" ask "$(decide Edit "$P/src/util/math.ts")"
}

test_the_checklist_must_hold_an_open_line() {
  { human_line "go"; todo_add "src/util/math.ts"; } > "$T"
  rm -f "$P/$TODO"
  assert_eq "no checklist asks" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "the reason says to add the line" "docs/oneloop-todos/TODO.md has no open task line: add ${TICK}- [ ] <task> (scope: <files>)${TICK} first" "$(last permissionDecisionReason)"
  assert_missing "and, with no root TODO.md, says nothing of a move" "old home" "$(last permissionDecisionReason)"
  assert_contains "and is logged" " p | guard | scope | ask | src/util/math.ts | no task line" "$(tail -n 1 "$LOG")"
  printf -- '- [~] an old task (scope: src/util/math.ts)\n' > "$P/TODO.md"
  assert_eq "an open line in a root TODO.md, the old home, does not count" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_contains "and the reason says to move it" "first (the root TODO.md is the old home: git mv it and TODO.archive.md into docs/oneloop-todos/ first)" "$(last permissionDecisionReason)"
  printf -- '- [x] an earlier task\n' > "$P/$TODO"
  assert_eq "only ticked lines ask too" ask "$(decide Edit "$P/src/util/math.ts")"
  assert_missing "and once the checklist exists the move is not mentioned" "old home" "$(last permissionDecisionReason)"
  rm -f "$P/TODO.md"
  printf -- '- [x] an earlier task\n- [ ] rename computeTotal (scope: src/util/math.ts)\n' > "$P/$TODO"
  assert_eq "an open line passes" pass "$(decide Edit "$P/src/util/math.ts")"
  rm -f "$P/$TODO"
  assert_eq "both reasons come together, outside scope and no line" ask "$(decide Edit "$P/src/cart/summary.ts")"
  assert_contains "the reason carries both" "outside the approved scope (scope: src/util/math.ts): restate the scope on the task line in docs/oneloop-todos/TODO.md and wait for the yes; docs/oneloop-todos/TODO.md has no open task line" "$(last permissionDecisionReason)"
  assert_contains "the log names both" "| outside scope + no task line" "$(tail -n 1 "$LOG")"
  human_line "Start something new." > "$T"
  assert_eq "the checklist itself is never judged" pass "$(decide Write "$P/$TODO")"
  assert_eq "nor is its archive" pass "$(decide Write "$P/docs/oneloop-todos/TODO.archive.md")"
  assert_eq "a root TODO.md is judged like any other file" ask "$(decide Write "$P/TODO.md")"
  assert_eq "and so is a TODO.md in another folder" ask "$(decide Write "$P/src/TODO.md")"
}

test_outside_the_repository_is_not_judged() {
  human_line "hello" > "$T"
  assert_eq "a file in a folder with no repository passes" pass "$(decide Edit "$WORK/elsewhere/x.ts")"
  before=$(wc -l < "$LOG" | tr -d ' ')
  assert_eq "and logs nothing" "$before" "$(wc -l < "$LOG" | tr -d ' ')"
}

test_a_new_file_in_a_new_folder_is_judged_by_its_repository() {
  { human_line "go"; todo_add "src/util/math.ts"; } > "$T"; open_task
  assert_eq "a Write into a folder that does not exist yet is judged" ask "$(decide Write "$P/src/new/deep/thing.ts")"
  assert_contains "by its path in the repository" "src/new/deep/thing.ts is outside the approved scope" "$(last permissionDecisionReason)"
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
test_a_proposal_waits_for_the_yes
test_the_users_reply_is_the_yes_for_the_proposal_that_stood
test_go_pre_approves_the_first_proposal_after_it_only
test_a_pick_list_answer_and_a_queued_message_are_replies
test_a_picked_option_carrying_the_scope_is_the_proposal
test_where_the_scope_is_read_from
test_folders_and_markdown_on_the_scope
test_quoted_injected_and_summary_lines_are_not_replies
test_the_checklist_must_hold_an_open_line
test_outside_the_repository_is_not_judged
test_a_new_file_in_a_new_folder_is_judged_by_its_repository
test_other_tools_events_and_bad_input
report
