#!/bin/bash
# Fixture tests for session-start.sh. Run: bash hooks/tests/session-start.test.sh
# On every SessionStart reason the hook hands Claude Code the core law as additionalContext in
# two parts (hooks.json runs it with `1` and with `2`), because Claude Code keeps only a 2KB
# preview of a hook context above 10,000 characters: each part is headed by one line naming the
# part and its lines, the plugin version and the harness root; the split is the `## ` heading
# nearest the middle by characters, or the line nearest it when that heading would leave a part
# over the cap; the two parts together are the law byte for byte; after a compaction or a resume
# part 2 adds the re-anchor (the law is the law, a task in flight resumes at its loop step,
# nothing from before the loss counts as proof); a start it cannot serve (another event,
# malformed input, a part other than 1 or 2, a root with no law) prints nothing, logged.
# SESSION_START_SH points the test at another copy of the script, for a watched failure; the copy
# needs hook-input.sh and progress-log.sh beside it. ONELOOP_HOME points the hook at a root; the
# test builds one with a tiny law and its own manifest, one with a long law whose only heading
# sits at the top, and also serves the repository's own.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${SESSION_START_SH:-$here/../session-start.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
REAL=$(cd "$here/../.." && pwd)
FAKE="$WORK/root"
LONG="$WORK/long"
LIMIT=10000

build_fake_roots() {
  mkdir -p "$FAKE/law" "$FAKE/.claude-plugin" "$LONG/law" "$LONG/.claude-plugin" || return 1
  printf '# Engineering law (always on)\n\nLine two of a tiny law.\n' > "$FAKE/law/engineering-law.md"
  printf '{"name": "oneloop", "version": "0.0.1"}\n' > "$FAKE/.claude-plugin/plugin.json"
  awk 'BEGIN { print "# A long law"; print "## The only heading"; for (i = 1; i <= 170; i++) printf "Line %03d of a law that runs long, filling the file to near its cap.\n", i }' > "$LONG/law/engineering-law.md"
  cp "$FAKE/.claude-plugin/plugin.json" "$LONG/.claude-plugin/plugin.json"
}

# start <how_started> <part> [root]: the hook's output for that session start against the root.
start() {
  jq -cn --arg h "$1" '{hook_event_name: "SessionStart", how_started: $h, cwd: "/tmp/proj", transcript_path: "/nonexistent/t.jsonl"}' \
    | ONELOOP_HOME="${3:-$FAKE}" bash "$SCRIPT" "$2"
}

