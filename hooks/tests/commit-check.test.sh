#!/bin/bash
# Fixture tests for commit-check.sh. Run: bash hooks/tests/commit-check.test.sh
# Each case feeds the guard one Bash event against a scratch git repo and reads the decision:
# a command with no commit in it is nothing to judge; a commit that leaves TODO.md out asks; a
# commit whose command names TODO.md, or whose repository has TODO.md staged, passes; the
# repository is the one a literal `git -C <dir>` names, else the cwd, and a cwd with no
# repository is nothing to judge; other tools, other events and unreadable input print nothing.
# COMMIT_CHECK_SH points the test at another copy of the script, for a watched failure; the
# copy needs hook-input.sh and progress-log.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${COMMIT_CHECK_SH:-$here/../commit-check.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
P="$WORK/p"

build_fixture() {
  mkdir -p "$P/src" "$WORK/plain" || return 1
  git init -q "$P" && printf -- '- [~] add the thing\n' > "$P/TODO.md" && : > "$P/src/a.ts" \
    && git -C "$P" add TODO.md src/a.ts && git -C "$P" -c user.name=t -c user.email=t@example.com commit -q -m base
}

# event_json <command> <cwd>: the Bash event as Claude Code sends it.
event_json() {
  jq -cn --arg c "$1" --arg d "$2" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}'
}

# decide <command> <cwd>: `ask` for a prompt, `pass` for silence, the raw decision otherwise.
decide() {
  out=$(event_json "$1" "$2" | bash "$SCRIPT")
  printf '%s' "$out" > "$WORK/last.json"
  if [ -z "$out" ]; then printf 'pass'; return; fi
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unreadable"'
}

# last <field>: one field of the last decision's hookSpecificOutput.
last() { jq -r ".hookSpecificOutput.$1 // empty" "$WORK/last.json"; }

test_commands_without_a_commit_pass() {
  assert_eq "ls passes" pass "$(decide "ls -la" "$P")"
  assert_eq "git status passes" pass "$(decide "git status --short" "$P")"
  assert_eq "a word that only contains commit passes" pass "$(decide "git log --oneline; echo recommitted" "$P")"
  assert_eq "and nothing was logged" "" "$(cat "$LOG" 2>/dev/null)"
}

test_a_commit_that_leaves_the_checklist_out_asks() {
  printf 'x\n' > "$P/src/a.ts"; git -C "$P" add src/a.ts
  assert_eq "git commit with TODO.md unstaged asks" ask "$(decide "git commit -m 'change a'" "$P")"
  assert_eq "the decision is for PreToolUse" PreToolUse "$(last hookEventName)"
  assert_contains "the reason says what to do" "this commit leaves TODO.md out. Tick the task's line in TODO.md and stage it with the change; approve to commit without it." "$(last permissionDecisionReason)"
  assert_contains "the context tells Claude the approval is the yes" "their approval is the yes" "$(last additionalContext)"
  assert_contains "it is logged" " p | guard | commit | ask | p | TODO.md not in the commit" "$(tail -n 1 "$LOG")"
  assert_eq "a commit after an add in the same command asks too" ask "$(decide "git add src/a.ts && git commit -m 'change a'" "$P")"
}

test_a_commit_that_carries_the_checklist_passes() {
  assert_eq "TODO.md named in the same command passes" pass "$(decide "git add TODO.md src/a.ts && git commit -m 'change a'" "$P")"
  printf -- '- [x] add the thing\n' > "$P/TODO.md"; git -C "$P" add TODO.md
  assert_eq "TODO.md already staged passes" pass "$(decide "git commit -m 'change a'" "$P")"
  git -C "$P" -c user.name=t -c user.email=t@example.com commit -q -m 'change a'
  assert_eq "the next commit with nothing staged asks again" ask "$(decide "git commit --allow-empty -m 'again'" "$P")"
}

test_the_repository_comes_from_c_else_the_cwd() {
  assert_eq "a literal -C names the repository from another cwd" ask "$(decide "git -C \"$P\" commit -m x" "$WORK/plain")"
  assert_eq "an unquoted -C too" ask "$(decide "git -C $P commit -m x" "$WORK/plain")"
  assert_eq "a -C holding a shell variable falls back to the cwd" ask "$(decide "D=$P; git -C \"\$D\" commit -m x" "$P")"
  assert_eq "a cwd with no repository and no -C is nothing to judge" pass "$(decide "git commit -m x" "$WORK/plain")"
}

test_other_tools_events_and_bad_input() {
  out=$(jq -cn --arg c "$P" '{hook_event_name: "PreToolUse", tool_name: "Edit", cwd: $c, tool_input: {file_path: "x", new_string: "git commit"}}' | bash "$SCRIPT")
  assert_eq "an edit is not judged here" "" "$out"
  out=$(jq -cn --arg c "$P" '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $c, tool_input: {command: "git commit -m x"}}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  out=$(jq -cn --arg c "$P" '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $c, tool_input: {}}' | bash "$SCRIPT")
  assert_eq "no command prints nothing" "" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_commands_without_a_commit_pass
test_a_commit_that_leaves_the_checklist_out_asks
test_a_commit_that_carries_the_checklist_passes
test_the_repository_comes_from_c_else_the_cwd
test_other_tools_events_and_bad_input
report
