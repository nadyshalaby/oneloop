#!/bin/bash
# Runs scripts/scout.sh against two throwaway git repos. The first is a linear history, one tag per
# base: a banned token already at the base, a second (textually distinct) one added to that same
# file, a third in a brand new file, a UI file, a plain-file change, then an exact copy of a line
# that was already there. The second has one commit and every change left uncommitted: an
# unstaged edit, a staged one, an untracked file, a file over the line cap at the base that grows,
# one that crosses it, a whole-file design row the change caused away from line 1 and one that was
# already true at the base, and a project ban list named by a relative path. It checks: new hits
# are introduced in full and old ones summarised once with a count, a copy of an old line is
# introduced, uncommitted work is scanned, a whole-file row is judged against the base file, the
# design scout runs only when the touched scope has a UI file, a clean change finds nothing, every
# scout proves itself on its planted hit first and one that misses stops the run, and the usage
# errors exit 2 with a one-line message.
# Run: bash tests/scout.test.sh
# SCOUT_SH points the test at another copy of scripts/scout.sh, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SCOUT="${SCOUT_SH:-$ROOT/scripts/scout.sh}"
# The token in two pieces: the edit guard (9.5) refuses an edit that adds a contiguous one, in a
# test file included, so every fixture and every assertion below reads it through this variable.
TOK=$(printf '@ts-%s' ignore)

# run_scout <base> <head>: checks the first repo out at <head> (scout.sh reads the working tree,
# so each scenario sets its own rather than trusting an earlier one's leftover position) and runs
# scout.sh from <base>; ENGINEERING_RULES_HOME stays the real docs so a broken SCOUT_SH is still
# judged against them, and the exit code is appended as the run's last line.
run_scout() {
  ( cd "$WORK/repo" && git checkout -q "$2" \
      && ENGINEERING_RULES_HOME="$ROOT" "$BASH" "$SCOUT" "$1" 2>&1
    printf 'exit=%s\n' "$?" )
}

commit() { git -c user.name=t -c user.email=t@example.com commit -q -m "$1"; }

# numbered <n>: n distinct lines of plain code, for the file-line cap.
numbered() { seq 1 "$1" | sed 's/^/const x/; s/$/ = 1/'; }

# build_fixture: the first repo, a linear history with one git tag per base the tests run from.
build_fixture() (
  git init -q "$WORK/repo" && cd "$WORK/repo" || return 1
  printf 'const ok = 1\n' > clean.ts
  printf '// %s\nconst a = 1\n' "$TOK" > a.ts
  git add -- clean.ts a.ts && commit planted && git tag base1
  printf '// %s\nconst a = 1\nconst b = 2\n// %s -- second\n' "$TOK" "$TOK" > a.ts
  printf '// %s -- brand new file\n' "$TOK" > new.ts
  git add -- a.ts new.ts && commit changed && git tag base2
  printf 'export const Hero = () => <div className="h-screen flex">hi</div>\n' > Hero.tsx
  git add -- Hero.tsx && commit ui && git tag base3
  printf 'const ok = 1\nconst ok2 = 2\n' > clean.ts
  git add -- clean.ts && commit clean-change && git tag base4
  printf '// %s\n' "$TOK" >> a.ts
  git add -- a.ts && commit copy && git tag base5
)

# build_uncommitted_fixture: the second repo, one commit and then every change left uncommitted.
build_uncommitted_fixture() (
  git init -q "$WORK/tree" && cd "$WORK/tree" || return 1
  printf '// %s\nconst w = 1\n' "$TOK" > w.ts
  printf '// %s\n' "$TOK" > dup.ts
  numbered 600 > big.ts
  numbered 450 > mid.ts
  printf 'export const G = () => (\n  <div className="flex">a</div>\n)\n' > Grid.tsx
  printf 'export const C = () => (\n  <div className="grid-cols-3">a</div>\n)\n' > Cols.tsx
  printf 'legacyCall()\nconst c = 1\n' > c.ts
  git add -- w.ts dup.ts big.ts mid.ts Grid.tsx Cols.tsx c.ts && commit base
  printf '// %s -- unstaged\n' "$TOK" >> w.ts
  printf '// %s\n' "$TOK" >> dup.ts && git add -- dup.ts
  printf '// %s -- untracked\n' "$TOK" > u.ts
  numbered 10 >> big.ts
  numbered 100 >> mid.ts
  printf 'export const G = () => (\n  <div className="flex">a</div>\n  <div className="grid-cols-3">b</div>\n)\n' > Grid.tsx
  printf 'export const C = () => (\n  <div className="grid-cols-3">b</div>\n)\n' > Cols.tsx
  printf 'const c2 = 2\n' >> c.ts
  printf 'legacyCall\\(\n' > "$WORK/bans.txt"
)

