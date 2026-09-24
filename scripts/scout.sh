#!/bin/bash
# engineering-rules scout.
# Runs the repository's deterministic scouts (the law scout 9.5, and the design scout 15.29 when
# the change touches a UI or style file) over the files this change touched, and reports which of
# their hits this change introduced against which were already there at a base commit. The
# scouts' own ### HOW fences are the one source of their patterns: this script extracts, runs and
# classifies them, it never repeats a pattern from either doc, and the design gate is assembled
# from 15.29's own block.
#
# The change is the working tree against the base, committed or not: every file that differs from
# the base (a deleted one has nothing to read) and every untracked file git does not ignore,
# docs/work/ left out of both. Each block's own path line is swapped whole for that list, and a
# block whose path line is not there exactly once stops the run, so no scout reads a scope of its
# own.
#
# A row is introduced unless its line is unchanged since the base AND the same scouts, run a
# second time over the base copies of the same files, fire the same rule on the same file. So a
# new copy of a line that was already there is introduced, and a whole-file row (the file-line
# cap, a file with no mobile variant) is judged by whether the base file tripped it too. Three
# edges, all erring toward the finding: a row with no file (a scope count) is introduced, a
# renamed file reads as new, and a whole-file row pinned to line 1 reads introduced whenever line
# 1 was edited.
#
# Usage: bash <er>/scripts/scout.sh <base-commit>
#   Run with the working directory anywhere inside the target git repository. <er> is
#   $ENGINEERING_RULES_HOME, else this script's own parent directory. A relative
#   PROJECT_BAN_PATTERNS is read from the directory the script was started in.
#
# Output: every introduced row in full (rule id, file:line, text), then every present-at-base
#   rule summarised to one line per file with a count, then the coverage lines the scouts printed
#   over the change, then one closing line:
#     scout: <n> introduced, <m> present at base in <k> files; ran: law[ design]
#
# Exit: 0 no row is introduced, 1 at least one row is introduced, 2 a usage error (no base, the
#   base is not a commit, the working directory is not inside a git repository, or a scout's
#   block could not be extracted or its path line swapped), with a one-line message on stderr.
set -u
umask 077

# usage_error <message>: the one-line stderr contract.
usage_error() {
  printf 'scout: %s\n' "$1" >&2
  exit 2
}

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
ER_HOME="${ENGINEERING_RULES_HOME:-$(cd -P "$here/.." && pwd)}"
LAW_DOC="$ER_HOME/references/09-phase-3-implement/9.5-the-law-scout.md"
DESIGN_DOC="$ER_HOME/references/15-design/15.29-the-design-scout.md"
# The line both blocks build their own path list with, and the line it is swapped for.
PATH_LINE="git diff -z --name-only \"<base>..HEAD\" -- . ':(exclude)docs/work/*' > \"\$SCOUT_PATHS\""
LIST_LINE="cat -- \"\$SCOUT_LIST\" > \"\$SCOUT_PATHS\""

# A rule id line, the shape every scout's `tag` helper produces: dotted lower-case segments then
# a space. Anything else a block prints (a coverage count, a reconcile line, a stray error under
# the 2>&1 capture) is passthrough, never a row, so a block that broke cannot inflate the count.
HIT_PREFIX='^[a-z]+(\.[a-z0-9-]+)+ '
# The unit separator between the columns of the TSV files below: real source text can hold a
# tab, never this byte. Not \1: bash 3.2's `read` silently refuses to split on it.
SEP=$(printf '\037')

