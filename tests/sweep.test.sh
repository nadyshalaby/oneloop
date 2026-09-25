#!/bin/bash
# Runs scripts/sweep.sh against throwaway git repos. The main one has a base dated 2021, branches
# made before it, between it and the task's branch and during the task (one pushed to a bare
# remote), and a working tree holding a hit for every class beside lines each class must leave
# alone: an owned debt marker, a `return null` in a file the base has, an ignored empty folder, a
# Next.js-style `[id]` path beside the `i` folder its brackets would match as a glob, a path with
# a space, a move that empties its folder, and an edit to the work-doc itself. It checks: every
# class names its hits with file and line and leaves the rest alone, a clean change the Plan names
# finds nothing and exits 0, the work-doc is found when not passed and a relative one is read from
# where the run started, class 8 without one is reported as not checked, a check that misses its
# planted hit stops the run, and the usage errors exit 2 with a one-line message.
# Run: bash tests/sweep.test.sh
# SWEEP_SH points the test at another copy of scripts/sweep.sh, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SWEEP="${SWEEP_SH:-$ROOT/scripts/sweep.sh}"
DOC=docs/work/2026-09-25-task.md
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

# run_sweep <dir> <base> [<work-doc>]: sweep.sh run from <dir>, its stderr folded in and its exit
# code appended as the last line.
run_sweep() {
  ( cd "$1" && "$BASH" "$SWEEP" "$2" ${3:+"$3"} 2>&1
    printf 'exit=%s\n' "$?" )
}

# section <n> <output>: that class's block of the output, its heading line and its hits.
section() {
  printf '%s\n' "$2" | awk -v n="$1" 'index($0, "sweep class " n " ") == 1 { on = 1; print; next } /^sweep/ { on = 0 } on'
}

# build_fixture: the main repo, as the header describes it; the markers are printed in pieces so
# the edit guard (9.5) never reads this file as carrying them.
build_fixture() (
  git init -q "$WORK/repo" && cd "$WORK/repo" || return 1
  mkdir -p old 'app/[id]' app/i docs/work
  printf 'build/\n' > .gitignore
  printf 'const a = 1\n' > a.ts
  printf 'export const x = 1\n' > old/x.ts
  printf 'export const p = 1\n' > 'app/[id]/page.tsx'
  printf 'export const i = 1\n' > app/i/page.tsx
  printf 'const m = 1\n' > 'my file.ts'
  printf -- '---\nbranch: task\n---\n## Plan\n- [ ] 1. change (files: a.ts, app/, lib/*.ts, t.test.ts) -> verify: true\n## Log\n' > "$DOC"
  git add -- .gitignore a.ts old/x.ts 'app/[id]/page.tsx' app/i/page.tsx 'my file.ts' "$DOC" || return 1
  GIT_COMMITTER_DATE=2021-01-01T00:00:00Z git commit -q -m base || return 1
  git tag base
  GIT_COMMITTER_DATE=2020-06-01T00:00:00Z git branch old-branch
  GIT_COMMITTER_DATE=2021-06-01T00:00:00Z git branch between-branch
  GIT_COMMITTER_DATE=2022-01-01T00:00:00Z git checkout -q -b task
  git branch made-branch
  git init -q --bare "$WORK/remote.git" || return 1
  git remote add origin "$WORK/remote.git" && git push -q origin made-branch task || return 1
  printf 'con%s.log(a)\n// %s: old\n// %s fix\n// %s(t) owned\nconst s = "Lorem ipsum"\nreturn %s\n' \
    sole removed TODO TODO null >> a.ts
  printf 'con%s.log(p)\n' sole >> 'app/[id]/page.tsx'
  printf 'export const i2 = 2\ncon%s.log(i)\n' sole >> app/i/page.tsx
  printf 'con%s.log(m)\n' sole >> 'my file.ts'
  mkdir -p lib/empty-now lib/build/out moved
  printf 'export function n() { return %s }\n' null > lib/new.ts
  printf 'it.%s("runs", () => {})\n' only > t.test.ts
  : > scratch.tmp
  mv old/x.ts moved/x.ts && git add -- moved/x.ts && git rm -q --cached old/x.ts || return 1
  printf -- '- 1. change: done, %s none\n' TODO >> "$DOC"
)

