#!/bin/bash
# Fixture tests for statusline.sh. Run: bash hooks/tests/statusline.test.sh
# STATUSLINE_SH points the test at another copy of the script, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${STATUSLINE_SH:-$here/../statusline.sh}"
export TMPDIR="$WORK"
T="$WORK/transcript.jsonl"
C="$WORK/compacted.jsonl"
PROJECT=${WORK##*/}

render() {
  printf '%s' "$1" | bash "$SCRIPT" | sed $'s/\e\\[[0-9;]*m//g'
}

build_status_json() {
  printf '{"cwd":"%s","transcript_path":"%s","model":{"display_name":"Fable 5.1"},"context_window":{"used_percentage":%s}}' "$WORK" "$T" "$1"
}

build_usage_json() {
  printf '{"cwd":"%s","rate_limits":{%s}}' "$WORK" "$1"
}

build_compact_json() {
  printf '{"cwd":"%s","transcript_path":"%s"}' "$WORK" "$C"
}

# row <n> <render output>: one row of the status line.
row() {
  printf '%s\n' "$2" | sed -n "${1}p"
}

# count_rows <json>: the rows the script prints, counted before command substitution can drop
# a blank one at the end.
count_rows() {
  printf '%s' "$1" | bash "$SCRIPT" | wc -l | tr -d ' '
}

# compact_boundary <trigger>: the line Claude Code writes into the transcript on a compaction.
compact_boundary() {
  printf '{"type":"system","subtype":"compact_boundary","content":"Conversation compacted","compactMetadata":{"trigger":"%s","preTokens":180000}}\n' "$1"
}

test_bare_render() {
  line=$(render "{\"cwd\":\"$WORK\"}")
  assert_contains "renders the directory with nothing else available" "➜ $PROJECT" "$line"
  assert_missing "no transcript means no ledger segment" "Phase" "$line"
  assert_missing "no rate_limits means no usage segment" "5h:" "$line"
  assert_missing "no transcript means no compaction segment" "compacted" "$line"
  assert_eq "nothing to measure means no second row, not even a blank one" "1" "$(count_rows "{\"cwd\":\"$WORK\"}")"
}

test_context_bar() {
  line=$(render "$(build_status_json 42)")
  assert_contains "context bar at 42%" "━━━━╌╌╌╌╌╌ 42%" "$line"
  assert_contains "model name" "Fable 5.1" "$line"
  assert_eq "the top row says where you are" "➜ $PROJECT  │ Fable 5.1" "$(row 1 "$line")"
  assert_eq "the meters row opens with the bar and no separator" "━━━━╌╌╌╌╌╌ 42%" "$(row 2 "$line")"
  line=$(render "$(build_status_json 100)")
  assert_contains "context bar at 100% is full and never negative" "━━━━━━━━━━ 100%" "$line"
}

test_ledger_position() {
  printf '%s\n' '{"timestamp":"2026-09-05T00:00:00.000Z"}' '{"type":"assistant","text":"## 0. Phase ledger  (2 of 6, Phase 3)\n- [>] 2"}' > "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "first heading is found" "(2 of 6, Phase 3)" "$line"
  assert_contains "uptime is shown" "up " "$line"
  printf '%s\n' '{"type":"assistant","text":"## 0. Phase ledger  (4 of 6, Phase 5)\n- [>] 4"}' >> "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "a heading appended after the first render is picked up" "(4 of 6, Phase 5)" "$line"
  line=$(render "$(build_status_json 10)")
  assert_contains "an unchanged transcript keeps the position" "(4 of 6, Phase 5)" "$line"
  printf '%s\n' '{"type":"user","text":"nothing new"}' >> "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "new bytes without a heading keep the position" "(4 of 6, Phase 5)" "$line"
}

test_replaced_transcript() {
  printf '%s\n' '{"timestamp":"2026-09-05T01:00:00.000Z"}' '{"type":"assistant","text":"## 0. Phase ledger  (1 of 6, Phase 1)"}' > "$T"
  line=$(render "$(build_status_json 10)")
  assert_contains "a transcript that shrank resets the cursor" "(1 of 6, Phase 1)" "$line"
  assert_missing "and forgets the old position" "(4 of 6, Phase 5)" "$line"
}

test_malformed_input() {
  line=$(printf 'not json' | bash "$SCRIPT" | sed $'s/\e\\[[0-9;]*m//g'; printf 'exit=%s' "${PIPESTATUS[1]}")
  assert_contains "malformed stdin still renders and exits 0" "➜ " "$line"
  assert_contains "malformed stdin exit code" "exit=0" "$line"
}

test_usage_windows() {
  line=$(render "$(build_usage_json '"five_hour":{"used_percentage":23.4,"resets_at":1738425600},"seven_day":{"used_percentage":61.6,"resets_at":1738857600}')")
  assert_eq "both usage windows, rounded, on the meters row" "5h:23% 7d:62%" "$(row 2 "$line")"
  line=$(render "$(build_usage_json '"seven_day":{"used_percentage":80}')")
  assert_eq "a window sent on its own is shown" "7d:80%" "$(row 2 "$line")"
  assert_missing "and the one left out is not" "5h:" "$line"
  raw=$(printf '%s' "$(build_usage_json '"five_hour":{"used_percentage":80}')" | bash "$SCRIPT")
  assert_contains "a window at 75% or more is red, like the context bar" $'5h:\e[0m\e[0;31m80%' "$raw"
  line=$(render "$(build_usage_json '"five_hour":{"used_percentage":"soon"}')")
  assert_missing "a percentage that is not a number is left out" "5h:" "$line"
}

test_compaction_count() {
  printf '%s\n' '{"type":"user","text":"hello"}' > "$C"
  line=$(render "$(build_compact_json)")
  assert_missing "no compaction yet means no segment" "compacted" "$line"
  compact_boundary manual >> "$C"
  line=$(render "$(build_compact_json)")
  assert_eq "a manual compaction is counted on the meters row" "compacted 1x" "$(row 2 "$line")"
  assert_missing "and is not called automatic" "auto)" "$line"
  { compact_boundary auto; printf '%s\n' '{"type":"user","text":"after"}'; } >> "$C"
  line=$(render "$(build_compact_json)")
  assert_contains "an automatic one appended later adds to the count" "compacted 2x (1 auto)" "$line"
  line=$(render "$(build_compact_json)")
  assert_contains "an unchanged transcript keeps the count and never doubles it" "compacted 2x (1 auto)" "$line"
  printf '%s\n' '{"type":"user","content":"{\"type\":\"system\",\"subtype\":\"compact_boundary\",\"compactMetadata\":{\"trigger\":\"auto\"}}"}' >> "$C"
  line=$(render "$(build_compact_json)")
  assert_contains "a marker quoted inside a message is not a compaction" "compacted 2x (1 auto)" "$line"
}

test_half_written_line() {
  compact_boundary auto | tr -d '\n' >> "$C"
  line=$(render "$(build_compact_json)")
  assert_contains "a line still being written waits for the next render" "compacted 2x (1 auto)" "$line"
  printf '\n' >> "$C"
  line=$(render "$(build_compact_json)")
  assert_contains "and is counted once it ends" "compacted 3x (2 auto)" "$line"
  line=$(render "$(build_compact_json)")
  assert_contains "and only once" "compacted 3x (2 auto)" "$line"
}

test_compaction_cursor_resets() {
  compact_boundary auto > "$C"
  line=$(render "$(build_compact_json)")
  assert_contains "a transcript that shrank is counted afresh" "compacted 1x (1 auto)" "$line"
  printf 'not a cursor\n' > "$WORK/engineering-rules-compactions-$(printf '%s' "$C" | cksum | cut -d ' ' -f 1)"
  line=$(render "$(build_compact_json)")
  assert_contains "a broken cursor file is counted afresh" "compacted 1x (1 auto)" "$line"
}

test_two_rows() {
  full="$WORK/full.jsonl"
  { printf '%s\n' '{"timestamp":"2026-09-05T00:00:00.000Z"}' '{"type":"assistant","text":"## 0. Phase ledger  (5 of 6, Phase 6)"}'; compact_boundary auto; } > "$full"
  json="{\"cwd\":\"$WORK\",\"transcript_path\":\"$full\",\"model\":{\"display_name\":\"Fable 5.1\"},\"context_window\":{\"used_percentage\":42},\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.4}}}"
  line=$(render "$json")
  assert_eq "exactly two rows" "2" "$(count_rows "$json")"
  assert_eq "the top row holds the folder, the model and the phase" "➜ $PROJECT  │ Fable 5.1  │ (5 of 6, Phase 6)" "$(row 1 "$line")"
  assert_contains "the meters row opens with the bar, then the uptime" "━━━━╌╌╌╌╌╌ 42%  │ up " "$(row 2 "$line")"
  assert_contains "and ends with the usage and the compactions" "  │ 5h:23%  │ compacted 1x (1 auto)" "$(row 2 "$line")"
}

test_bare_render
test_context_bar
test_ledger_position
test_replaced_transcript
test_malformed_input
test_usage_windows
test_compaction_count
test_half_written_line
test_compaction_cursor_resets
test_two_rows
report