test_introduced_named_present_at_base_summarised() {
  out=$(run_scout base1 base2)
  assert_contains "the new line in the same file is introduced" "introduced ban.suppression a.ts:4:// $TOK -- second" "$out"
  assert_contains "the new file's hit is introduced" "introduced ban.suppression new.ts:1:// $TOK -- brand new file" "$out"
  assert_missing "the old occurrence is not its own introduced row" "introduced ban.suppression a.ts:1:" "$out"
  assert_contains "the old occurrence is summarised once with a count" "present-at-base ban.suppression a.ts (1 hit)" "$out"
  tally=$(printf '%s\n' "$out" | grep '^scout:')
  assert_eq "the closing tally line" 'scout: 2 introduced, 1 present at base in 1 files; ran: perf law' "$tally"
  assert_contains "exit 1 when a row is introduced" "exit=1" "$out"
}

test_ui_file_triggers_the_design_scout() {
  out=$(run_scout base2 base3)
  assert_contains "the design scout ran" 'ran: perf law design' "$out"
  assert_contains "and its own tell fired on the new file" "introduced tell.layout.h-screen Hero.tsx:1:" "$out"
  assert_contains "exit 1 when a row is introduced" "exit=1" "$out"
}

test_no_ui_file_skips_design_and_a_clean_change_finds_nothing() {
  out=$(run_scout base3 base4)
  assert_missing "the design scout did not run on the change" "ran: perf law design" "$out"
  tally=$(printf '%s\n' "$out" | grep '^scout:')
  assert_eq "a clean change introduces nothing" 'scout: 0 introduced, 0 present at base in 0 files; ran: perf law' "$tally"
  assert_contains "exit 0 when nothing is introduced" "exit=0" "$out"
}

# A line matched by its text alone would call the copy present at base; the diff says it is new.
test_a_copy_of_an_old_line_is_introduced() {
  out=$(run_scout base4 base5)
  assert_contains "the copy is introduced" "introduced ban.suppression a.ts:5:// $TOK" "$out"
  tally=$(printf '%s\n' "$out" | grep '^scout:')
  assert_eq "and the two old lines stay at base" 'scout: 1 introduced, 2 present at base in 1 files; ran: perf law' "$tally"
}

test_uncommitted_work_is_scanned_and_judged_against_the_base() {
  out=$(cd "$WORK/tree" && PROJECT_BAN_PATTERNS=../bans.txt ENGINEERING_RULES_HOME="$ROOT" "$BASH" "$SCOUT" HEAD 2>&1
    printf 'exit=%s\n' "$?")
  assert_contains "an unstaged edit is scanned" "introduced ban.suppression w.ts:3:// $TOK -- unstaged" "$out"
  assert_contains "a staged copy of an old line is introduced" "introduced ban.suppression dup.ts:2:// $TOK" "$out"
  assert_contains "and the old line stays at base" "present-at-base ban.suppression dup.ts (1 hit)" "$out"
  assert_contains "an untracked file is scanned" "introduced ban.suppression u.ts:1:// $TOK -- untracked" "$out"
  assert_contains "a file over the cap at the base that grows is at base" "present-at-base cap.file-lines big.ts (1 hit)" "$out"
  assert_contains "a file that crosses the cap is introduced" "introduced cap.file-lines mid.ts: 550 lines" "$out"
  assert_contains "a whole-file row caused away from line 1 is introduced" "introduced tell.layout.mobile-implicit Grid.tsx:1:" "$out"
  assert_contains "the same row already true at the base is at base" "present-at-base tell.layout.mobile-implicit Cols.tsx (1 hit)" "$out"
  assert_contains "a relative ban list is read in both passes" "present-at-base ban.custom c.ts (1 hit)" "$out"
  tally=$(printf '%s\n' "$out" | grep '^scout:')
  assert_eq "the closing tally line" 'scout: 5 introduced, 5 present at base in 5 files; ran: perf law design' "$tally"
}