# build_clean_fixture: a clean change committed on the task's branch, the one file the Plan names
# (in backticks, after ./), and an uncommitted edit to the work-doc.
build_clean_fixture() (
  git init -q "$WORK/clean" && cd "$WORK/clean" || return 1
  mkdir -p src docs/work
  printf 'const a = 1\n' > src/a.ts
  printf -- '---\nbranch: task\n---\n## Plan\n- [ ] 1. change (files: \140./src/a.ts\140) -> verify: true\n## Log\n' \
    > docs/work/2026-09-25-clean.md
  git add -- src/a.ts docs/work/2026-09-25-clean.md && git commit -q -m base || return 1
  git tag base
  git checkout -q -b task
  printf 'const b = 2\n' >> src/a.ts
  git add -- src/a.ts && git commit -q -m change || return 1
  printf -- '- 1. change: done\n' >> docs/work/2026-09-25-clean.md
)

# build_nodoc_fixture: a clean committed change in a repo with no work-doc.
build_nodoc_fixture() (
  git init -q "$WORK/nodoc" && cd "$WORK/nodoc" || return 1
  printf 'const a = 1\n' > a.ts
  git add -- a.ts && git commit -q -m base || return 1
  git tag base
  printf 'const b = 2\n' >> a.ts
  git add -- a.ts && git commit -q -m change
)

test_the_self_check_leads_the_output() {
  out=$(run_sweep "$WORK/clean" base)
  assert_eq "the first line is the self-check" 'sweep self-check: 8 classes found their planted hits' "$(printf '%s\n' "$out" | head -n 1)"
}

test_every_class_names_its_hits() {
  out=$(run_sweep "$WORK/repo" base "$DOC")
  c1=$(section 1 "$out")
  assert_contains "debug output is named with its file and line" "a.ts:2:" "$c1"
  assert_contains "a bracketed path is read as itself" "app/[id]/page.tsx:2:" "$c1"
  assert_missing "and never takes the lines of the folder its brackets match" "app/[id]/page.tsx:3:" "$c1"
  assert_contains "that folder keeps its own" "app/i/page.tsx:3:" "$c1"
  assert_contains "a path with a space is read whole" "my file.ts:2:" "$c1"
  assert_contains "a removed: marker" "a.ts:3:" "$(section 2 "$out")"
  c3=$(section 3 "$out")
  assert_contains "an ownerless debt marker" "a.ts:4:" "$c3"
  assert_missing "an owned one is left alone" "a.ts:5:" "$c3"
  c6=$(section 6 "$out")
  assert_contains "a scratch file" "uncommitted ?? scratch.tmp" "$c6"
  assert_contains "an empty folder" "empty-folder lib/empty-now" "$c6"
  assert_contains "a folder a move emptied" "empty-folder old" "$c6"
  assert_missing "an ignored empty folder is left alone" "lib/build" "$c6"
  c7=$(section 7 "$out")
  assert_contains "a placeholder, whatever its case" "a.ts:6:" "$c7"
  assert_contains "a return null in a new file" "lib/new.ts:1:" "$c7"
  assert_missing "one in a file the base has is left alone" "a.ts:7:" "$c7"
  c8=$(section 8 "$out")
  assert_contains "a path the Plan does not name" "my file.ts" "$c8"
  assert_contains "a move's old path" "old/x.ts" "$c8"
  assert_contains "and its new one" "moved/x.ts" "$c8"
  assert_missing "a folder entry covers what is under it" "app/i/page.tsx" "$c8"
  assert_missing "a glob entry covers what it matches" "lib/new.ts" "$c8"
  c12=$(section 12 "$out")
  assert_contains "a branch made during the task" "local made-branch" "$c12"
  assert_contains "and its first push" "pushed origin/made-branch" "$c12"
  assert_missing "a branch older than the base is left alone" "old-branch" "$c12"
  assert_missing "one made before the task's branch is left alone" "between-branch" "$c12"
  assert_missing "the task's own branch is left alone" "local task" "$c12"
  assert_missing "and so is its push" "origin/task" "$c12"
  assert_contains "a focused test" "t.test.ts:1:" "$(section 13 "$out")"
  assert_missing "the work-doc itself is never a hit" "2026-09-25-task.md" "$out"
  assert_contains "the closing line hands the rest to the session" "hits to judge; by hand: classes 4 5 9 10 11 (13.2)" "$out"
  assert_contains "exit 1 with hits to judge" "exit=1" "$out"
}

