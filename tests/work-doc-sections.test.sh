#!/bin/bash
# Guard: the law agrees with itself about the work-doc's sections. The template in 7.2 is the
# only definition; 7.1's table tells the planner what to write and 5.5's planner prompt tells
# it what to check, and both are compared against the template heading by heading. This is the
# check that was missing when 7.1 numbered Primary Goal & Guardrails as section 2 and ended at
# a section 9 the template never had, so every later citation pointed at the wrong block.
# Run: bash tests/work-doc-sections.test.sh
# TEMPLATE_MD, PLAN_MD and DELEGATION_MD point the test at another copy, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
REF=$ROOT/references
TEMPLATE="${TEMPLATE_MD:-$REF/07-phase-2-plan/7.2-the-work-doc-template.md}"
PLAN="${PLAN_MD:-$REF/07-phase-2-plan/7.1-phase-2-plan.md}"
DELEGATION="${DELEGATION_MD:-$REF/05-working-references/5.5-the-phase-agents-what-this-session-keeps.md}"
TICK=$(printf '\140')

# template_headings: the `## ` headings of the skeleton itself, in order, one per line. The
# skeleton runs from its fence to the prose that documents it; a nested fence inside the
# skeleton is why this stops at that prose rather than at the first closing fence.
template_headings() {
  awk '/^```markdown$/ { inside = 1; next }
       inside && /^## Current-shape conformance/ { exit }
       inside && /^## / { print }' "$1"
}

# same_or_differs <a> <b>: the word "same" when two heading lists match, else "differs".
same_or_differs() { [ "$1" = "$2" ] && printf same || printf differs; }

# plan_headings: the headings 7.1's table names, in the order its rows list them.
plan_headings() {
  sed -n '/^## What the doc says when it is right/,/^## Rules/p' "$1" |
    tr -d "$TICK" | sed -n 's/^| \(## [^|]*[^| ]\) *|.*/\1/p'
}

# prompt_headings: the headings the planner prompt's shape pass names, in order.
prompt_headings() {
  sed -n '/^1\. \*\*Shape\.\*\*/,/^2\. /p' "$1" | grep -o "$TICK## [^$TICK]*$TICK" | tr -d "$TICK"
}

test_the_plan_table_is_the_template() {
  assert_eq "7.1's table names the template's headings, in its order" "$(template_headings "$TEMPLATE")" "$(plan_headings "$PLAN")"
}

test_the_prompt_lists_every_template_heading() {
  missing=$(comm -23 <(template_headings "$TEMPLATE" | sort) <(prompt_headings "$DELEGATION" | sort))
  assert_eq "the planner prompt's shape pass names every heading" "" "$missing"
}

test_the_template_has_no_section_nine() {
  assert_missing "the template defines no section 9" "## 9." "$(template_headings "$TEMPLATE")"
  assert_contains "Primary Goal & Guardrails carries no number" "## Primary Goal & Guardrails" "$(template_headings "$TEMPLATE")"
}

# The checks have to be able to fail: a renumbered heading, a dropped row and a heading the
# prompt never names are each named.
test_planted_breaches_are_named() {
  sed "s/^| $TICK## 2\\. Clarifying/| $TICK## 3. Clarifying/" "$PLAN" > "$WORK/7.1.md"
  PLAN=$WORK/7.1.md
  assert_eq "a renumbered heading in 7.1 is named" differs "$(same_or_differs "$(template_headings "$TEMPLATE")" "$(plan_headings "$PLAN")")"
  PLAN=$REF/07-phase-2-plan/7.1-phase-2-plan.md

  grep -v "$TICK## 8\\. Retrospective$TICK" "$PLAN" > "$WORK/7.1-short.md"
  PLAN=$WORK/7.1-short.md
  assert_eq "a heading 7.1 forgot is named" differs "$(same_or_differs "$(template_headings "$TEMPLATE")" "$(plan_headings "$PLAN")")"
  PLAN=$REF/07-phase-2-plan/7.1-phase-2-plan.md

  printf '1. **Shape.** Every heading is present: %s## 0. Phase ledger%s.\n2. next\n' "$TICK" "$TICK" > "$WORK/5.5.md"
  DELEGATION=$WORK/5.5.md
  missing=$(comm -23 <(template_headings "$TEMPLATE" | sort) <(prompt_headings "$DELEGATION" | sort))
  assert_contains "a prompt missing a heading is named" "## 8. Retrospective" "$missing"
  DELEGATION=$REF/05-working-references/5.5-the-phase-agents-what-this-session-keeps.md
}

test_the_plan_table_is_the_template
test_the_prompt_lists_every_template_heading
test_the_template_has_no_section_nine
test_planted_breaches_are_named
report