[ $# -eq 1 ] || usage_error 'usage: scout.sh <base-commit>'
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || usage_error 'not inside a git repository'
base=$(git rev-parse --verify -q "$1^{commit}" 2>/dev/null) || usage_error "'$1' is not a commit"
# The second pass runs inside a copy of the base tree, where a relative ban list would be gone.
case "${PROJECT_BAN_PATTERNS:-}" in
  '' | /*) ;;
  *) export PROJECT_BAN_PATTERNS="$PWD/$PROJECT_BAN_PATTERNS" ;;
esac
cd "$repo_root" || usage_error 'could not switch to the repository root'

WORK=$(mktemp -d "${TMPDIR:-/tmp}/scout.XXXXXX") || usage_error 'could not create a work directory'
trap 'rm -rf "$WORK"' EXIT

# extract_how_block <doc>: the fenced bash block under "### HOW", verbatim, on stdout; empty for
# an unreadable doc or one with no such heading and fence.
extract_how_block() {
  [ -r "$1" ] || return 0
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$1"
}

# materialize_block <doc> <label>: that block with its path line swapped for the list this script
# builds, in $WORK/<label>-block.sh. A block that is missing, or whose path line is not there
# exactly once, stops the run: a scout left to build its own list would read another scope.
materialize_block() {
  extract_how_block "$1" | PATH_LINE="$PATH_LINE" LIST_LINE="$LIST_LINE" awk '
    $0 == ENVIRON["PATH_LINE"] { print ENVIRON["LIST_LINE"]; n++; next }
    { print }
    END { exit (n == 1 ? 0 : 1) }' > "$WORK/$2-block.sh"
  swapped=$?
  [ -s "$WORK/$2-block.sh" ] || usage_error "$2 scout: no ### HOW block found in $1"
  [ "$swapped" -eq 0 ] || usage_error "$2 scout: its path line is not there exactly once in $1"
}

# build_touched <list>: the change's scope, NUL-separated, as the header describes it.
build_touched() {
  {
    git diff -z --name-only --diff-filter=d "$base" -- . ':(exclude)docs/work/*'
    git ls-files -z --others --exclude-standard -- . ':(exclude)docs/work/*'
  } > "$1"
}

# build_base_tree <dir> <list>: the base copy of every touched file the base has, written under
# <dir> at its own path, and those paths NUL-separated in <list>.
build_base_tree() {
  mkdir -p "$1" && : > "$2"
  while IFS= read -r -d '' p; do
    case "$p" in */*) mkdir -p "$1/${p%/*}" ;; esac
    if git cat-file blob "$base:$p" > "$1/$p" 2>/dev/null; then printf '%s\0' "$p" >> "$2"; else rm -f "$1/$p"; fi
  done < "$touched"
}

# design_touches_ui: true when the touched scope has a file matching 15.29's own UI or STYLE
# globs, assembled from that block's own `set -f`, `UI=`, `STYLE=` and `in_paths()` lines.
design_touches_ui() {
  gate="$WORK/design-gate.sh"
  grep -E '^(set -f|UI=|STYLE=)' "$WORK/design-block.sh" > "$gate"
  grep -E '^in_paths\(\)' "$WORK/design-block.sh" >> "$gate"
  cat <<'EOF' >> "$gate"
[ -n "$(in_paths $UI $STYLE | head -c 1)" ]
EOF
  SCOUT_PATHS="$touched" "$BASH" "$gate"
}

# run_scouts <dir> <list> <out>: every scout in $ran, run from <dir> over the paths in <list>,
# each one's combined output in <out>-<label>.
run_scouts() {
  for label in $ran; do
    (cd "$1" && SCOUT_LIST="$2" SCOUT_PATHS="$3-$label.paths" "$BASH" "$WORK/$label-block.sh") > "$3-$label" 2>&1
  done
}

