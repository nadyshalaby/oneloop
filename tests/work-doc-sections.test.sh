#!/bin/bash
# Guard: everything that reads or writes the work-doc agrees on its shape. The slim template on
# the workflow page is the only definition: four frontmatter keys (status, base, branch, next)
# and six sections in order (Goal, Done when, Plan, Log, Evidence, Follow-ups), and the page
# names none of the old work-doc parts those sections replaced; the re-anchor hook reads the
# same two keys a resumed session needs (status, next). Run:
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

# old_parts <workflow>: every old work-doc part the page still names, one per line.
old_parts() {
  page=$(folded "$1")
  for part in "Sprint Backlog" "Acceptance Criteria" "Daily Update" "Evidence Ledger" "Retrospective" "full mode"; do
    case "$page" in *"$part"*) printf '%s\n' "$part" ;; esac
  done
}

test_no_old_part_is_named() {
  named=$(old_parts "$WORKFLOW" | tr '\n' ' ' | sed 's/ $//')
  assert_eq "the page names no old work-doc part" "<none>" "${named:-<none>}"
}

test_the_re_anchor_hook_reads_the_same_keys() {
  hook=$(cat "$HOOK")
  assert_contains "the hook reads status" "front \"\$doc\" status" "$hook"
  assert_contains "the hook reads next" "front \"\$doc\" next" "$hook"
}

# The checks can fail: a template that lost a section, one with two sections swapped, one
# that lost a key and a page that names an old part again are each caught.
test_planted_breaches_are_named() {
  grep -v '^## Evidence$' "$WORKFLOW" > "$WORK/lost.md"
  assert_eq "a lost section changes the list" "Goal|Done when|Plan|Log|Follow-ups" "$(template_headings "$WORK/lost.md")"
  awk '/^## Log$/ { held = $0; next } held && /^## Evidence$/ { print; print held; held = ""; next } { print }' "$WORKFLOW" > "$WORK/swapped.md"
  assert_contains "swapped sections change the order" "Plan|Evidence|Log" "$(template_headings "$WORK/swapped.md")"
  grep -v '^next: <the step to take next>$' "$WORKFLOW" > "$WORK/keys.md"
  assert_eq "a lost key changes the keys" "status base branch" "$(template_keys "$WORK/keys.md")"
  { cat "$WORKFLOW"; printf 'its Plan boxes are the Sprint Backlog\n'; } > "$WORK/old.md"
  assert_eq "an old part named again is caught" "Sprint Backlog" "$(old_parts "$WORK/old.md")"
}

test_the_template_has_its_shape
test_no_old_part_is_named
test_the_re_anchor_hook_reads_the_same_keys
test_planted_breaches_are_named
report
