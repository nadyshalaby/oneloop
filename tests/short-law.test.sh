#!/bin/bash
# Guard: the law keeps every rule the long form pins, stays small, and carries no text the
# CLAUDE.md import parser would read as an import. It is two files. The core, which CLAUDE.md
# loads into every session and every helper, and the code rules, which install.sh copies into
# the user's rules folder so Claude Code loads them the first time a code file is read. Both
# are compacted; a compaction that drops a banned token, a cap, a guardrail, a git rule, a
# banned phrase or a deploy proof fails here instead of silently loosening the law. The pins
# are data, one per line, in fixtures/short-law-pins.txt (the core) and
# fixtures/code-rules-pins.txt (the code rules), because a code file listing banned tokens
# reads as using them. The wording the no-chase rule (1.9) retired, in
# fixtures/short-law-absent.txt, must stay out of both law files and the workflow skill, so a
# later edit cannot bring a chase back.
# LAW_MD, PINS, CODE_MD, CODE_PINS, WORKFLOW_MD and ABSENT point the test at other copies,
# which is how it proves it can fail.
# Run: bash tests/short-law.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
LAW="${LAW_MD:-$ROOT/law/engineering-law.md}"
PINS="${PINS:-$ROOT/tests/fixtures/short-law-pins.txt}"
CODE="${CODE_MD:-$ROOT/law/engineering-code.md}"
CODE_PINS="${CODE_PINS:-$ROOT/tests/fixtures/code-rules-pins.txt}"
WORKFLOW="${WORKFLOW_MD:-$ROOT/skills/workflow/SKILL.md}"
ABSENT="${ABSENT:-$ROOT/tests/fixtures/short-law-absent.txt}"
LINE_CAP=90
CHAR_CAP=10000
CODE_LINE_CAP=60
CODE_CHAR_CAP=7600

# listed <file>: the lines of a list file, comments and blank lines left out.
listed() {
  grep -vE '^(#|$)' "$1"
}

# missing_pins <pins> <file>: every pinned string the file does not carry, one per line.
missing_pins() {
  listed "$1" | while IFS= read -r pin; do
    grep -qF -- "$pin" "$2" || printf '%s\n' "$pin"
  done
}

# retired_present <file>: every retired string the file still carries, one per line.
retired_present() {
  listed "$ABSENT" | while IFS= read -r retired; do
    if grep -qF -- "$retired" "$1"; then printf '%s\n' "$retired"; fi
  done
}

# stray_imports <file>: lines with an @ outside backticks, which CLAUDE.md would try to import.
stray_imports() {
  perl -ne 'my $l = $_; $l =~ s/`[^`]*`//g; print "$.: $_" if $l =~ /\@/' "$1"
}

# at_most <value> <cap>: yes when the value is within the cap.
at_most() {
  if [ "$1" -le "$2" ]; then echo yes; else echo no; fi
}

# more_than <value> <floor>: yes when the value is above the floor.
more_than() {
  if [ "$1" -gt "$2" ]; then echo yes; else echo no; fi
}

# front_matter <file>: the lines between a first-line --- and the next ---, nothing when the
# file does not open with one.
front_matter() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

# path_globs <file>: the quoted globs listed under the front matter's paths: key.
path_globs() {
  front_matter "$1" | awk '/^paths:/ { on = 1; next } on && /^  - "/ { print; next } { on = 0 }'
}

# path_extensions <file>: the extensions inside the braces of those globs, one per line.
path_extensions() {
  path_globs "$1" | sed -E 's/.*\{//; s/\}.*//' | tr ',' '\n'
}

# size_check <label> <file> <line cap> <char cap>: the two size asserts for one file.
size_check() {
  lines=$(wc -l < "$2" | tr -d ' ')
  chars=$(wc -c < "$2" | tr -d ' ')
  assert_eq "$1 is at most $3 lines ($lines)" yes "$(at_most "$lines" "$3")"
  assert_eq "$1 is at most $4 characters ($chars)" yes "$(at_most "$chars" "$4")"
}

