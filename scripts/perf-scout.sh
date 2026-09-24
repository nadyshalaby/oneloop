#!/bin/bash
# engineering-rules perf scout runner.
# Turns the perf scout (9.4) into a runnable block, so its tables are run rather than read. The
# block holds 9.4's helper fence and COVERAGE fence verbatim, then one command per row of every
# pattern table whose section carries a `Runs over` line, in the doc's order. The doc is the one
# source of every pattern, catalog id, file glob and helper; this script only parses it. A row
# whose first cell is neither a pattern nor a `(via ...)` helper becomes a `not run:` line naming
# its id, and so does a section that runs over nothing, so the review knows what no pattern
# reached.
#
# The grammar, all of it written on 9.4's own lines:
#   Runs over `*.<ext> ...`, each pattern against the whole file[, a `(loop-window)` row
#     through `<helper>`][, case-insensitive].
#   Runs over `*.<ext> ...`, each pattern through `<helper>`.
#   Runs over nothing: <prose citing catalog ids>
#   A row's first cell: `<ERE>` alone, or followed by (with `-i`), (loop-window),
#     (inverted: `grep -L -i`) or (inverted: `grep -L -i`, among files matching `<ERE>`); or
#     (via `<helper>`). A `\|` inside a pattern is a table-escaped `|`.
#
# In the block, a loop-body row is matched against the text of the lines its section's helper
# returns for a match-anything pattern, never against the file name the helper prints before
# them, so a file named like a token (console.ts) does not make every line of it a hit.
#
# Usage: bash <er>/scripts/perf-scout.sh <9.4 doc> > block.sh
#   Run the block from the directory the listed paths are relative to, with SCOUT_LIST naming
#   the NUL-separated path list and SCOUT_PATHS a scratch file, as scripts/scout.sh runs every
#   scout.
#
# Exit: 0 the block is on stdout; 2 the doc is unreadable or lacks the helper or coverage fence,
#   a Runs line the grammar does not read, a pattern table with no Runs line, a row with no
#   catalog id, a helper the fence does not define, or no runnable row at all.
set -u

# usage_error <message>: the one-line stderr contract.
usage_error() {
  printf 'perf-scout: %s\n' "$1" >&2
  exit 2
}

TICK='`'
RUNS_RE="^Runs over ${TICK}([^${TICK}]+)${TICK}, each pattern (against the whole file|through ${TICK}([a-z_]+)${TICK})(, a ${TICK}\\(loop-window\\)${TICK} row through ${TICK}([a-z_]+)${TICK})?(, case-insensitive)?\\.\$"
VIA_RE="^\\(via ${TICK}([a-z_]+)${TICK}\\)\$"
ID_RE='^perf\.[a-z]+\.[a-z0-9-]+$'
EXT_RE='^\*\.([A-Za-z0-9]+)$'

# The block's own functions, printed into it with `declare -f`; the generator never calls them.

# tag <id>: prefixes every line with the rule that fired.
tag() { sed "s#^#$1 #"; }

# perf_files <ext>...: the listed paths whose file name ends in one of the extensions.
perf_files() {
  while IFS= read -r -d '' p; do
    case "${p##*/}" in *.*) ;; *) continue ;; esac
    case " $* " in *" ${p##*.} "*) printf '%s\0' "$p" ;; esac
  done < "$SCOUT_PATHS"
}

# section <ext>...: the section's files, NUL-separated in $PS/files, with no loop body yet.
section() {
  perf_files "$@" > "$PS/files"
  : > "$PS/text"
  : > "$PS/loc"
}

# body <helper>: every loop-body line of the section's files through the helper and a pattern
# that matches any line, its text in $PS/text and its file:line in $PS/loc, line for line.
body() {
  while IFS= read -r -d '' p; do
    "$1" "./$p" '.' | body_split "$p"
  done < "$PS/files"
}

# body_split <path>: one helper's output split into $PS/text and $PS/loc. The exact helpers
# print "./path:line:header:depth:text"; loop_window prints "line:text", "line-text" and "--".
body_split() {
  P="./$1:" F="$1" LOC="$PS/loc" TXT="$PS/text" awk '
    BEGIN { p = ENVIRON["P"]; f = ENVIRON["F"]; loc = ENVIRON["LOC"]; txt = ENVIRON["TXT"] }
    function emit(n, t) { print f ":" n >> loc; print t >> txt }
    index($0, p) == 1 {
      rest = substr($0, length(p) + 1)
      if (match(rest, /^[0-9]+:[0-9]+:[0-9]+:/)) { split(rest, a, ":"); emit(a[1], substr(rest, RLENGTH + 1)) }
      next
    }
    match($0, /^[0-9]+[-:]/) { emit(substr($0, 1, RLENGTH - 1), substr($0, RLENGTH + 1)) }'
}

# loop <id> <grep flags> <ERE>: the section's loop-body lines whose text matches the pattern.
loop() {
  grep -n "$2" -e "$3" -- "$PS/text" | awk '
    NR == FNR { loc[FNR] = $0; next }
    { n = $0; sub(/:.*/, "", n); print loc[n] ":" substr($0, length(n) + 2) }' "$PS/loc" - | tag "$1"
}

