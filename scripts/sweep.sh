#!/bin/bash
# engineering-rules cleanup sweep.
# Runs the eight mechanical classes of the cleanup sweep (13.2, Step D) over the change and prints
# every hit for the session to judge: 1 debug output, 2 `removed:` markers, 3 ownerless debt
# markers, 6 scratch files and empty folders, 7 placeholders and stubs, 8 changes outside the
# Plan's files, 12 branches made during the task, 13 focused or skipped tests. Their patterns are
# the ones 13.2's table held, and this file is now their one source. The five classes that need
# judgment (4 dead code, 5 unused imports and dependencies, 9 stale references, 10 what was
# already there, 11 leaked runtime state) stay with the session, from 13.2.
#
# Before it reads the change, every check runs over a planted repository holding one hit for it;
# a check that misses its plant stops the run, so a broken check never passes for a clean change.
#
# The change is the working tree against the base, committed or not, a rename read as a deletion
# and an addition. The work-doc itself is left out of every class, and class 8 leaves docs/work/
# out whole. Class 8 compares the paths with the ones the work-doc's Plan names in its
# "(files: ...)" lists: a named folder covers what is under it, `*` matches within one folder and
# `**` across folders. Class 12 reads each branch's oldest reflog entry and names the local
# branches this repository created, and the remote ones it first pushed, since the task began
# (its branch's creation, or the base commit's time when that is later or the reflog does not
# say), the task's own branch left out.
#
# Usage: bash <er>/scripts/sweep.sh <base-commit> [<work-doc>]
#   Run with the working directory inside the target repository; scout.sh --sweep runs it after
#   its scouts. The work-doc defaults to the one in-flight docs/work/*.md; with none, several, or
#   a Plan naming no files, class 8 is reported as not checked.
#
# Output: `sweep self-check: 8 classes found their planted hits`, then for each class
#   `sweep class <n> <name>: <count>` with every hit indented under it, then one closing line:
#     sweep: <n> hits to judge[, class 8 not checked]; by hand: classes 4 5 9 10 11 (13.2)
#
# Exit: 0 nothing to judge, 1 a hit or class 8 not checked, 2 a usage error, a change git could
#   not list, or a check that missed its planted hit, with a one-line message on stderr.
set -u
umask 077

# usage_error <message>: the one-line stderr contract.
usage_error() {
  printf 'sweep: %s\n' "$1" >&2
  exit 2
}

# The unit separator between the columns of the added-lines file, as in scout.sh.
SEP=$(printf '\037')
CLASSES='1 2 3 6 7 8 12 13'
# The patterns, matched by Perl on each added line's text. One token is split in two so the edit
# guard (9.5) never reads this file as using it.
DEBUG_RE='console\.|print\(|println|dbg!|debugger|breakpoint\(|pdb\.set_trace|binding\.pry|'"bye""bug"'|var_dump|dd\('
REMOVED_RE='(?i)removed:'
DEBT_RE='TODO|FIXME|HACK|XXX'
OWNED_DEBT_RE='(TODO|FIXME|HACK|XXX):?[[:space:]]*(\([^)]*\)|@[a-z][[:alnum:]_.-]*|\[[^]]*\]|#[0-9]+|[A-Z][A-Z0-9]+-[0-9]+)'
PLACEHOLDER_RE='TODO|(?i:placeholder|stub|lorem|picsum\.photos|placehold\.co)'
NEW_PATH_TEXT='return null'
FOCUS_RE='\.only|\.skip|\.todo|xit\(|xdescribe\(|fit\(|fdescribe\('
PLAN_EXCLUDE=':(exclude)docs/work/*'
# The planted hit each check must report, as <class> <text of the hit>; only its own check can
# produce each one.
PLANTED='1 a.ts:2:
2 a.ts:3:
3 a.ts:4:
6 uncommitted ?? scratch.tmp
6 empty-folder lib/empty
7 a.ts:5:
7 lib/c.ts:1:
8 lib/b.ts
12 local made-in-task
13 t.test.ts:1:'

# physical <path>: the path with its folder's symlinks resolved, so it compares with git's root.
physical() {
  printf '%s/%s\n' "$(cd -P -- "$(dirname -- "$1")" && pwd)" "$(basename -- "$1")"
}

