#!/bin/bash
# Fixture tests for session-start.sh. Run: bash hooks/tests/session-start.test.sh
# On every SessionStart reason the hook hands Claude Code the core law as additionalContext,
# headed by one line naming the plugin version and the harness root; after a compaction or a
# resume it adds the re-anchor (the law above is the law, a task in flight resumes at its loop
# step, nothing from before the loss counts as proof); a start it cannot serve (another event,
# malformed input, a root with no law) prints nothing, the missing law logged. SESSION_START_SH
# points the test at another copy of the script, for a watched failure; the copy needs
# hook-input.sh and progress-log.sh beside it. ONELOOP_HOME points the hook at a root; the
# test builds one with a tiny law and its own manifest, and also serves the repository's own.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${SESSION_START_SH:-$here/../session-start.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
REAL=$(cd "$here/../.." && pwd)
FAKE="$WORK/root"

build_fake_root() {
  mkdir -p "$FAKE/law" "$FAKE/.claude-plugin" || return 1
  printf '# Engineering law (always on)\n\nLine two of a tiny law.\n' > "$FAKE/law/engineering-law.md"
  printf '{"name": "oneloop", "version": "0.0.1"}\n' > "$FAKE/.claude-plugin/plugin.json"
}

# start <how_started> [root]: the hook's output for that session start against the root.
start() {
  jq -cn --arg h "$1" '{hook_event_name: "SessionStart", how_started: $h, cwd: "/tmp/proj", transcript_path: "/nonexistent/t.jsonl"}' \
    | ONELOOP_HOME="${2:-$FAKE}" bash "$SCRIPT"
}

# context <output>: the additionalContext string of a decision.
context() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# carries <context> <file>: yes when the file's text (its last newline aside) is inside the context.
carries() { printf '%s' "$1" | jq -Rs --rawfile law "$2" 'contains($law | rtrimstr("\n"))' | sed 's/true/yes/'; }

test_a_fresh_start_carries_the_law() {
  out=$(start startup)
  assert_eq "the decision is for SessionStart" SessionStart "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
  ctx=$(context "$out")
  head=$(printf '%s\n' "$ctx" | head -n 1)
  assert_contains "the header names the plugin version" "oneloop 0.0.1, the engineering law, always on" "$head"
  assert_contains "and the harness root" "Harness root: $FAKE" "$head"
  assert_eq "the law follows verbatim" yes "$(carries "$ctx" "$FAKE/law/engineering-law.md")"
  assert_missing "no anchor on a fresh start" "resumes at the loop step" "$ctx"
  assert_contains "is logged" " proj | law | startup" "$(tail -n 1 "$LOG")"
}

test_compact_and_resume_add_the_anchor() {
  ctx=$(context "$(start compact)")
  assert_contains "compact says a summary is not the law" "Context was compacted. A summary of the law is not the law: the law above is the law." "$ctx"
  assert_contains "and resumes the loop with no proof carried over" "resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof." "$ctx"
  order=$(printf '%s\n' "$ctx" | awk '/Line two of a tiny law/ { law = NR } /Context was compacted/ { anchor = NR } END { print (law && anchor > law) ? "law then anchor" : "wrong" }')
  assert_eq "the anchor comes after the law" "law then anchor" "$order"
  assert_contains "is logged" " proj | law | compact" "$(tail -n 1 "$LOG")"
  ctx=$(context "$(start resume)")
  assert_contains "resume says so" "Session resumed. A task that was in flight resumes" "$ctx"
  for how in clear fork; do
    assert_missing "no anchor on $how" "resumes at the loop step" "$(context "$(start "$how")")"
  done
  assert_contains "clear still carries the law" "Line two of a tiny law" "$(context "$(start clear)")"
}

test_the_repositorys_own_law_ships_whole() {
  ctx=$(context "$(start startup "$REAL")")
  assert_eq "the repository's law is carried verbatim" yes "$(carries "$ctx" "$REAL/law/engineering-law.md")"
  assert_contains "under the manifest's version" "oneloop $(jq -r .version "$REAL/.claude-plugin/plugin.json"), the engineering law" "$ctx"
  assert_contains "and the real root" "Harness root: $REAL" "$ctx"
}

test_nothing_to_serve_prints_nothing() {
  assert_eq "another event prints nothing" "" "$(jq -cn '{hook_event_name: "Stop", cwd: "/tmp/proj"}' | bash "$SCRIPT")"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_eq "a root with no law prints nothing" "" "$(start startup /nonexistent)"
  assert_contains "and logs the missing law" " proj | law | missing | /nonexistent/law/engineering-law.md" "$(tail -n 1 "$LOG")"
  out=$(jq -cn '{hook_event_name: "SessionStart", source: "resume", cwd: "/tmp/proj"}' | ONELOOP_HOME="$FAKE" bash "$SCRIPT")
  assert_contains "the older source field still starts it" "Session resumed" "$(context "$out")"
}

build_fake_root || { printf 'FAIL could not build the fake root\n'; exit 1; }
test_a_fresh_start_carries_the_law
test_compact_and_resume_add_the_anchor
test_the_repositorys_own_law_ships_whole
test_nothing_to_serve_prints_nothing
report