test_usage_errors_exit_2() {
  out=$(ENGINEERING_RULES_HOME="$ROOT" "$BASH" "$SCOUT" 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "no base argument names the usage" "usage: scout.sh <base-commit>" "$out"
  assert_contains "and exits 2" "exit=2" "$out"

  out=$(cd "$WORK/repo" && ENGINEERING_RULES_HOME="$ROOT" "$BASH" "$SCOUT" not-a-real-commit-xyz 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "a base that is not a commit" "is not a commit" "$out"
  assert_contains "and exits 2" "exit=2" "$out"

  mkdir -p "$WORK/notgit"
  out=$(cd "$WORK/notgit" && ENGINEERING_RULES_HOME="$ROOT" "$BASH" "$SCOUT" HEAD 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "outside a git repository" "not inside a git repository" "$out"
  assert_contains "and exits 2" "exit=2" "$out"

  mkdir -p "$WORK/empty-home"
  out=$(cd "$WORK/repo" && ENGINEERING_RULES_HOME="$WORK/empty-home" "$BASH" "$SCOUT" base1 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "a doc that cannot be found is a block that could not be extracted" "no ### HOW block found" "$out"
  assert_contains "and exits 2" "exit=2" "$out"
}

# A block whose path line changed would build its own scope, so the run stops instead.
test_a_moved_path_line_stops_the_run() {
  home="$WORK/moved-home/references"
  mkdir -p "$home/09-phase-3-implement" "$home/15-design"
  sed 's/"<base>..HEAD"/"<base>...HEAD"/' "$ROOT/references/09-phase-3-implement/9.5-the-law-scout.md" > "$home/09-phase-3-implement/9.5-the-law-scout.md"
  cp "$ROOT/references/15-design/15.29-the-design-scout.md" "$home/15-design/"
  out=$(cd "$WORK/repo" && ENGINEERING_RULES_HOME="$WORK/moved-home" "$BASH" "$SCOUT" base1 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "the moved path line is named" "law scout: its path line is not there exactly once" "$out"
  assert_contains "and exits 2" "exit=2" "$out"
}

test_the_self_check_leads_the_output() {
  out=$(run_scout base3 base4)
  assert_eq "the first line is the self-check" 'self-check: perf ok, law ok, design ok' "$(printf '%s\n' "$out" | head -n 1)"
}

# broken_home <name> <doc> <sed program>: a home with the three scout docs, <doc> (a path under
# references/) edited by the sed program, as $WORK/<name>.
broken_home() {
  for d in 09-phase-3-implement/9.4-the-perf-scout.md 09-phase-3-implement/9.5-the-law-scout.md 15-design/15.29-the-design-scout.md; do
    mkdir -p "$WORK/$1/references/${d%/*}"
    cp "$ROOT/references/$d" "$WORK/$1/references/$d"
  done
  sed "$3" "$ROOT/references/$2" > "$WORK/$1/references/$2"
}

# A scout whose doc lost the row for its plant would report a clean change; the run stops instead.
test_a_scout_that_misses_its_plant_stops_the_run() {
  broken_home noperf 09-phase-3-implement/9.4-the-perf-scout.md '/perf\.memory\.json-deep-clone/d'
  broken_home nolaw 09-phase-3-implement/9.5-the-law-scout.md "s/$TOK|//"
  broken_home nodesign 15-design/15.29-the-design-scout.md '/tag tell\.layout\.h-screen$/d'
  for pair in noperf=perf.memory.json-deep-clone nolaw=ban.suppression nodesign=tell.layout.h-screen; do
    home=${pair%%=*} id=${pair#*=}
    out=$(cd "$WORK/repo" && ENGINEERING_RULES_HOME="$WORK/$home" "$BASH" "$SCOUT" base1 2>&1; printf 'exit=%s\n' "$?")
    assert_contains "a scout that misses its plant is named ($home)" "missed its planted $id" "$out"
    assert_contains "and exits 2 ($home)" "exit=2" "$out"
  done
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
build_uncommitted_fixture || { printf 'FAIL could not build the uncommitted fixture repo\n'; exit 1; }
test_introduced_named_present_at_base_summarised
test_ui_file_triggers_the_design_scout
test_no_ui_file_skips_design_and_a_clean_change_finds_nothing
test_a_copy_of_an_old_line_is_introduced
test_uncommitted_work_is_scanned_and_judged_against_the_base
test_usage_errors_exit_2
test_a_moved_path_line_stops_the_run
test_the_self_check_leads_the_output
test_a_scout_that_misses_its_plant_stops_the_run
report
