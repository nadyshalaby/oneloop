#!/bin/bash
# Guard: the short law that CLAUDE.md loads into every session keeps every rule the long form
# pins, stays small, and carries no text the CLAUDE.md import parser would read as an import.
# Every session and every helper pays for this file, so it is compacted; a compaction that
# drops a banned token, a cap, a guardrail, a git rule, a banned phrase or a deploy proof
# fails here instead of silently loosening the law. The pins are data, one per line, in
# fixtures/short-law-pins.txt, because a code file listing banned tokens reads as using them.
# LAW_MD and PINS point the test at other copies, which is how it proves it can fail.
# Run: bash tests/short-law.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
LAW="${LAW_MD:-$ROOT/law/engineering-law.md}"
PINS="${PINS:-$ROOT/tests/fixtures/short-law-pins.txt}"
LINE_CAP=200
CHAR_CAP=20000

# pinned: the pins, comments and blank lines left out.
pinned() {
  grep -vE '^(#|$)' "$PINS"
}

# missing_pins <file>: every pinned string the file does not carry, one per line.
missing_pins() {
  pinned | while IFS= read -r pin; do
    grep -qF -- "$pin" "$1" || printf '%s\n' "$pin"
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

test_every_rule_is_pinned() {
  total=$(pinned | grep -c .)
  assert_eq "the pin list is not empty" yes "$([ "$total" -gt 100 ] && echo yes || echo no)"
  assert_eq "every one of the $total pinned rules is in the short law" "" "$(missing_pins "$LAW")"
}

test_size_caps() {
  lines=$(wc -l < "$LAW" | tr -d ' ')
  chars=$(wc -c < "$LAW" | tr -d ' ')
  assert_eq "the short law is at most $LINE_CAP lines ($lines)" yes "$(at_most "$lines" "$LINE_CAP")"
  assert_eq "the short law is at most $CHAR_CAP characters ($chars)" yes "$(at_most "$chars" "$CHAR_CAP")"
}

test_no_stray_imports() {
  assert_eq "no @ outside backticks, so nothing is read as an import" "" "$(stray_imports "$LAW")"
}

# The checks above can fail: a copy with one pin removed, one import-shaped line and too many
# lines is refused on all three counts.
test_the_checks_can_fail() {
  planted="$WORK/planted.md"
  grep -vF 'Batch bulk writes' "$LAW" > "$planted"
  printf 'see @docs/notes.md for more\n' >> "$planted"
  awk 'BEGIN { for (i = 0; i < 250; i++) print "filler" }' >> "$planted"
  assert_contains "a dropped pin is named" "Batch bulk writes" "$(missing_pins "$planted")"
  assert_contains "a stray import is named" "@docs/notes.md" "$(stray_imports "$planted")"
  assert_eq "an over-long copy breaks the line cap" no "$(at_most "$(wc -l < "$planted")" "$LINE_CAP")"
}

test_every_rule_is_pinned
test_size_caps
test_no_stray_imports
test_the_checks_can_fail
report
