#!/bin/bash
# Guard: the demystify skill keeps the shape the user chose for every explanation: the problem,
# what I'd build, the effect and the risks, asked through AskUserQuestion with nothing built
# before a yes, never about tests, reviews or specs, and read-only until the yes (nothing run to
# try an idea). Run: bash tests/demystify.test.sh
# DEMYSTIFY_MD points the test at another copy of the skill, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILL="${DEMYSTIFY_MD:-$ROOT/skills/demystify/SKILL.md}"
TICK=$(printf '\140')
PINS="**The problem.**
**What I'd build.** Pseudocode of the core logic
**Effect.**
**Risks.**
ask through ${TICK}AskUserQuestion${TICK} whether this is the right logic
Build nothing before a yes.
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