# whole <id> <grep flags> <ERE>: the pattern over each of the section's files.
whole() { xargs -0 -r grep -n "$2" -e "$3" -- /dev/null < "$PS/files" | tag "$1"; }

# inverted <id> <grep flags> <ERE> [<ERE>]: the section's files with no line matching the first
# pattern, among those with a line matching the second when there is one, reported at line 1.
inverted() {
  among "$2" "${4:-}" | xargs -0 -r grep -L "$2" -e "$3" -- | sed 's/$/:1:no line matches the row pattern/' | tag "$1"
}

# among <grep flags> <ERE>: the section's files, only those with a matching line when the
# pattern is not empty.
among() {
  if [ -z "$2" ]; then cat -- "$PS/files"; return; fi
  xargs -0 -r grep -l --null "$1" -e "$2" -- < "$PS/files"
}

# via <id> <helper>: the helper's own rows over each of the section's files, with the ./ it was
# handed taken back off the file name.
via() {
  while IFS= read -r -d '' p; do
    "$2" "./$p" | P="./$p:" F="$p" awk 'index($0, ENVIRON["P"]) == 1 { print ENVIRON["F"] ":" substr($0, length(ENVIRON["P"]) + 1) }'
  done < "$PS/files" | tag "$1"
}

# not_run <id> <why>: a row or a section no pattern reaches, named for the review.
not_run() { printf 'not run: %s: %s\n' "$1" "$2"; }

# The generator.

[ $# -eq 1 ] || usage_error 'usage: perf-scout.sh <9.4 doc>'
DOC=$1
[ -r "$DOC" ] || usage_error "cannot read $DOC"

# fence_after <heading>: the first ```bash fence after the line that starts with the heading.
fence_after() {
  H="$1" awk 'index($0, ENVIRON["H"]) == 1 { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$DOC"
}

HELPERS=$(fence_after '### HOW')
COVERAGE=$(fence_after '### COVERAGE')
[ -n "$HELPERS" ] || usage_error "no helper fence under ### HOW in $DOC"
[ -n "$COVERAGE" ] || usage_error "no fence under ### COVERAGE in $DOC"

# emit <command> <word>...: one line of the block, every word single-quoted, which keeps its
# bytes as they are (printf %q splits a multibyte character into escapes). The quote's escape
# sits in a variable because bash 3.2 keeps the backslashes of one written in the replacement.
QUOTE_ESCAPE="'\\''"
emit() {
  line=$1
  shift
  for w; do line="$line '${w//\'/$QUOTE_ESCAPE}'"; done
  printf '%s\n' "$line"
}

# trimmed <text>: the text without its leading and trailing blanks, in t.
trimmed() {
  t=${1#"${1%%[![:space:]]*}"}
  t=${t%"${t##*[![:space:]]}"}
}

# defined <helper>: stops the run unless the helper fence defines that function.
defined() {
  printf '%s\n' "$HELPERS" | grep -qE "^$1\(\) \{" || usage_error "the helper fence defines no $1()"
}

# emit_section <globs>: the command that selects a section's files, from globs that are all
# *.<ext>, since the block matches a file name's extension against a plain list.
emit_section() {
  read -r -a globs <<< "$1"
  exts=()
  for g in "${globs[@]}"; do
    [[ $g =~ $EXT_RE ]] || usage_error "a Runs glob that is not *.<ext>: $g"
    exts+=("${BASH_REMATCH[1]}")
  done
  [ "${#exts[@]}" -gt 0 ] || usage_error "a Runs line with no glob: $1"
  emit section "${exts[@]}"
}

# read_runs <line>: a section's Runs line sets its mode, loop helper and grep flags, and prints
# the command that selects its files; one that runs over nothing starts collecting its ids.
read_runs() {
  sec_mode=nothing sec_helper='' sec_flags=-E body_done=0 ids=''
  case "$1" in 'Runs over nothing:'*) return 0 ;; esac
  [[ $1 =~ $RUNS_RE ]] || usage_error "a Runs line the grammar does not read: $1"
  globs_text=${BASH_REMATCH[1]} through=${BASH_REMATCH[3]} window=${BASH_REMATCH[5]} fold=${BASH_REMATCH[6]}
  sec_mode=whole
  if [ -n "$through" ]; then sec_mode=loop sec_helper=$through; fi
  if [ -n "$window" ]; then sec_helper=$window; fi
  if [ -n "$fold" ]; then sec_flags=-iE; fi
  if [ -n "$sec_helper" ]; then defined "$sec_helper"; fi
  emit_section "$globs_text"
}

# need_body: the section's loop body, built once before its first loop row.
need_body() {
  if [ "$body_done" -eq 1 ]; then return 0; fi
  [ -n "$sec_helper" ] || usage_error "a loop row in a section with no loop helper: $row"
  emit body "$sec_helper"
  body_done=1
}

# pattern_row <id> <ERE> <marker> <first cell>: whole, loop or inverted by the section and the
# row's marker; a marker the grammar does not read leaves the row not run.
pattern_row() {
  flags=$sec_flags mode=$sec_mode among=''
  case "$3" in
    '') ;;
    "(with ${TICK}-i${TICK})") flags=-iE ;;
    '(loop-window)') mode=loop ;;
    "(inverted: ${TICK}grep -L -i${TICK})") mode=inverted flags=-iE ;;
    "(inverted: ${TICK}grep -L -i${TICK}, among files matching ${TICK}"*"${TICK})")
      mode=inverted flags=-iE among=${3#*matching "$TICK"} && among=${among%"$TICK)"} ;;
    *) mode=not_run ;;
  esac
  case "$mode" in
    whole) emit whole "$1" "$flags" "$2" ;;
    loop) need_body && emit loop "$1" "$flags" "$2" ;;
    inverted) emit inverted "$1" "$flags" "$2" ${among:+"$among"} ;;
    *) emit not_run "$1" "$4" && return 0 ;;
  esac
  runnable=$((runnable + 1))
}

