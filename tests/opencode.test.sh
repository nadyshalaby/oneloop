#!/bin/bash
# Guard: opencode/plugin.js, the OpenCode 2.x entry, carries the Claude Code plugin into
# OpenCode through the same hook scripts: every skills/<name> registers as the skill
# oneloop:<name> with its description; every request's system parts are the OpenCode note (the
# question tool), the law's two parts as SessionStart hands them over and the loop reminder;
# and a tool call reaches the guards in Claude Code's shape, so an edit outside the task's
# scope, a debug artifact, a commit without the checklist and the out-of-scope file of a patch
# each get their pointer at the end of the tool's output, while an in-scope edit and a read of
# prose get none; 16.3.0: every skill is also the typed command /oneloop:<name>, which sends the
# typed words with the skill attached, and the scope guard reads the turn's text from the
# session's own messages: an edit in a turn that printed no scope line is pointed at, a turn
# that printed the scope line, the explanation and a fenced block is not, and only the last
# turn counts. Needs node; without it the test says so and checks nothing.
# Run: bash tests/opencode.test.sh
# ONELOOP_OPENCODE_JS points the test at another copy of the entry, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
ENTRY="${ONELOOP_OPENCODE_JS:-$ROOT/opencode/plugin.js}"
PROJECT="$WORK/project"
VERSION=$(jq -r .version "$ROOT/.claude-plugin/plugin.json")
TICK=$(printf '\140')

# make_project: a git repo with a map and one task in flight, scoped to src/a.js.
make_project() {
  mkdir -p "$PROJECT/src" "$PROJECT/docs/oneloop-todos"
  printf '# project\n\n## Key directories\n\n- %ssrc/%s: the code.\n- %sdocs/%s: the checklist.\n' "$TICK" "$TICK" "$TICK" "$TICK" > "$PROJECT/CLAUDE.md"
  printf '%s\n' '- [~] Add a (scope: src/a.js)' > "$PROJECT/docs/oneloop-todos/TODO.md"
  printf 'export const a = 1\n' > "$PROJECT/src/a.js"
  git -C "$PROJECT" init -q && git -C "$PROJECT" add -A && git -C "$PROJECT" -c user.name=t -c user.email=t@t commit -qm init
}

# write_calls: the OpenCode tool calls the driver runs, in order, in one session.
write_calls() {
  jq -n --arg shown "$(printf 'scope: src/a.js\nThe problem: a is wrong. The effect: a is right. The risks: none.\n%s\na <- 6\n%s' "$TICK$TICK$TICK" "$TICK$TICK$TICK")" '[
    {tool: "edit", input: {path: "src/b.js", oldString: "x", newString: "y"}},
    {tool: "write", input: {path: "src/a.js", content: "export const a = 2\ndebugger;\n"}},
    {tool: "shell", input: {command: "git commit -m \"add a\""}},
    {tool: "patch", input: {patchText: "*** Begin Patch\n*** Update File: src/a.js\n@@\n-export const a = 1\n+export const a = 3\n*** Add File: src/c.js\n+export const c = 1\n*** End Patch"}},
    {tool: "edit", input: {path: "src/a.js", oldString: "1", newString: "4"}},
    {tool: "read", input: {path: "CLAUDE.md"}},
    {tool: "edit", input: {path: "src/a.js", oldString: "4", newString: "5"},
      messages: [{type: "user", text: "add a"}, {type: "assistant", content: [{type: "text", text: "Editing it now."}]}]},
    {tool: "edit", input: {path: "src/a.js", oldString: "5", newString: "6"},
      messages: [{type: "user", text: "add a"}, {type: "assistant", content: [{type: "text", text: $shown}, {type: "tool", name: "edit"}]}]},
    {tool: "edit", input: {path: "src/a.js", oldString: "6", newString: "7"},
      messages: [{type: "user", text: "add a"}, {type: "assistant", content: [{type: "text", text: $shown}]},
        {type: "user", text: "and once more"}, {type: "assistant", content: [{type: "text", text: "Editing again."}]}]}
  ]' > "$WORK/calls.json"
}

run_driver() {
  TMPDIR="$WORK/state" CLAUDE_CONFIG_DIR="$WORK/log" node "$ROOT/tests/opencode-driver.mjs" "$ENTRY" "$PROJECT" "$WORK/calls.json"
}