# context <output>: the additionalContext string of a decision.
context() { printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# part_text <how_started> <part> <root> <file>: that part's context written to the file byte for byte.
part_text() { start "$1" "$2" "$3" | jq -j '.hookSpecificOutput.additionalContext // empty' > "$4"; }

# law_of <part file> <file>: the law inside a part, the header line and the blank line under it off.
law_of() { sed '1,2d' "$1" > "$2"; }

# joined_is_the_law <root>: yes when the two parts of a fresh start, headers off, join into the
# root's law byte for byte; leaves the parts in p1 and p2 and their law in l1 and l2.
joined_is_the_law() {
  part_text startup 1 "$1" "$WORK/p1"
  part_text startup 2 "$1" "$WORK/p2"
  law_of "$WORK/p1" "$WORK/l1"
  law_of "$WORK/p2" "$WORK/l2"
  if cat "$WORK/l1" "$WORK/l2" | cmp -s - "$1/law/engineering-law.md"; then printf yes; else printf no; fi
}

# sizes <how_started> <root>: the byte counts of the two parts' contexts, "n1 n2".
sizes() {
  part_text "$1" 1 "$2" "$WORK/s1"
  part_text "$1" 2 "$2" "$WORK/s2"
  printf '%s %s' "$(wc -c < "$WORK/s1" | tr -d ' ')" "$(wc -c < "$WORK/s2" | tr -d ' ')"
}

# under <limit> "<n1> <n2>": yes when both counts are under the limit.
under() { printf '%s\n' "$2" | awk -v cap="$1" '{ print ($1 < cap && $2 < cap) ? "yes" : "no" }'; }

# starts_with_heading <file>: yes when the file's first line is a `## ` heading.
starts_with_heading() { if head -n 1 "$1" | grep -q '^## '; then printf yes; else printf no; fi; }

test_a_fresh_start_carries_the_law_in_two_parts() {
  out=$(start startup 1)
  assert_eq "the decision is for SessionStart" SessionStart "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
  head1=$(context "$out" | head -n 1)
  assert_contains "part 1's header names the plugin version and the part" "oneloop 0.0.1, the engineering law, always on, part 1 of 2" "$head1"
  assert_contains "its lines" "(lines 1 to 1 of law/engineering-law.md" "$head1"
  assert_contains "and the harness root" "Harness root: $FAKE" "$head1"
  assert_contains "part 1 is logged" " proj | law | startup | part 1" "$(tail -n 1 "$LOG")"
  head2=$(context "$(start startup 2)" | head -n 1)
  assert_contains "part 2's header names its part and lines" "part 2 of 2 (lines 2 to 3 of law/engineering-law.md" "$head2"
  assert_contains "and the root too" "Harness root: $FAKE" "$head2"
  assert_contains "part 2 is logged" " proj | law | startup | part 2" "$(tail -n 1 "$LOG")"
  assert_eq "the two parts, headers off, are the tiny law byte for byte" yes "$(joined_is_the_law "$FAKE")"
  assert_missing "no anchor on a fresh start" "resumes at the loop step" "$(cat "$WORK/p1" "$WORK/p2")"
}

test_compact_and_resume_anchor_part_two() {
  ctx=$(context "$(start compact 2)")
  assert_contains "compact says a summary is not the law" "Context was compacted. A summary of the law is not the law: the law in its two parts is the law." "$ctx"
  assert_contains "and resumes the loop with no proof carried over" "resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof." "$ctx"
  order=$(printf '%s\n' "$ctx" | awk '/Line two of a tiny law/ { law = NR } /Context was compacted/ { anchor = NR } END { print (law && anchor > law) ? "law then anchor" : "wrong" }')
  assert_eq "the anchor comes after the law" "law then anchor" "$order"
  assert_contains "is logged" " proj | law | compact | part 2" "$(tail -n 1 "$LOG")"
  assert_missing "part 1 carries no anchor" "Context was compacted" "$(context "$(start compact 1)")"
  assert_contains "resume says so" "Session resumed. A task that was in flight resumes" "$(context "$(start resume 2)")"
  for how in clear fork; do
    assert_missing "no anchor on $how" "resumes at the loop step" "$(context "$(start "$how" 2)")"
  done
  assert_contains "clear still carries the law" "Line two of a tiny law" "$(context "$(start clear 2)")"
}

test_the_repositorys_own_law_ships_whole_in_two_parts() {
  assert_eq "the repository's law is the two parts joined, byte for byte" yes "$(joined_is_the_law "$REAL")"
  assert_eq "part 2 begins at a heading" yes "$(starts_with_heading "$WORK/l2")"
  assert_eq "each part of a fresh start is under Claude Code's $LIMIT characters" yes "$(under "$LIMIT" "$(sizes startup "$REAL")")"
  assert_eq "and after a compaction, the anchor included" yes "$(under "$LIMIT" "$(sizes compact "$REAL")")"
  assert_contains "under the manifest's version" "oneloop $(jq -r .version "$REAL/.claude-plugin/plugin.json"), the engineering law" "$(head -n 1 "$WORK/p1")"
  assert_contains "and the real root" "Harness root: $REAL" "$(head -n 1 "$WORK/p2")"
}

test_a_lone_heading_at_the_top_does_not_pin_the_split() {
  assert_eq "the long law is the two parts joined" yes "$(joined_is_the_law "$LONG")"
  assert_eq "both parts stay under the limit" yes "$(under "$LIMIT" "$(sizes startup "$LONG")")"
  first=$(head -n 1 "$WORK/l2")
  assert_missing "so part 2 does not start at the lone heading" "## The only heading" "$first"
  assert_contains "but near the middle" "Line 08" "$first"
}

test_nothing_to_serve_prints_nothing() {
  assert_eq "another event prints nothing" "" "$(jq -cn '{hook_event_name: "Stop", cwd: "/tmp/proj"}' | bash "$SCRIPT" 1)"
  out=$(printf 'nope' | bash "$SCRIPT" 1 2>&1; printf 'exit=%s' "$?")
  assert_eq "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_eq "a root with no law prints nothing" "" "$(start startup 1 /nonexistent)"
  assert_contains "and logs the missing law" " proj | law | missing | /nonexistent/law/engineering-law.md" "$(tail -n 1 "$LOG")"
  assert_eq "a part that is not 1 or 2 prints nothing" "" "$(start startup 3)"
  assert_contains "and is logged" " proj | law | startup | part not 1 or 2" "$(tail -n 1 "$LOG")"
  assert_eq "no part at all prints nothing" "" "$(start startup "")"
  out=$(jq -cn '{hook_event_name: "SessionStart", source: "resume", cwd: "/tmp/proj"}' | ONELOOP_HOME="$FAKE" bash "$SCRIPT" 2)
  assert_contains "the older source field still starts it" "Session resumed" "$(context "$out")"
}

build_fake_roots || { printf 'FAIL could not build the fake roots\n'; exit 1; }
test_a_fresh_start_carries_the_law_in_two_parts
test_compact_and_resume_anchor_part_two
test_the_repositorys_own_law_ships_whole_in_two_parts
test_a_lone_heading_at_the_top_does_not_pin_the_split
test_nothing_to_serve_prints_nothing
report
