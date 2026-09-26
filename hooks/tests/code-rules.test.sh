#!/bin/bash
# Fixture tests for code-rules.sh. Run: bash hooks/tests/code-rules.test.sh
# The first PreToolUse for a Read or an edit of a file whose extension the code rules' paths:
# globs name hands Claude the code rules (their front matter off) as context and logs it; the
# same session gets them once; another session gets them again; a file the globs do not name
# leaves the session unserved; another tool or event, a missing path, malformed input and a
# root with no rules file are nothing to do. CODE_RULES_SH points the test at another copy of
# the script, for a watched failure; the copy needs hook-input.sh and progress-log.sh beside
# it. The markers live under TMPDIR, which the test points at its scratch dir.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${CODE_RULES_SH:-$here/../code-rules.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
REAL=$(cd "$here/../.." && pwd)
FAKE="$WORK/root"
MARKERS="$WORK/tmp"
ROOT_FOR_EVENT="$FAKE"

build_fake_root() {
  mkdir -p "$FAKE/law" "$MARKERS" || return 1
  printf -- '---\npaths:\n  - "**/*.{ts,tsx,js}"\n  - "**/*.{py,sh}"\n---\n# Code rules\n\nRULES BODY: no empty catches.\n' > "$FAKE/law/engineering-code.md"
}

# event <tool> <path> <session> [event]: the hook's output for that call, against ROOT_FOR_EVENT.
event() {
  jq -cn --arg t "$1" --arg p "$2" --arg s "$3" --arg e "${4:-PreToolUse}" \
    '{hook_event_name: $e, tool_name: $t, session_id: $s, cwd: "/tmp/proj",
      tool_input: (if $t == "NotebookEdit" then {notebook_path: $p} else {file_path: $p} end)}' \
    | TMPDIR="$MARKERS" ONELOOP_HOME="$ROOT_FOR_EVENT" bash "$SCRIPT"
}

# context <output>: the additionalContext string of a decision.
context() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# body <rules file>: the file under its front matter.
body() { awk 'NR == 1 && $0 == "---" { skip = 1; next } skip { if ($0 == "---") skip = 0; next } { print }' "$1"; }

test_the_first_code_read_loads_the_rules() {
  out=$(event Read /p/src/a.ts s1)
  assert_eq "the decision is for PreToolUse" PreToolUse "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
  ctx=$(context "$out")
  assert_contains "the header names the file" "loaded with the first code file of this session (a.ts)" "$ctx"
  assert_contains "the rules follow" "RULES BODY: no empty catches." "$ctx"
  assert_missing "without their front matter" "paths:" "$ctx"
  assert_contains "is logged" " proj | code-rules | loaded | a.ts" "$(tail -n 1 "$LOG")"
}

test_once_per_session() {
  assert_eq "the second code file of the session loads nothing" "" "$(event Read /p/src/b.ts s1)"
  assert_eq "an edit in the same session loads nothing either" "" "$(event Edit /p/src/c.py s1)"
  assert_contains "another session loads them again" "RULES BODY" "$(context "$(event Edit /p/src/c.py s2)")"
  assert_contains "a Write counts as the first code file" "RULES BODY" "$(context "$(event Write /p/new.sh s3)")"
  assert_contains "a MultiEdit too" "RULES BODY" "$(context "$(event MultiEdit /p/m.js s9)")"
}

test_files_the_globs_do_not_name() {
  assert_eq "a markdown read loads nothing" "" "$(event Read /p/README.md s4)"
  assert_eq "a file with no extension loads nothing" "" "$(event Read /p/Makefile s4)"
  assert_contains "and leaves the session unserved, so its first code file still loads" "RULES BODY" "$(context "$(event Read /p/x.tsx s4)")"
  assert_eq "a notebook is not a code file here" "" "$(event NotebookEdit /p/n.ipynb s5)"
}

test_nothing_to_do() {
  assert_eq "PostToolUse prints nothing" "" "$(event Read /p/a.ts s6 PostToolUse)"
  assert_eq "another tool prints nothing" "" "$(event Bash /p/a.ts s6)"
  out=$(jq -cn '{hook_event_name: "PreToolUse", tool_name: "Read", session_id: "s6", tool_input: {}}' | TMPDIR="$MARKERS" ONELOOP_HOME="$FAKE" bash "$SCRIPT")
  assert_eq "no path prints nothing" "" "$out"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  ROOT_FOR_EVENT=/nonexistent
  assert_eq "a root with no rules file prints nothing" "" "$(event Read /p/a.ts s7)"
  ROOT_FOR_EVENT="$FAKE"
}

test_the_repositorys_own_rules_load_whole() {
  ROOT_FOR_EVENT="$REAL"
  ctx=$(context "$(event Read /p/a.ts s8)")
  ROOT_FOR_EVENT="$FAKE"
  expected=$(body "$REAL/law/engineering-code.md")
  assert_eq "the repository's code rules are carried whole, front matter off" yes "$(printf '%s' "$ctx" | jq -Rs --arg e "$expected" 'contains($e)' | sed 's/true/yes/')"
  assert_missing "and the globs stay out" '"**/*.{ts' "$ctx"
  if [ "$(printf '%s' "$ctx" | wc -c | tr -d ' ')" -lt 10000 ]; then fits=yes; else fits=no; fi
  assert_eq "and the whole context stays under the 10,000 characters Claude Code shows whole" yes "$fits"
}

build_fake_root || { printf 'FAIL could not build the fake root\n'; exit 1; }
test_the_first_code_read_loads_the_rules
test_once_per_session
test_files_the_globs_do_not_name
test_nothing_to_do
test_the_repositorys_own_rules_load_whole
report