test_every_rule_is_pinned() {
  core=$(listed "$PINS" | grep -c .)
  code=$(listed "$CODE_PINS" | grep -c .)
  assert_eq "the core pin list is not empty" yes "$(more_than "$core" 50)"
  assert_eq "the code pin list is not empty" yes "$(more_than "$code" 50)"
  assert_eq "every one of the $core core pins is in the core law" "" "$(missing_pins "$PINS" "$LAW")"
  assert_eq "every one of the $code code pins is in the code rules" "" "$(missing_pins "$CODE_PINS" "$CODE")"
}

test_size_caps() {
  size_check "the core law" "$LAW" "$LINE_CAP" "$CHAR_CAP"
  size_check "the code rules file" "$CODE" "$CODE_LINE_CAP" "$CODE_CHAR_CAP"
}

test_no_retired_wording() {
  assert_eq "the retired list is not empty" yes "$(more_than "$(listed "$ABSENT" | grep -c .)" 3)"
  assert_eq "the core law carries none of the retired wording" "" "$(retired_present "$LAW")"
  assert_eq "nor do the code rules" "" "$(retired_present "$CODE")"
  assert_eq "nor does the workflow skill" "" "$(retired_present "$WORKFLOW")"
}

test_no_stray_imports() {
  assert_eq "no @ outside backticks in the core law" "" "$(stray_imports "$LAW")"
  assert_eq "nor in the code rules" "" "$(stray_imports "$CODE")"
}

# The code rules load only through their front matter: a paths: list of globs that covers the
# common code files, and the managed-by line install.sh reads to tell its own copy from a file
# the user wrote. The core has none, because CLAUDE.md imports it whole.
test_code_rules_front_matter() {
  assert_eq "the code rules list globs under paths:" yes "$(more_than "$(path_globs "$CODE" | grep -c .)" 0)"
  extensions=$(path_extensions "$CODE")
  for ext in ts tsx js py go rs java rb php sh sql css html; do
    assert_eq "and the globs cover .$ext" "$ext" "$(printf '%s\n' "$extensions" | grep -x -- "$ext")"
  done
  assert_contains "the code rules name their installer" "managed-by: engineering-rules" "$(front_matter "$CODE")"
  assert_eq "the core law has no front matter" "" "$(front_matter "$LAW")"
}

# The checks above can fail: a copy with one pin removed, one import-shaped line, one retired
# line and too many lines is refused on all four counts, for the core and the code rules both;
# a code copy whose front matter lost its paths and its marker is refused on both.
test_the_checks_can_fail() {
  planted="$WORK/planted.md"
  {
    grep -vF 'Batch bulk writes' "$CODE"
    grep -vF 'booted against a production-like copy' "$LAW"
    printf 'see @docs/notes.md for more\n'
    printf 'Dead code goes in its own cleanup commit.\n'
    awk 'BEGIN { for (i = 0; i < 250; i++) print "filler" }'
  } > "$planted"
  assert_contains "a dropped code pin is named" "Batch bulk writes" "$(missing_pins "$CODE_PINS" "$planted")"
  assert_contains "a dropped core pin is named" "booted against a production-like copy" "$(missing_pins "$PINS" "$planted")"
  assert_contains "a stray import is named" "@docs/notes.md" "$(stray_imports "$planted")"
  assert_contains "retired wording is named" "own cleanup commit" "$(retired_present "$planted")"
  assert_eq "an over-long copy breaks the line cap" no "$(at_most "$(wc -l < "$planted")" "$CODE_LINE_CAP")"
  bare="$WORK/bare.md"
  { printf -- '---\nsummary: no paths here\n---\n'; sed '1,/^---$/d' "$CODE"; } > "$bare"
  assert_eq "a copy with no paths: lists no globs" "" "$(path_globs "$bare")"
  assert_missing "and carries no managed-by marker" "managed-by: engineering-rules" "$(front_matter "$bare")"
}

test_every_rule_is_pinned
test_size_caps
test_no_retired_wording
test_no_stray_imports
test_code_rules_front_matter
test_the_checks_can_fail
report