# scan_exclude: the pathspec every class but 8 leaves out: the work-doc when it sits in this
# repository, else the root again, which leaves nothing out.
scan_exclude() {
  root=$(git rev-parse --show-toplevel)
  rel=${doc#"$root"/}
  if [ -n "$doc" ] && [ "$rel" != "$doc" ]; then printf ':(exclude,literal)%s\n' "$rel"; else printf '.\n'; fi
}

# hunk_lines <path>: file, line number and text of each line the working tree added to a tracked
# file since the base, unit-separated; only lines after the first hunk header count.
hunk_lines() {
  git diff -U0 --no-color --no-ext-diff --no-textconv --no-renames "$base" -- ":(literal)$1" \
    | F="$1" awk -v sep="$SEP" '
      /^@@ / { split($3, a, ","); n = substr(a[1], 2) + 0; hunk = 1; next }
      hunk && /^\+/ { print ENVIRON["F"] sep n sep substr($0, 2); n++ }'
}

# file_lines <path>: file, line number and text of every line of an untracked text file.
file_lines() {
  LC_ALL=C grep -I -n '' -- "$1" 2>/dev/null \
    | F="$1" awk -v sep="$SEP" '{ i = index($0, ":"); print ENVIRON["F"] sep substr($0, 1, i - 1) sep substr($0, i + 1) }'
}

# each_path <function>: that function over every NUL-separated path on stdin.
each_path() {
  while IFS= read -r -d '' p; do "$1" "$p"; done
}

# plan_entries: every path, glob or folder the work-doc's Plan names in its "(files: ...)" lists,
# one per line, backticks, commas and a leading ./ stripped.
plan_entries() {
  awk '/^## Plan/ { on = 1; next } /^## / { on = 0 } on' "$doc" \
    | perl -ne 'while (/\(files:\s*([^)]*)\)/g) { print "$_\n" for grep { length } map { s{^\./}{}r } map { s/`//gr } split /[,\s]+/, $1 }'
}

# read_change: the change, into files named from $out: its kept, deleted, untracked and new paths
# (NUL-separated), every line it added, and the Plan's entries; fails when git cannot list it.
read_change() {
  skip=$(scan_exclude)
  git diff -z --name-only --no-renames --diff-filter=d "$base" -- . "$skip" > "${out}kept" || return 1
  git diff -z --name-only --no-renames --diff-filter=D "$base" -- . "$skip" > "${out}deleted" || return 1
  git ls-files -z --others --exclude-standard -- . "$skip" > "${out}untracked" || return 1
  git diff -z --name-only --no-renames --diff-filter=A "$base" -- . "$skip" > "${out}new" || return 1
  cat -- "${out}untracked" >> "${out}new"
  { each_path hunk_lines < "${out}kept"; each_path file_lines < "${out}untracked"; } > "${out}added"
  : > "${out}plan"
  if [ -n "$doc" ]; then plan_entries > "${out}plan"; fi
}

# match_added <pattern> [<exclude pattern>]: every added line whose text matches the pattern and
# not the exclude pattern, as file:line:text.
match_added() {
  RE="$1" EX="${2:-}" perl -ne '
    chomp;
    my ($f, $n, $t) = split /\x1f/, $_, 3;
    next unless defined $t && $t =~ $ENV{RE};
    next if length $ENV{EX} && $t =~ $ENV{EX};
    print "$f:$n:$t\n";' "${out}added"
}

# match_new_paths: every added line holding the new-path text in a path the base does not have,
# as file:line:text.
match_new_paths() {
  TEXT="$NEW_PATH_TEXT" NEW="${out}new" perl -ne '
    BEGIN { local $/ = "\0"; open my $h, "<", $ENV{NEW} or die "sweep: no new-path list\n"; chomp(my @n = <$h>); %new = map { $_ => 1 } @n }
    chomp;
    my ($f, $n, $t) = split /\x1f/, $_, 3;
    print "$f:$n:$t\n" if defined $t && $new{$f} && index($t, $ENV{TEXT}) >= 0;' "${out}added"
}

# change_dirs: every folder holding a changed path, deleted ones included, the root left out.
change_dirs() {
  cat -- "${out}kept" "${out}deleted" "${out}untracked" | while IFS= read -r -d '' p; do
    case "$p" in */*) printf '%s\n' "${p%/*}" ;; esac
  done | LC_ALL=C sort -u
}

# empty_dirs: every empty folder under a changed folder, git-ignored ones left out.
empty_dirs() {
  change_dirs | while IFS= read -r d; do
    if [ -d "$d" ]; then find "$d" -type d -empty -not -path '*/.git/*'; fi
  done | LC_ALL=C sort -u > "${out}empty"
  git check-ignore --stdin < "${out}empty" | LC_ALL=C sort -u > "${out}ignored"
  LC_ALL=C comm -23 "${out}empty" "${out}ignored"
}

# scratch: every path git still reports, since by the sweep every task is committed (a scratch
# file, an unstaged edit, a staged fixture), then every empty folder under a changed folder.
scratch() {
  git -c core.quotePath=false status --porcelain --untracked-files=all -- . "$(scan_exclude)" | sed 's/^/uncommitted /'
  empty_dirs | sed 's/^/empty-folder /'
}

# outside_plan: every changed path, docs/work/ left out, that no Plan entry covers.
outside_plan() {
  { git diff -z --name-only --no-renames "$base" -- . "$PLAN_EXCLUDE"
    git ls-files -z --others --exclude-standard -- . "$PLAN_EXCLUDE"; } \
    | PLAN="${out}plan" perl -0 -ne '
      BEGIN {
        local $/ = "\n";
        open my $h, "<", $ENV{PLAN} or die "sweep: no plan list\n";
        while (my $e = <$h>) {
          chomp $e;
          $e =~ s{/+$}{};
          (my $re = quotemeta $e) =~ s/\\\*\\\*/.*/g;
          $re =~ s/\\\*/[^\/]*/g;
          $re =~ s/\\\?/[^\/]/g;
          push @plan, qr/^$re(?:\/.*)?$/s;
        }
      }
      chomp;
      my $p = $_;
      print "$p\n" unless grep { $p =~ $_ } @plan;'
}