test_every_skill_is_registered() {
  folders=$(for dir in "$ROOT"/skills/*/; do name=${dir%/}; printf 'oneloop:%s\n' "${name##*/}"; done)
  assert_eq "each skills/<name> is the skill oneloop:<name>" "$folders" "$(printf '%s' "$OUT" | jq -r '.skills[].id' | sort)"
  assert_eq "and named so" "$folders" "$(printf '%s' "$OUT" | jq -r '.skills[].name' | sort)"
  assert_eq "every skill carries its description" true "$(printf '%s' "$OUT" | jq '[.skills[].hasDescription] | all')"
}

test_every_request_carries_the_law() {
  assert_eq "four system parts" 4 "$(printf '%s' "$OUT" | jq '.system | length')"
  assert_contains "the OpenCode note maps AskUserQuestion" "the \`question\` tool" "$(printf '%s' "$OUT" | jq -r '.system[0]')"
  assert_contains "then the law's part 1" "oneloop $VERSION, the engineering law, always on, part 1 of 2" "$(printf '%s' "$OUT" | jq -r '.system[1]')"
  assert_contains "then its part 2" "oneloop $VERSION, the engineering law, always on, part 2 of 2" "$(printf '%s' "$OUT" | jq -r '.system[2]')"
  assert_contains "then the loop reminder" "one loop · auto-pilot" "$(printf '%s' "$OUT" | jq -r '.system[3]')"
}

test_the_guards_point() {
  assert_contains "an edit outside the scope is pointed at" "src/b.js is outside the scope of the task in flight" "$(printf '%s' "$OUT" | jq -r '.outputs[0]')"
  assert_contains "the first code file brings the code rules" "the code rules, part of the engineering law" "$(printf '%s' "$OUT" | jq -r '.outputs[0]')"
  assert_contains "a debug artifact is pointed at" "clean.debug-artifact" "$(printf '%s' "$OUT" | jq -r '.outputs[1]')"
  assert_contains "a commit without the checklist is pointed at" "this commit leaves docs/oneloop-todos/TODO.md out" "$(printf '%s' "$OUT" | jq -r '.outputs[2]')"
  assert_contains "a patch's out-of-scope file is pointed at" "src/c.js is outside the scope" "$(printf '%s' "$OUT" | jq -r '.outputs[3]')"
  assert_missing "its in-scope file is not" "src/a.js is outside the scope" "$(printf '%s' "$OUT" | jq -r '.outputs[3]')"
  assert_eq "an in-scope clean edit gets no pointer" "Edited." "$(printf '%s' "$OUT" | jq -r '.outputs[4]')"
  assert_eq "a read of prose gets none" "Edited." "$(printf '%s' "$OUT" | jq -r '.outputs[5]')"
}

test_every_skill_is_a_command() {
  folders=$(for dir in "$ROOT"/skills/*/; do name=${dir%/}; printf 'oneloop:%s\n' "${name##*/}"; done)
  assert_eq "each skill is the typed command /oneloop:<name>" "$folders" "$(printf '%s' "$OUT" | jq -r '.commands[].name' | sort)"
  assert_eq "every command carries its description" true "$(printf '%s' "$OUT" | jq '[.commands[].hasDescription] | all')"
  assert_eq "typing /oneloop:audit src/ sends the typed words" "/oneloop:audit src/" "$(printf '%s' "$OUT" | jq -r '.prompt.text')"
  assert_eq "with the skill attached" "oneloop:audit" "$(printf '%s' "$OUT" | jq -r '.prompt.skills[].id')"
}

test_the_scope_line_check() {
  assert_contains "a turn that printed no scope line is pointed at" "no scope line is visible in this turn" "$(printf '%s' "$OUT" | jq -r '.outputs[6]')"
  assert_eq "a turn that printed the scope line, the explanation and a fenced block is not" "Edited." "$(printf '%s' "$OUT" | jq -r '.outputs[7]')"
  assert_contains "only the last turn counts" "no scope line is visible in this turn" "$(printf '%s' "$OUT" | jq -r '.outputs[8]')"
}

if ! command -v node > /dev/null 2>&1; then
  printf 'node not found: the OpenCode entry is not checked\n'
  report
  exit
fi
make_project
write_calls
OUT=$(run_driver)
test_every_skill_is_registered
test_every_request_carries_the_law
test_the_guards_point
test_every_skill_is_a_command
test_the_scope_line_check
report
