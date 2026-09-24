#!/bin/bash
# Guard: the lane picker (scripts/lane.sh) gives the fast lane only when every fact a machine can
# check holds, names the first fact that failed otherwise, reads its kinds from the files that
# define them (hooks/path-kind.sh and 15.29's UI and STYLE lists) and stops with exit 2 on a
# usage error or a kind source it cannot read.
# Run: bash tests/lane.test.sh
# LANE_SH points the test at another copy of the script, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
LANE="${LANE_SH:-$ROOT/scripts/lane.sh}"
T='bun test'

# lane <arg>...: the picker's output, stderr folded in, against $ER_COPY when it is set.
lane() { ENGINEERING_RULES_HOME="${ER_COPY:-$ROOT}" "$BASH" "$LANE" "$@" 2>&1; }

# exit_of <arg>...: the picker's exit code alone.
exit_of() {
  ENGINEERING_RULES_HOME="${ER_COPY:-$ROOT}" "$BASH" "$LANE" "$@" > /dev/null 2>&1
  printf '%s' "$?"
}

# er_copy <name>: a home holding only the two kind sources, as $WORK/<name>.
er_copy() {
  mkdir -p "$WORK/$1/hooks" "$WORK/$1/references/15-design"
  cp "$ROOT/hooks/path-kind.sh" "$WORK/$1/hooks/"
  cp "$ROOT/references/15-design/15.29-the-design-scout.md" "$WORK/$1/references/15-design/"
}

test_the_fast_lane() {
  assert_eq "one code file with its test" 'lane: fast' "$(lane --test "$T" src/even.ts tests/even.test.ts)"
  assert_eq "three code files, the cap" 'lane: fast' "$(lane --test "$T" src/a.ts src/b.ts src/c.ts src/a.test.ts)"
  assert_eq "docs and generated files do not count" 'lane: fast' "$(lane --test "$T" README.md docs/guide.md dist/app.js src/a.ts src/b.ts src/c.ts test/a_test.go)"
  assert_eq "a test on its own needs no other" 'lane: fast' "$(lane --test pytest tests/test_even.py)"
  assert_eq "display is not pay" 'lane: fast' "$(lane --test "$T" src/display.ts src/display.test.ts)"
}

test_each_failed_fact_is_named() {
  assert_eq "no test command" 'lane: careful: the project has no test command' "$(lane --test '' src/even.ts tests/even.test.ts)"
  assert_eq "a blank test command" 'lane: careful: the project has no test command' "$(lane --test '  ' src/even.ts tests/even.test.ts)"
  assert_eq "four code files" 'lane: careful: 4 code files change, more than 3' "$(lane --test "$T" src/a.ts src/b.ts src/c.ts src/d.ts src/a.test.ts)"
  assert_eq "code with no test" 'lane: careful: code changes with no test file planned' "$(lane --test "$T" src/even.ts)"
}

test_each_risky_kind_is_named() {
  assert_eq "login" 'lane: careful: src/auth/password.ts is login or security' "$(lane --test "$T" src/auth/password.ts tests/password.test.ts)"
  assert_eq "money, camelCase split" 'lane: careful: src/PaymentService.ts is money' "$(lane --test "$T" src/PaymentService.ts tests/pay.test.ts)"
  assert_eq "database" 'lane: careful: db/migrations/001_init.sql is database' "$(lane --test "$T" db/migrations/001_init.sql)"
  assert_eq "dependencies" 'lane: careful: package.json is build or deploy settings' "$(lane --test "$T" package.json)"
  assert_eq "CI" 'lane: careful: .github/workflows/ci.yml is build or deploy settings' "$(lane --test "$T" .github/workflows/ci.yml)"
  assert_eq "env" 'lane: careful: .env.local is build or deploy settings' "$(lane --test "$T" .env.local)"
  assert_eq "a screen" 'lane: careful: src/Button.tsx is a screen or style file' "$(lane --test "$T" src/Button.tsx tests/Button.test.ts)"
  assert_eq "a style" 'lane: careful: styles/app.css is a screen or style file' "$(lane --test "$T" styles/app.css)"
}

# The UI and STYLE lists are 15.29's own: an extension planted there becomes a screen file, and
# a home without the lists, or without path-kind.sh, stops the run.
test_the_kinds_come_from_their_sources() {
  assert_eq "an unknown extension is not a screen" 'lane: fast' "$(lane --test "$T" src/x.zzz tests/x.test.ts)"
  er_copy planted
  doc="$WORK/planted/references/15-design/15.29-the-design-scout.md"
  sed "s/^UI='/UI='*.zzz /" "$doc" > "$doc.new" && mv "$doc.new" "$doc"
  assert_eq "planted in 15.29's UI list, it is" 'lane: careful: src/x.zzz is a screen or style file' "$(ER_COPY="$WORK/planted" lane --test "$T" src/x.zzz tests/x.test.ts)"
  er_copy nolist
  doc="$WORK/nolist/references/15-design/15.29-the-design-scout.md"
  grep -vE "^(UI|STYLE)='" "$doc" > "$doc.new" && mv "$doc.new" "$doc"
  assert_contains "no UI or STYLE list stops the run" 'no UI or STYLE list' "$(ER_COPY="$WORK/nolist" lane --test "$T" src/a.ts)"
  assert_eq "with exit 2" 2 "$(ER_COPY="$WORK/nolist" exit_of --test "$T" src/a.ts)"
  er_copy nokind && rm "$WORK/nokind/hooks/path-kind.sh"
  assert_eq "no path-kind.sh stops the run" 2 "$(ER_COPY="$WORK/nokind" exit_of --test "$T" src/a.ts)"
}

test_usage_errors_exit_2() {
  assert_eq "no --test" 2 "$(exit_of src/a.ts)"
  assert_eq "--test with no value" 2 "$(exit_of --test)"
  assert_eq "no planned file" 2 "$(exit_of --test "$T")"
  assert_eq "an unknown option" 2 "$(exit_of --fast --test "$T" src/a.ts)"
  assert_contains "named on stderr" 'lane: no planned file' "$(lane --test "$T")"
}

test_the_fast_lane
test_each_failed_fact_is_named
test_each_risky_kind_is_named
test_the_kinds_come_from_their_sources
test_usage_errors_exit_2
report
