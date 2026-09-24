#!/bin/bash
# Fixture tests for re-anchor.sh. Run: bash hooks/tests/re-anchor.test.sh
# RE_ANCHOR_SH points the test at another copy of the script, for a watched failure; the copy
# needs hook-input.sh, progress-log.sh and ledger-position.sh beside it.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${RE_ANCHOR_SH:-$here/../re-anchor.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
T="$WORK/transcript.jsonl"

# start <how_started> <transcript path>: what the hook prints for that session start.
start() {
  jq -cn --arg h "$1" --arg t "$2" '{hook_event_name:"SessionStart",how_started:$h,cwd:"/tmp/proj",transcript_path:$t}' | bash "$SCRIPT"
}

# skill_path <output>: the path the first line tells Claude to read.
skill_path() {
  printf '%s\n' "$1" | head -n 1 | sed -E 's/.*step 7\): //'
}

test_compact_carries_the_last_position() {
  { reply_line $'## 0. Phase ledger  (2 of 6, Phase 3)\n- [>] 2'; reply_line 'more'; reply_line $'## 0. Phase ledger  (3 of 6, Phase 4)\n- [>] 3'; } > "$T"
  out=$(start compact "$T")
  assert_contains "names the event" "engineering-rules re-anchor (context was compacted)" "$out"
  assert_contains "cites the re-read rule" "read it from disk before the next step (1.7, step 7)" "$out"
  assert_contains "names the code rules in the config dir" "before writing code, read them from disk unless they are verbatim in your context: $WORK/config/rules/engineering-code.md" "$out"
  assert_contains "carries the last position, not the first" "Last phase-ledger position printed before the loss: (3 of 6, Phase 4)" "$out"
  assert_missing "and not the earlier one" "(2 of 6, Phase 3)" "$out"
  path=$(skill_path "$out")
  if [ -f "$path" ]; then found=exists; else found="missing: $path"; fi
  assert_contains "the path it names is a real file" "exists" "$found"
  case "$path" in /*) shape=absolute ;; *) shape="relative: $path" ;; esac
  assert_contains "and an absolute one" "absolute" "$shape"
  assert_contains "is logged with the position" " proj | anchor | compact | (3 of 6, Phase 4)" "$(cat "$LOG")"
}

test_resume_without_a_position() {
  reply_line 'no ledger here' > "$T"
  out=$(start resume "$T")
  assert_contains "names the event" "engineering-rules re-anchor (session resumed)" "$out"
  assert_contains "says no position was found" "No phase-ledger position was found in the transcript" "$out"
  assert_contains "is logged without a position" " proj | anchor | resume | no ledger position" "$(tail -n 1 "$LOG")"
  out=$(start compact "$WORK/not-there.jsonl")
  assert_contains "a missing transcript still re-anchors" "(context was compacted)" "$out"
  assert_contains "and says no position was found" "No phase-ledger position" "$out"
}

# A heading Claude only quoted, in a file it wrote or read, is no position: the last one it
# printed in a reply wins, a transcript of quotes alone has none, and a line the byte window
# cut short is skipped rather than misread.
test_quoted_headings_are_not_positions() {
  { reply_line '## 0. Phase ledger  (2 of 6, Phase 3)'; quoted_line '## 0. Phase ledger  (5 of 6, Phase 6)'; } > "$T"
  out=$(start compact "$T")
  assert_contains "the last position Claude printed wins" "Last phase-ledger position printed before the loss: (2 of 6, Phase 3)" "$out"
  assert_missing "over a later one it only quoted" "(5 of 6, Phase 6)" "$out"
  quoted_line '## 0. Phase ledger  (3 of 6, Phase 4)' > "$T"
  out=$(start compact "$T")
  assert_contains "quotes alone are no position" "No phase-ledger position was found in the transcript" "$out"
  { printf '%s\n' 'xt","text":"## 0. Phase ledger  (6 of 6, Phase 6)"}]}}'; reply_line '## 0. Phase ledger  (1 of 6, Phase 1)'; } > "$T"
  out=$(start compact "$T")
  assert_contains "a whole line is read" "(1 of 6, Phase 1)" "$out"
  assert_missing "a cut-short one is not" "(6 of 6, Phase 6)" "$out"
}

# The workflow's own heading format, quoted with letters for the counts, is no position; a
# three-phase heading is.
test_a_placeholder_is_no_position() {
  reply_line '## 0. Phase ledger  (N of 3, <Phase>)' > "$T"
  out=$(start compact "$T")
  assert_contains "a placeholder heading is no position" "No phase-ledger position was found in the transcript" "$out"
  { reply_line '## 0. Phase ledger  (2 of 3, Implement)'; reply_line '## 0. Phase ledger  (N of 3, <Phase>)'; } > "$T"
  out=$(start compact "$T")
  assert_contains "a three-phase heading is read" "Last phase-ledger position printed before the loss: (2 of 3, Implement)" "$out"
}

# A work-doc still in flight is named with its status and next step; one marked done, and the
# archive under done/, are not.
test_an_in_flight_work_doc_is_named() {
  proj="$WORK/proj"; mkdir -p "$proj/docs/work/done"
  printf -- '---\nstatus: implement\nbase: abc\nnext: task 2, the parser\n---\n# x\n' > "$proj/docs/work/2026-09-24-parser.md"
  printf -- '---\nstatus: done\nnext: none\n---\n# y\n' > "$proj/docs/work/2026-09-20-old.md"
  printf -- '---\nstatus: implement\nnext: archived\n---\n# z\n' > "$proj/docs/work/done/2026-09-01-archived.md"
  reply_line 'nothing' > "$T"
  out=$(jq -cn --arg t "$T" --arg d "$proj" '{hook_event_name:"SessionStart",how_started:"compact",cwd:$d,transcript_path:$t}' | bash "$SCRIPT")
  assert_contains "the in-flight work-doc is named with its next step" "In-flight work-doc: $proj/docs/work/2026-09-24-parser.md (status: implement; next: task 2, the parser)" "$out"
  assert_missing "a done one is not" "2026-09-20-old.md" "$out"
  assert_missing "nor the archive" "archived" "$out"
}

test_other_starts_and_bad_input_print_nothing() {
  assert_eq "a fresh start prints nothing" "" "$(start startup "$T")"
  assert_eq "a cleared session prints nothing" "" "$(start clear "$T")"
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints nothing" "re-anchor" "$out"
  out=$(jq -cn '{hook_event_name:"Stop",cwd:"/tmp/proj"}' | bash "$SCRIPT")
  assert_eq "another event prints nothing" "" "$out"
}

test_source_field_and_the_home_variable() {
  out=$(jq -cn --arg t "$T" '{hook_event_name:"SessionStart",source:"resume",cwd:"/tmp/proj",transcript_path:$t}' | bash "$SCRIPT")
  assert_contains "the older source field still starts it" "(session resumed)" "$out"
  out=$(jq -cn --arg t "$T" '{hook_event_name:"SessionStart",how_started:"compact",cwd:"/tmp/proj",transcript_path:$t}' | ENGINEERING_RULES_HOME=/opt/er bash "$SCRIPT")
  assert_contains "the home variable decides the path" "/opt/er/law/engineering-law.md" "$out"
}

test_compact_carries_the_last_position
test_resume_without_a_position
test_quoted_headings_are_not_positions
test_a_placeholder_is_no_position
test_an_in_flight_work_doc_is_named
test_other_starts_and_bad_input_print_nothing
test_source_field_and_the_home_variable
report
