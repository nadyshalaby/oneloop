#!/bin/bash
# Guard: the perf scout's tables (9.4) are run, not read. scripts/perf-scout.sh turns them into a
# block, and this checks that every row of every pattern section becomes exactly one command
# (counted per section against the doc by a separate reading), that the only rows it leaves as
# `not run` are the prose ones, that a planted hit in each section comes back through
# scripts/scout.sh under its own catalog id, that a file named like a token is not a hit because
# of its name, and that a doc the grammar cannot read stops the run with exit 2.
# Run: bash tests/perf-scout.test.sh
# PERF_SCOUT_SH and SCOUT_SH point the test at other copies of the two scripts (scout.sh runs the
# perf-scout.sh beside it), for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
RUNNER="${PERF_SCOUT_SH:-$ROOT/scripts/perf-scout.sh}"
SCOUT="${SCOUT_SH:-$ROOT/scripts/scout.sh}"
DOC="$ROOT/references/09-implement/9.4-the-perf-scout.md"
ID_CMD="^(whole|loop|inverted|via|not_run) 'perf\\.[a-z]+\\.[a-z0-9-]+' "
TICK=$(printf '\140')

# doc_rows <doc>: the row count of each pattern section, in order, read straight off the doc.
doc_rows() {
  awk '/^### HOW/ { on = 1; next } /^### COVERAGE/ { exit } !on { next }
    /^```/ { fence = !fence; next } fence { next }
    function done_section() { if (n != "") out = out (out == "" ? "" : " ") n; n = "" }
    /^#### / { done_section(); runs = 0; next }
    /^Runs over `/ { runs = 1; n = 0; next }
    runs && /^\| / && !/^\| Pattern \(ERE\) \|/ { n++ }
    END { done_section(); printf "%s", out }' "$1"
}

# block_rows <block>: the row commands between each pair of `section` lines, in order.
block_rows() {
  RE="$ID_CMD" awk '/^section '"'"'/ { if (on) printf "%d ", n; n = 0; on = 1; next }
    $0 ~ ENVIRON["RE"] { n++ } END { if (on) printf "%d", n }' "$1"
}

test_every_row_becomes_one_command() {
  "$BASH" "$RUNNER" "$DOC" > "$WORK/block.sh"
  assert_eq "the runner exits 0 on the real doc" 0 "$?"
  want=$(doc_rows "$DOC")
  assert_eq "each section's rows, doc against block ($want)" "$want" "$(block_rows "$WORK/block.sh")"
  assert_eq "five pattern sections" 5 "$(printf '%s\n' "$want" | wc -w | tr -d ' ')"
}

test_only_the_prose_rows_are_not_run() {
  prose=$(grep -E "^not_run 'perf\\.[a-z]+\\.[a-z0-9-]+' " "$WORK/block.sh" | awk '{ print $2 }' | tr -d "'" | tr '\n' ' ')
  assert_eq "the three shell prose rows, and nothing else" "perf.algorithmic.loop-invariant perf.algorithmic.loop-invariant perf.algorithmic.nested-loop-join " "$prose"
  assert_contains "the reading-only section names its ids" "not_run 'perf.data.missing-index perf.network.sequential-awaits" "$(cat "$WORK/block.sh")"
}

# build_planted: a repo with one committed file and, untracked, one planted hit per section, a
# SQL file with no SELECT and a file named like the log token.
build_planted() (
  git init -q "$WORK/planted" && cd "$WORK/planted" || return 1
  printf 'planted\n' > README.md && git add README.md
  git -c user.name=t -c user.email=t@example.com commit -q -m base
  printf 'const copy = JSON.parse(JSON.stringify(input))\nexport async function run(items) {\n  await first()\n  await second()\n  for (const item of items) {\n    await save(item)\n  }\n}\n' > app.ts
  printf 'let total = 0\nfor (const n of [1, 2]) {\n  total += n\n}\n' > console.ts
  printf 'import re, time\ntime.sleep(1)\nfor row in rows:\n    re.compile(row)\n' > job.py
  cat > run.sh <<'EOF'
#!/bin/bash
out=""
for f in "$@"; do
  n=$(basename "$f")
  out="$out $n"
done
EOF
  printf 'SELECT * FROM users;\n' > q.sql
  printf 'CREATE TABLE t (id int);\n' > m.sql
)