# doc_branch: the `branch:` value of the work-doc's front matter, nothing without a work-doc.
doc_branch() {
  if [ -z "$doc" ]; then return 0; fi
  awk 'NR == 1 && /^---$/ { fm = 1; next } fm && /^---$/ { exit } fm && /^branch:/ { sub(/^branch:[[:space:]]*/, ""); print; exit }' "$doc"
}

# made_branches: from each ref's oldest reflog entry, the local branches this repository created
# and the remote ones it first pushed since the task began, the task's own branch left out.
made_branches() {
  current=$(git branch --show-current)
  task=$(doc_branch)
  git reflog show --all --date=unix --format="%gD$SEP%gs" 2>/dev/null \
    | BASE_TIME=$(git show -s --format=%ct "$base") TASK=${task:-$current} CURRENT=$current perl -ne '
      chomp;
      my ($sel, $msg) = split /\x1f/, $_, 2;
      my ($ref, $t) = $sel =~ /^(.*)\@\{(\d+)\}$/ or next;
      $first{$ref} = [$t, $msg] if !$first{$ref} || $t <= $first{$ref}[0];
      END {
        my $since = $ENV{BASE_TIME};
        my $own = $first{"refs/heads/$ENV{TASK}"};
        $since = $own->[0] if $own && $own->[1] =~ /^branch: Created from/ && $own->[0] > $since;
        for my $ref (sort keys %first) {
          my ($t, $msg) = @{ $first{$ref} };
          my ($row, $name);
          ($row, $name) = ("local $1", $1) if $msg =~ /^branch: Created from/ && $ref =~ m{^refs/heads/(.+)$};
          ($row, $name) = ("pushed $1/$2", $2) if $msg =~ /^update by push/ && $ref =~ m{^refs/remotes/([^/]+)/(.+)$};
          print "$row\n" if $row && $t >= $since && $name ne $ENV{TASK} && $name ne $ENV{CURRENT};
        }
      }'
}

# run_class <n>: the hits of one class, one per line; nothing for a class with none.
run_class() {
  case "$1" in
    1) match_added "$DEBUG_RE" ;;
    2) match_added "$REMOVED_RE" ;;
    3) match_added "$DEBT_RE" "$OWNED_DEBT_RE" ;;
    6) scratch ;;
    7) { match_added "$PLACEHOLDER_RE"; match_new_paths; } | awk '!seen[$0]++' ;;
    8) outside_plan ;;
    12) made_branches ;;
    13) match_added "$FOCUS_RE" ;;
  esac
}

# run_all: the change read, then every class over it, each one's hits in ${out}class-<n>.
run_all() {
  read_change || return 1
  for class in $CLASSES; do run_class "$class" > "${out}class-$class"; done
}

