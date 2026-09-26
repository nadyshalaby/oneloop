#!/bin/bash
# Guard: the explain skill keeps the shape the user chose for every explanation: the problem,
# the pseudocode as a fenced block (14.2.0: numbered steps in prose are not it, and a
# plain-language rule never removes the block), the effect and the risks; inside the loop it is the Scope step's explanation
# and Edit follows at once, no yes waited for (14.0.0), as reply text, never a plan in the thinking (14.1.0); asked on its own it stops (the build runs
# the loop; the skill is no gate of its own since 10.0.0); never about tests, reviews or specs,
# and read-only (nothing run to try an idea). Run: bash tests/explain.test.sh
# EXPLAIN_MD points the test at another copy of the skill, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILL="${EXPLAIN_MD:-$ROOT/skills/explain/SKILL.md}"
PINS="**The problem.**
**Pseudocode.** The core logic only, in a fenced block
A numbered list of steps in prose is not pseudocode
the one place code-shaped text belongs
never removes the block
**Effect.**
**Risks.**
Inside the loop, Edit follows at once
a plan inside your thinking is not an explanation
Asked on its own, stop here: the build, when the user wants it, runs the loop
no yes is waited for
Never about tests, reviews, specs or process
Nothing is run to try an idea"

# missing_pins <file>: every pin the file does not carry, one per line, whitespace folded so a
# pin matches across the line breaks of wrapped prose.
missing_pins() {
  page=$(tr '\n' ' ' < "$1" | tr -s ' \t' ' ')
  printf '%s\n' "$PINS" | while IFS= read -r pin; do
    case "$page" in *"$pin"*) ;; *) printf '%s\n' "$pin" ;; esac
  done
}

test_the_shape_holds() {
  missing=$(missing_pins "$SKILL")
  assert_eq "every pin is in the skill" "<none>" "${missing:-<none>}"
}

# The check can fail: a copy that lost the read-only rule is named.
test_a_lost_rule_is_named() {
  grep -v 'Nothing is run to try' "$SKILL" > "$WORK/lost.md"
  assert_eq "the lost rule is named" "Nothing is run to try an idea" "$(missing_pins "$WORK/lost.md")"
}

test_the_shape_holds
test_a_lost_rule_is_named
report