test_a_planted_hit_in_each_section_comes_back() {
  out=$(cd "$WORK/planted" && ENGINEERING_RULES_HOME="$ROOT" "$BASH" "$SCOUT" HEAD 2>&1)
  assert_contains "JS/TS whole file" "introduced perf.memory.json-deep-clone app.ts:1:" "$out"
  assert_contains "JS/TS through seq_awaits" "introduced perf.network.sequential-awaits app.ts:4:" "$out"
  assert_contains "JS/TS loop body" "introduced perf.async.await-in-loop app.ts:6:" "$out"
  assert_contains "Python whole file" "introduced perf.async.sleep-poll job.py:2:" "$out"
  assert_contains "Python loop body" "introduced perf.algorithmic.regex-in-loop job.py:4:" "$out"
  assert_contains "shell loop body" "introduced perf.process.fork-for-builtin run.sh:4:" "$out"
  assert_contains "shell through sh_accum" "introduced perf.algorithmic.string-concat-loop run.sh:5:" "$out"
  assert_contains "SQL whole file" "introduced perf.data.select-star q.sql:1:" "$out"
  assert_contains "SQL inverted, among the SELECT files" "introduced perf.data.unbounded-result q.sql:1:" "$out"
  assert_missing "a SQL file with no SELECT is not an unbounded result" "unbounded-result m.sql" "$out"
  assert_missing "a file named like the log token is not a hit by its name" "log-in-hot-loop console.ts" "$out"
  assert_contains "a prose row is named as not run" "not run: perf.algorithmic.nested-loop-join" "$out"
  tally=$(printf '%s\n' "$out" | grep '^scout:')
  assert_eq "the closing tally line" 'scout: 10 introduced, 0 present at base in 0 files; ran: perf law' "$tally"
}

# broken <name> <sed program>: the real doc with one edit, as $WORK/<name>.md.
broken() { sed "$2" "$DOC" > "$WORK/$1.md"; }

# run_on <name>: the runner over that copy, its stderr and exit code.
run_on() {
  { "$BASH" "$RUNNER" "$WORK/$1.md" > /dev/null; } 2>&1
  printf 'exit=%s\n' "$?"
}

# The checks can fail: every way a doc can stop being runnable stops the run, named.
test_a_doc_the_grammar_cannot_read_stops_the_run() {
  broken runs "s/^Runs over ${TICK}\\*\\.sql${TICK}, each pattern against the whole file, case-insensitive\\.\$/Runs over ${TICK}*.sql${TICK}, each pattern somehow./"
  assert_contains "an unreadable Runs line" "a Runs line the grammar does not read" "$(run_on runs)"
  broken glob "s/^Runs over ${TICK}\\*\\.py${TICK}/Runs over ${TICK}py*${TICK}/"
  assert_contains "a glob that is not *.<ext>" "a Runs glob that is not" "$(run_on glob)"
  broken no-runs "/^Runs over ${TICK}\\*\\.sql${TICK}/d"
  assert_contains "a pattern table with no Runs line" "a pattern table with no Runs line above it" "$(run_on no-runs)"
  broken helper "s/(via ${TICK}seq_awaits${TICK})/(via ${TICK}no_such_helper${TICK})/"
  assert_contains "a helper the fence does not define" "the helper fence defines no no_such_helper()" "$(run_on helper)"
  broken id 's/| perf\.data\.select-star |/| |/'
  assert_contains "a row with no catalog id" "a row with no catalog id" "$(run_on id)"
  broken fence '/^```bash$/d'
  out=$(run_on fence)
  assert_contains "no helper fence" "no helper fence under ### HOW" "$out"
  assert_contains "and every one exits 2" "exit=2" "$out"
}

build_planted || { printf 'FAIL could not build the planted repo\n'; exit 1; }
test_every_row_becomes_one_command
test_only_the_prose_rows_are_not_run
test_a_planted_hit_in_each_section_comes_back
test_a_doc_the_grammar_cannot_read_stops_the_run
report