# plant <dir>: a repository at <dir> whose change holds the planted hit of every check, with a
# work-doc at docs/work/plan.md whose Plan names two of its files; each marker is printed in
# pieces so this file never carries it whole.
plant() (
  git init -q "$1" || exit 1
  cd "$1" || exit 1
  mkdir -p lib docs/work
  printf 'export const a = 1\n' > a.ts
  printf 'export const b = 2\n' > lib/b.ts
  printf -- '---\nbranch: task\n---\n## Plan\n- [ ] 1. t (files: a.ts, lib/c.ts) -> verify: true\n## Log\n' > docs/work/plan.md
  git add -- a.ts lib/b.ts docs/work/plan.md || exit 1
  git -c user.name=sweep -c user.email=sweep@local -c commit.gpgsign=false -c core.hooksPath=/dev/null \
    commit -q -m base || exit 1
  printf 'con%s.log(a)\n// %s: old code\n// %s fix this\nconst s = "lorem ipsum"\n' sole removed TODO >> a.ts
  printf 'export const c = 3\n' >> lib/b.ts
  printf 'export function c() { return %s }\n' null > lib/c.ts
  printf 'it.%s("runs", () => {})\n' only > t.test.ts
  printf -- '- 1. t: done\n' >> docs/work/plan.md
  : > scratch.tmp
  mkdir -p lib/empty
  git branch made-in-task
)

# plant_run: run_all over the planted repository, from inside it; run in a subshell, so the
# real run's base, work-doc and file names stay as they were.
plant_run() {
  base=$(git rev-parse HEAD) doc=$(physical docs/work/plan.md) out="$WORK/plant-"
  run_all
}

# self_check: every class over the planted repository, each check required to report its hit.
self_check() {
  plant "$WORK/plant" || usage_error 'self-check: could not build its planted repository'
  (cd "$WORK/plant" && plant_run) || usage_error 'self-check: could not read its planted change'
  printf '%s\n' "$PLANTED" | while read -r class text; do
    grep -qF -- "$text" "$WORK/plant-class-$class" || usage_error "self-check: class $class missed its planted hit"
  done || exit 2
  printf 'sweep self-check: 8 classes found their planted hits\n'
}

# report_class <n> <name>: the class's line with its count, then every hit indented under it.
report_class() {
  count=$(grep -c . "${out}class-$1")
  printf 'sweep class %s %s: %s\n' "$1" "$2" "$count"
  sed 's/^/  /' "${out}class-$1"
  total=$((total + count))
}

# default_doc: the one in-flight docs/work/*.md, resolved; nothing with none or several.
default_doc() {
  set -- docs/work/*.md
  if [ $# -eq 1 ] && [ -f "$1" ]; then physical "$1"; fi
}

case $# in
  1 | 2) ;;
  *) usage_error 'usage: sweep.sh <base-commit> [<work-doc>]' ;;
esac
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || usage_error 'not inside a git repository'
base=$(git rev-parse --verify -q "$1^{commit}" 2>/dev/null) || usage_error "'$1' is not a commit"
doc=${2:-}
if [ -n "$doc" ]; then
  if [ ! -f "$doc" ] || [ ! -r "$doc" ]; then usage_error "cannot read the work-doc '$doc'"; fi
  doc=$(physical "$doc")
fi
cd "$repo_root" || usage_error 'could not switch to the repository root'
if [ -z "$doc" ]; then doc=$(default_doc); fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sweep.XXXXXX") || usage_error 'could not create a work directory'
trap 'rm -rf "$WORK"' EXIT
self_check
out="$WORK/"
run_all || usage_error 'git could not list the change'
total=0
report_class 1 'debug output'
report_class 2 'removed: markers (read every added comment block too)'
report_class 3 'ownerless TODOs'
report_class 6 'scratch files and empty dirs'
report_class 7 'placeholders and stubs'
note=''
if [ -s "${out}plan" ]; then
  report_class 8 "changes outside the plan's files"
else
  printf "sweep class 8 changes outside the plan's files: not checked, no work-doc Plan names its files\n"
  note=', class 8 not checked'
fi
report_class 12 'branches you made'
report_class 13 'focused or skipped tests'
printf 'sweep: %s hits to judge%s; by hand: classes 4 5 9 10 11 (13.2)\n' "$total" "$note"
if [ "$total" -gt 0 ] || [ -n "$note" ]; then exit 1; fi