# parse_row <row>: rule, file and line of a rule-led row, from the grep -n shape "file:line:text"
# or cap.file-lines' whole-file shape "file: N lines" (no line); any other row has no file.
parse_row() {
  rule=${1%% *} rest=${1#* } file='' line=''
  fre='^([^:]*):([0-9]+):'
  cre='^([^:]*):[[:space:]]*[0-9]+ lines$'
  if [[ $rest =~ $fre ]]; then
    file=${BASH_REMATCH[1]} line=${BASH_REMATCH[2]}
  elif [[ $rest =~ $cre ]]; then
    file=${BASH_REMATCH[1]}
  fi
}

# queue_rows <label> <out>: PASS A over the change's output. A rule-led row becomes a candidate
# (seq, rule, file, line, the row); anything else is kept as coverage, never counted.
queue_rows() {
  while IFS= read -r raw || [ -n "$raw" ]; do
    [ -n "$raw" ] || continue
    if [[ $raw =~ $HIT_PREFIX ]]; then
      parse_row "$raw"
      hit_seq=$((hit_seq + 1))
      printf '%s\037%s\037%s\037%s\037%s\n' "$hit_seq" "$rule" "$file" "$line" "$raw" >> "$WORK/candidates.tsv"
    else
      printf '%s coverage: %s\n' "$1" "$raw" >> "$WORK/coverage.log"
    fi
  done < "$2"
}

# queue_base_keys <out>: PASS A over the base copies' output, "rule SEP file" for every row with a
# file; that pass's coverage lines describe the base tree and are dropped.
queue_base_keys() {
  while IFS= read -r raw || [ -n "$raw" ]; do
    [[ $raw =~ $HIT_PREFIX ]] || continue
    parse_row "$raw"
    [ -z "$file" ] || printf '%s\037%s\n' "$rule" "$file"
  done < "$1" >> "$WORK/base-keys"
}

# added_lines <file>: the line numbers the working tree added or changed in <file> since the
# base, one per line, off the -U0 hunk headers (`+c` is one line, `+c,0` adds none).
added_lines() {
  git diff -U0 --no-color --no-ext-diff --no-textconv "$base" -- "$1" | awk '
    /^@@ / { n = split($3, a, ","); first = substr(a[1], 2) + 0; count = (n > 1) ? a[2] + 0 : 1
             for (i = 0; i < count; i++) print first + i }'
}

# verdict: v for the row resolve_candidates holds, first match wins: no file, or no copy at the
# base, is introduced; a line the diff added is introduced; the same rule on the same file in the
# base pass is present at base; anything else is introduced.
verdict() {
  v=introduced
  if [ -z "$file" ] || [ "$at_base" -eq 0 ]; then return 0; fi
  if [ -n "$line" ] && grep -qxF -- "$line" "$WORK/added"; then return 0; fi
  if grep -qxF -- "$rule$SEP$file" "$WORK/base-keys"; then v=present-at-base; fi
}

# resolve_candidates: PASS B. Reads the candidates sorted by file, so one diff serves every row
# in a file, and writes each row with its verdict; the seq column restores the scouts' order.
resolve_candidates() {
  sort -t "$SEP" -k3,3 -- "$WORK/candidates.tsv" > "$WORK/candidates.sorted"
  cur_file='' at_base=0
  : > "$WORK/resolved.tsv"
  while IFS="$SEP" read -r seq rule file line raw; do
    if [ -n "$file" ] && [ "$file" != "$cur_file" ]; then
      cur_file=$file at_base=0
      : > "$WORK/added"
      git cat-file -e "$base:$file" 2>/dev/null && at_base=1 && added_lines "$file" > "$WORK/added"
    fi
    verdict
    printf '%s\037%s\037%s\037%s\037%s\n' "$seq" "$v" "$rule" "$file" "$raw" >> "$WORK/resolved.tsv"
  done < "$WORK/candidates.sorted"
}

# emit_introduced: every introduced row in full, in the order the scouts first produced them.
emit_introduced() {
  sort -t "$SEP" -k1,1n -- "$WORK/resolved.tsv" \
    | awk -F "$SEP" '$2 == "introduced" { print "introduced " $5 }'
}

# emit_present_at_base: present-at-base rows collapsed to one line per rule and file, with a
# count, so an old, unrelated finding does not repeat once per hit.
emit_present_at_base() {
  awk -F "$SEP" '
    $2 == "present-at-base" {
      key = $3 SUBSEP $4
      if (!(key in n)) order[++k] = key
      n[key]++
    }
    END {
      for (i = 1; i <= k; i++) {
        split(order[i], f, SUBSEP)
        s = (n[order[i]] == 1) ? "" : "s"
        printf "present-at-base %s %s (%d hit%s)\n", f[1], f[2], n[order[i]], s
      }
    }' "$WORK/resolved.tsv"
}

emit_coverage() { cat "$WORK/coverage.log"; }

# print_tally: the closing line, counting raw hit occurrences (not the present-at-base groups)
# for n and m, and distinct files among the present-at-base hits for k; then the exit, 1 for any
# introduced row, 0 otherwise.
print_tally() {
  n=$(awk -F "$SEP" '$2 == "introduced"' "$WORK/resolved.tsv" | wc -l | tr -d ' ')
  m=$(awk -F "$SEP" '$2 == "present-at-base"' "$WORK/resolved.tsv" | wc -l | tr -d ' ')
  k=$(awk -F "$SEP" '$2 == "present-at-base" { print $4 }' "$WORK/resolved.tsv" | sort -u | wc -l | tr -d ' ')
  printf 'scout: %s introduced, %s present at base in %s files; ran: %s\n' "$n" "$m" "$k" "$ran"
  if [ "$n" -gt 0 ]; then exit 1; fi
  exit 0
}

materialize_block "$LAW_DOC" law
materialize_block "$DESIGN_DOC" design
touched="$WORK/touched"
build_touched "$touched"
ran=law
if design_touches_ui; then ran='law design'; fi
: > "$WORK/candidates.tsv"
: > "$WORK/coverage.log"
: > "$WORK/base-keys"
hit_seq=0
run_scouts "$repo_root" "$touched" "$WORK/now"
build_base_tree "$WORK/base-tree" "$WORK/base-list"
run_scouts "$WORK/base-tree" "$WORK/base-list" "$WORK/base"
for label in $ran; do
  queue_rows "$label" "$WORK/now-$label"
  queue_base_keys "$WORK/base-$label"
done
resolve_candidates
emit_introduced
emit_present_at_base
emit_coverage
print_tally