test_a_clean_change_in_the_plan_finds_nothing() {
  out=$(run_sweep "$WORK/clean" base)
  assert_contains "the work-doc is found when not passed, and nothing is flagged" \
    "sweep: 0 hits to judge; by hand: classes 4 5 9 10 11 (13.2)" "$out"
  assert_contains "exit 0 when nothing is flagged" "exit=0" "$out"
  out=$(run_sweep "$WORK/clean/src" base ../docs/work/2026-09-25-clean.md)
  assert_contains "a relative work-doc is read from where the run started" "sweep: 0 hits to judge;" "$out"
  assert_contains "and the run exits 0" "exit=0" "$out"
}

test_without_a_work_doc_class_8_is_not_checked() {
  out=$(run_sweep "$WORK/nodoc" base)
  assert_contains "class 8 says it was not checked" "sweep class 8 changes outside the plan's files: not checked" "$out"
  assert_contains "and the closing line says so" "sweep: 0 hits to judge, class 8 not checked;" "$out"
  assert_contains "exit 1, since nothing proved the scope" "exit=1" "$out"
}

# broken <name> <sed program>: a copy of sweep.sh with one check broken, as $WORK/<name>.sh.
broken() { sed "$2" "$SWEEP" > "$WORK/$1.sh"; }

# A check that lost its pattern would report a clean change; the run stops instead.
test_a_check_that_misses_its_plant_stops_the_run() {
  broken nodebug 's/console\\\.|//'
  broken noempty 's/-type d -empty/-type d -name none/'
  broken nonew "s/^NEW_PATH_TEXT=.*/NEW_PATH_TEXT='never here'/"
  broken nobranch 's/branch: Created from/branch: Never from/g'
  for pair in nodebug=1 noempty=6 nonew=7 nobranch=12; do
    name=${pair%%=*} class=${pair#*=}
    out=$(cd "$WORK/clean" && "$BASH" "$WORK/$name.sh" base 2>&1; printf 'exit=%s\n' "$?")
    assert_contains "a check that misses its plant is named ($name)" "self-check: class $class missed its planted hit" "$out"
    assert_contains "and exits 2 ($name)" "exit=2" "$out"
  done
}

test_usage_errors_exit_2() {
  out=$(cd "$WORK/clean" && "$BASH" "$SWEEP" 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "no base names the usage" "usage: sweep.sh <base-commit> [<work-doc>]" "$out"
  assert_contains "and exits 2" "exit=2" "$out"
  out=$(cd "$WORK/clean" && "$BASH" "$SWEEP" base one two 2>&1; printf 'exit=%s\n' "$?")
  assert_contains "three arguments name the usage" "usage: sweep.sh" "$out"
  assert_contains "and exit 2" "exit=2" "$out"
  out=$(run_sweep "$WORK/clean" not-a-real-commit-xyz)
  assert_contains "a base that is not a commit" "is not a commit" "$out"
  assert_contains "and exits 2" "exit=2" "$out"
  out=$(run_sweep "$WORK/clean" base no-such-doc.md)
  assert_contains "a work-doc that cannot be read" "cannot read the work-doc" "$out"
  assert_contains "and exits 2" "exit=2" "$out"
  mkdir -p "$WORK/notgit"
  out=$(run_sweep "$WORK/notgit" HEAD)
  assert_contains "outside a git repository" "not inside a git repository" "$out"
  assert_contains "and exits 2" "exit=2" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
build_clean_fixture || { printf 'FAIL could not build the clean fixture repo\n'; exit 1; }
build_nodoc_fixture || { printf 'FAIL could not build the no-doc fixture repo\n'; exit 1; }
test_the_self_check_leads_the_output
test_every_class_names_its_hits
test_a_clean_change_in_the_plan_finds_nothing
test_without_a_work_doc_class_8_is_not_checked
test_a_check_that_misses_its_plant_stops_the_run
test_usage_errors_exit_2
report
