#!/bin/bash
# Guard: everything that reads or writes the work-doc agrees on its shape. The slim template on
# the workflow page is the only definition: four frontmatter keys (status, base, branch, next)
# and six sections in order (Goal, Done when, Plan, Log, Evidence, Follow-ups). The check-in
# line on the same page maps the user's check-in words onto those sections, and the re-anchor
# hook reads the same two keys a resumed session needs (status, next). Run:
# bash tests/work-doc-sections.test.sh. WORKFLOW_MD and RE_ANCHOR_SH point the test at other
# copies, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
WORKFLOW="${WORKFLOW_MD:-$ROOT/skills/workflow/SKILL.md}"
HOOK="${RE_ANCHOR_SH:-$ROOT/hooks/re-anchor.sh}"
KEYS="status base branch next"
HEADINGS="Goal|Done when|Plan|Log|Evidence|Follow-ups"
TICK=$(printf '\140')

# template <workflow>: the fenced block that follows the "**The work-doc**" line.
template() {
  awk '/^\*\*The work-doc\*\*/ { seek = 1; next }
       seek && /^```/ { if (inside) exit; inside = 1; next }
       inside { print }' "$1"
}

# template_keys <workflow>: the frontmatter keys of the template, space-separated.
template_keys() { template "$1" | sed -n '2,/^---$/p' | sed -n -E 's/^([a-z]+):.*/\1/p' | tr '\n' ' ' | sed 's/ $//'; }

# template_headings <workflow>: the template's `## ` headings, in order, joined by |.
template_headings() { template "$1" | sed -n 's/^## //p' | tr '\n' '|' | sed 's/|$//'; }

# folded <file>: the file on one line with its whitespace folded, so wrapped prose matches.
folded() { tr '\n' ' ' < "$1" | tr -s ' \t' ' '; }

test_the_template_has_its_shape() {
  assert_eq "the template's frontmatter keys" "$KEYS" "$(template_keys "$WORKFLOW")"
  assert_eq "the template's sections, in order" "$HEADINGS" "$(template_headings "$WORKFLOW")"
  assert_contains "status names the phases and done" "status: plan | implement | verify | done" "$(template "$WORKFLOW")"
}

test_the_check_in_maps_onto_it() {
  page=$(folded "$WORKFLOW")
  assert_contains "the check-in maps the backlog onto Plan" "its Plan boxes are the Sprint Backlog" "$page"
  assert_contains "the acceptance criteria onto Done when" "its Done-when boxes the Acceptance Criteria" "$page"
  assert_contains "the daily update onto a Log line" "a Log line the Daily Update" "$page"
  assert_contains "and the ledger onto status and next" "frontmatter ${TICK}status${TICK} and ${TICK}next${TICK} the phase ledger" "$page"
}

test_the_re_anchor_hook_reads_the_same_keys() {
  hook=$(cat "$HOOK")
  assert_contains "the hook reads status" "front \"\$doc\" status" "$hook"
  assert_contains "the hook reads next" "front \"\$doc\" next" "$hook"
}

# The checks can fail: a template that lost a section, one with two sections swapped and one
# that lost a key are each caught.
test_planted_breaches_are_named() {
  grep -v '^## Evidence$' "$WORKFLOW" > "$WORK/lost.md"
  assert_eq "a lost section changes the list" "Goal|Done when|Plan|Log|Follow-ups" "$(template_headings "$WORK/lost.md")"
  awk '/^## Log$/ { held = $0; next } held && /^## Evidence$/ { print; print held; held = ""; next } { print }' "$WORKFLOW" > "$WORK/swapped.md"
  assert_contains "swapped sections change the order" "Plan|Evidence|Log" "$(template_headings "$WORK/swapped.md")"
  grep -v '^next: <the step to take next>$' "$WORKFLOW" > "$WORK/keys.md"
  assert_eq "a lost key changes the keys" "status base branch" "$(template_keys "$WORK/keys.md")"
}

test_the_template_has_its_shape
test_the_check_in_maps_onto_it
test_the_re_anchor_hook_reads_the_same_keys
test_planted_breaches_are_named
report
