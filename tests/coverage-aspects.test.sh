#!/bin/bash
# Guard: the workflow's coverage line and the coverage map page (6.15) name the same sixteen
# aspects in the same order, so the one line every Plan writes and the full map a risky task
# walks can never drift apart. The line's list is the parenthesis after "each aspect the task
# touches"; the map's is the Aspect column of its numbered table. Case is ignored.
# Run: bash tests/coverage-aspects.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
WORKFLOW="$ROOT/skills/workflow/SKILL.md"
MAP=$(find "$ROOT/references" -name '6.15-*.md' | head -n 1)

# line_aspects <workflow page>: the coverage line's aspects, one per line, lowercased. A page
# whose line no longer reads "each aspect the task touches (" prints whole, and so never matches.
line_aspects() {
  tr '\n' ' ' < "$1" | sed -E 's/.*each aspect the task touches \(([^)]*)\).*/\1/' \
    | tr ',' '\n' | sed -E 's/  +/ /g; s/^ //; s/ $//' | tr '[:upper:]' '[:lower:]'
}

# map_aspects <map page>: the Aspect column of the map's numbered table, one per line, lowercased.
map_aspects() {
  awk -F'|' '/^\| *[0-9]+ *\|/ { gsub(/^ +| +$/, "", $3); print tolower($3) }' "$1"
}

test_the_map_has_sixteen() {
  assert_eq "the map names sixteen aspects" "16" "$(map_aspects "$MAP" | grep -c .)"
}

test_the_line_and_the_map_agree() {
  assert_eq "the coverage line names the map's aspects, in order" "$(map_aspects "$MAP")" \
    "$(line_aspects "$WORKFLOW")"
}

# The check can fail: a copy of the workflow page with one aspect renamed is caught.
test_a_planted_rename_is_caught() {
  sed 's/, failures,/, failure paths,/' "$WORKFLOW" > "$WORK/workflow.md"
  assert_contains "the planted copy names the renamed aspect" "failure paths" \
    "$(line_aspects "$WORK/workflow.md")"
  verdict=same
  [ "$(map_aspects "$MAP")" = "$(line_aspects "$WORK/workflow.md")" ] || verdict=different
  assert_eq "a renamed aspect is told apart" "different" "$verdict"
}

test_the_map_has_sixteen
test_the_line_and_the_map_agree
test_a_planted_rename_is_caught
report