# other_row <id> <first cell>: a (via `helper`) row runs the helper over the section's files;
# any other first cell is prose, named as not run.
other_row() {
  if [[ $2 =~ $VIA_RE ]]; then
    helper=${BASH_REMATCH[1]}
    defined "$helper"
    emit via "$1" "$helper"
    runnable=$((runnable + 1))
  else
    emit not_run "$1" "$2"
  fi
}

# read_row <line>: one row of a pattern table as one command of the block. A first cell that
# opens with a code span is a pattern and its marker; any other first cell is read whole.
read_row() {
  row=$1 cell=${1#|} span='' marker=''
  trimmed "$cell"
  cell=$t rest=$t
  if [ "${cell:0:1}" = "$TICK" ]; then
    span=${cell#"$TICK"} && rest=${span#*"$TICK"} && span=${span%%"$TICK"*}
    trimmed "${rest%%|*}"
    marker=$t first="$TICK$span$TICK${t:+ $t}"
  else
    trimmed "${cell%%|*}"
    first=$t
  fi
  after=${rest#*|}
  trimmed "${after%%|*}"
  [[ $t =~ $ID_RE ]] || usage_error "a row with no catalog id: $row"
  rows=$((rows + 1))
  if [ -n "$span" ]; then pattern_row "$t" "${span//\\|/|}" "$marker" "$first"; else other_row "$t" "$first"; fi
}

# read_table_line <line>: a table's first line is its header, which says whether it is a pattern
# table; its separator is skipped; every later line of a pattern table is a row.
read_table_line() {
  if [ "$in_table" -eq 0 ]; then
    in_table=1 pattern_table=0
    case "$1" in '| Pattern (ERE) |'*) pattern_table=1 ;; esac
    if [ "$pattern_table" -eq 1 ] && [ "$sec_mode" != whole ] && [ "$sec_mode" != loop ]; then
      usage_error "a pattern table with no Runs line above it: $1"
    fi
    return 0
  fi
  case "$1" in '|---'* | '| ---'*) return 0 ;; esac
  if [ "$pattern_table" -eq 1 ]; then read_row "$1"; fi
}

# close_section: a section that runs over nothing names every catalog id it cites.
close_section() {
  if [ "$sec_mode" = nothing ] && [ -n "$ids" ]; then emit not_run "${ids% }" 'read, not matched'; fi
  sec_mode='' in_table=0
}

# collect_ids <line>: in a section that runs over nothing, every catalog id the line cites.
collect_ids() {
  if [ "$sec_mode" != nothing ]; then return 0; fi
  ids="$ids$(printf '%s\n' "$1" | grep -oE 'perf\.[a-z]+\.[a-z0-9-]+' | tr '\n' ' ')"
}

# read_region: every line from ### HOW to ### COVERAGE outside a fence, through the grammar.
read_region() {
  sec_mode='' in_table=0 ids='' rows=0 runnable=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '#### '*) close_section ;;
      'Runs over '*) in_table=0; read_runs "$line" ;;
      '|'*) read_table_line "$line" ;;
      *) in_table=0; collect_ids "$line" ;;
    esac
  done < <(awk '/^### HOW/ { on = 1; next } /^### COVERAGE/ { exit } on && /^```/ { fence = !fence; next } on && !fence' "$DOC")
  close_section
  [ "$runnable" -gt 0 ] || usage_error "no runnable row in $DOC"
}

cat <<'EOF'
#!/bin/bash
# The perf scout (9.4) as commands, written by scripts/perf-scout.sh on every run; never edited.
cat -- "$SCOUT_LIST" > "$SCOUT_PATHS"
PS=$(mktemp -d "${TMPDIR:-/tmp}/perf-scout.XXXXXX") || exit 1
trap 'rm -rf "$PS"' EXIT
EOF
printf '%s\n' "$HELPERS" "$COVERAGE"
declare -f tag perf_files section body body_split loop whole inverted among via not_run
cat <<'EOF'
scout_coverage_from_list "$SCOUT_PATHS"
EOF
read_region
