#!/bin/bash
# Guard: this repository's CLAUDE.md is the map the law asks every project for: the four check
# commands, the key directories, five to ten entry-point files that exist, the house
# conventions, under 60 lines, and a risk_regex line the risk-zone hook reads that covers the
# files a bad edit to would hurt a live system. Run: bash tests/claude-md.test.sh
# MAP_MD points the test at another copy, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
MAP="${MAP_MD:-$ROOT/CLAUDE.md}"
LINE_CAP=60
LINT='shellcheck -x -P SCRIPTDIR -S style bin/*.sh hooks/*.sh hooks/tests/*.sh tests/*.sh'
TICK=$(printf '\140')

# line_count <file>
line_count() { wc -l < "$1" | tr -d ' '; }

# missing_checks <map>: each of the four check lines the map lacks.
missing_checks() {
  for k in lint typecheck test ui_check; do
    grep -qE "^- $k: " "$1" || printf 'no %s line\n' "$k"
  done
}

# check_line <map> <key>: the command on the map's line for that key, backticks removed.
check_line() { sed -n -E "s/^- $2: *//p" "$1" | head -n 1 | tr -d '\140'; }

# entry_points <map>: the first backticked path of every bullet under "## Entry points".
entry_points() {
  awk -v t="$TICK" '/^## Entry points/ { on = 1; next } /^## / { on = 0 } on && index($0, "- " t) == 1 { print }' "$1" | sed -E "s/^- ${TICK}([^${TICK}]*)${TICK}.*/\\1/"
}

# missing_entries <map>: every entry point that is not a file or folder in the repository.
missing_entries() {
  entry_points "$1" | while IFS= read -r p; do [ -e "$ROOT/$p" ] || printf '%s\n' "$p"; done
}

# risk_regex <map>: the map's own line, as the hook reads it.
risk_regex() { sed -n -E 's/^risk_regex:[[:space:]]*//p' "$1" | head -n 1; }

# matches <regex> <path>: yes or no.
matches() { if printf '%s' "$2" | grep -qE -- "$1"; then echo yes; else echo no; fi; }

test_the_map_is_short_and_carries_the_checks() {
  lines=$(line_count "$MAP")
  if [ "$lines" -le "$LINE_CAP" ]; then within=yes; else within="no ($lines lines)"; fi
  assert_eq "the map is at most $LINE_CAP lines" yes "$within"
  assert_eq "it carries the four check lines" "" "$(missing_checks "$MAP")"
  assert_eq "the lint line is the repository's shellcheck command" "$LINT" "$(check_line "$MAP" lint)"
  assert_contains "the test line runs the test files" "*.test.sh" "$(check_line "$MAP" test)"
  assert_eq "typecheck and ui_check are named as none" "none none" "$(check_line "$MAP" typecheck) $(check_line "$MAP" ui_check)"
}

test_the_map_orients() {
  assert_contains "it names the key directories" "## Key directories" "$(cat "$MAP")"
  assert_contains "and the conventions" "## Conventions" "$(cat "$MAP")"
  n=$(entry_points "$MAP" | grep -c .)
  if [ "$n" -ge 5 ] && [ "$n" -le 10 ]; then band=yes; else band="no ($n)"; fi
  assert_eq "five to ten entry points" yes "$band"
  assert_eq "every entry point exists" "" "$(missing_entries "$MAP")"
}

test_the_risk_regex_covers_the_live_pieces() {
  re=$(risk_regex "$MAP")
  assert_eq "the map sets a risk regex" yes "$([ -n "$re" ] && echo yes || echo no)"
  assert_eq "the manifests, the wiring, a hook, the loop config and the status line setup are risk zones" "yes yes yes yes yes" "$(matches "$re" .claude-plugin/plugin.json) $(matches "$re" hooks/hooks.json) $(matches "$re" hooks/edit-guard.sh) $(matches "$re" settings/loop.json) $(matches "$re" bin/setup-statusline.sh)"
  assert_eq "the law, a page and a hook test are not" "no no no" "$(matches "$re" law/engineering-law.md) $(matches "$re" references/02-doctrine/2.1-code-quality-the-full-doctrine.md) $(matches "$re" hooks/tests/edit-guard.test.sh)"
}

# The checks can fail: a copy over the cap, one without a test line, and one whose entry point
# names a missing file are each named.
test_planted_breaches_are_named() {
  { cat "$MAP"; awk 'BEGIN { for (i = 0; i < 61; i++) print "filler" }'; } > "$WORK/long.md"
  if [ "$(line_count "$WORK/long.md")" -le "$LINE_CAP" ]; then within=yes; else within=no; fi
  assert_eq "a copy over the cap is refused" no "$within"
  grep -vE '^- test: ' "$MAP" > "$WORK/no-test.md"
  assert_eq "a copy without a test line is named" "no test line" "$(missing_checks "$WORK/no-test.md")"
  { cat "$MAP"; printf '\n## Entry points\n\n- %sno/such/file.sh%s: nothing.\n' "$TICK" "$TICK"; } > "$WORK/ghost.md"
  assert_contains "a missing entry point is named" "no/such/file.sh" "$(missing_entries "$WORK/ghost.md")"
}

test_the_map_is_short_and_carries_the_checks
test_the_map_orients
test_the_risk_regex_covers_the_live_pieces
test_planted_breaches_are_named
report
