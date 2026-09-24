#!/bin/bash
# Guard: the lite workflow keeps the power of the one it replaced. Every row of the old
# workflow's own checklists (the nineteen-row self-audit, the exit artifact of every phase, the
# thirteen sweep classes, the review of 12.2 to 12.9, the coverage map and the ledger's rules)
# is listed in fixtures/workflow-power.txt with the file and the words that keep it now, and
# every one of those files must carry those words. A row is kept or merged, never dropped: a
# check the workflow stops running is a loosening, which needs the user's words and a changelog
# line. The workflow page also stays inside its size cap, since every call of the workflow pays
# for it. POWER points the test at another list, for a watched failure.
# Run: bash tests/workflow-power.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
POWER="${POWER:-$ROOT/tests/fixtures/workflow-power.txt}"
WORKFLOW="$ROOT/skills/engineering-rules/SKILL.md"
CHAR_CAP=16000

# rows: the list's rows, comments and blank lines left out.
rows() { grep -vE '^(#|$)' "$POWER"; }

# folded <file>: the file on one line, every run of whitespace folded into one space, so a pin
# matches across the line breaks of wrapped prose.
folded() { tr '\n' ' ' < "$1" | tr -s ' \t' ' '; }

# homeless: one line per row whose status is not kept or merged, whose file is missing, or whose
# file does not carry its words.
homeless() {
  rows | while IFS= read -r row; do
    status=$(printf '%s' "$row" | awk -F ' :: ' '{ print $2 }')
    file=$(printf '%s' "$row" | awk -F ' :: ' '{ print $3 }')
    text=$(printf '%s' "$row" | awk -F ' :: ' '{ for (i = 4; i <= NF; i++) printf "%s%s", (i > 4 ? " :: " : ""), $i }')
    case "$status" in kept|merged) ;; *) printf 'not kept or merged: %s\n' "$row"; continue ;; esac
    [ -f "$ROOT/$file" ] || { printf 'no such file: %s\n' "$row"; continue; }
    folded "$ROOT/$file" | grep -qF -- "$text" || printf 'no home: %s\n' "$row"
  done
}

test_every_old_row_has_a_home() {
  total=$(rows | grep -c .)
  assert_eq "the list holds the old checklists ($total rows)" yes "$([ "$total" -ge 60 ] && echo yes || echo no)"
  assert_eq "every row is kept or merged, in a file that carries its words" "" "$(homeless)"
}

test_the_workflow_stays_small() {
  chars=$(wc -c < "$WORKFLOW" | tr -d ' ')
  assert_eq "the workflow page is at most $CHAR_CAP characters ($chars)" yes "$([ "$chars" -le "$CHAR_CAP" ] && echo yes || echo no)"
}

# The check can fail: a dropped row, a row whose words are gone and a row naming a missing file
# are each named.
test_the_check_can_fail() {
  planted="$WORK/power.txt"
  {
    rows | head -n 3
    printf 'the old spec review :: dropped :: skills/engineering-rules/SKILL.md :: spec review\n'
    printf 'a rule nobody wrote :: kept :: skills/engineering-rules/SKILL.md :: words that are nowhere\n'
    printf 'a missing home :: kept :: agents/nobody.md :: anything\n'
  } > "$planted"
  out=$(POWER="$planted" homeless)
  assert_contains "a dropped row is named" "not kept or merged: the old spec review" "$out"
  assert_contains "a row whose words are gone is named" "no home: a rule nobody wrote" "$out"
  assert_contains "a row naming a missing file is named" "no such file: a missing home" "$out"
  assert_missing "and the kept rows are not" "audit 1," "$out"
}

test_every_old_row_has_a_home
test_the_workflow_stays_small
test_the_check_can_fail
report
