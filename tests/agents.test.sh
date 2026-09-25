#!/bin/bash
# Guard: the law's one helper is the read-only reader in agents/, and nothing else is ever sent
# (10.0.0, the user's words: "No Builder, no Reviewer"). The one agent file names itself after
# its file, says what it is for, runs on haiku (the law says a Haiku search) with a turn cap,
# holds no editing tool, and its description carries the law's condition: sent only after grep
# has failed twice, and only to search. The law names it and sends no fork and no built-in agent
# type. AGENTS_DIR and LAW_MD point the test at other copies, for a watched failure.
# Run: bash tests/agents.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
AGENTS="${AGENTS_DIR:-$ROOT/agents}"
LAW="${LAW_MD:-$ROOT/law/engineering-law.md}"
EXPECTED="er-reader"
TURN_CAP=12
CONDITION="after grep has failed twice"
TICK=$(printf '\140')

# front_value <file> <key>: the frontmatter value of the key, empty when absent.
front_value() { sed -n '2,/^---$/p' "$1" | sed -n -E "s/^$2: *//p" | head -n 1; }

# agent_names <dir>: every agent file's name, from its file name, sorted.
agent_names() { find "$1" -maxdepth 1 -name '*.md' | sed 's#.*/##; s#\.md$##' | sort | tr '\n' ' ' | sed 's/ $//'; }

# agent_defects <dir>: one line per departure from the shape the reader keeps.
agent_defects() {
  for file in "$1"/*.md; do
    name=${file##*/}; name=${name%.md}
    [ "$(front_value "$file" name)" = "$name" ] || printf '%s: name is not %s\n' "$name" "$name"
    description=$(front_value "$file" description)
    [ -n "$description" ] || printf '%s: no description\n' "$name"
    case "$description" in *"$CONDITION"*) ;; *) printf '%s: the description does not carry the condition (%s)\n' "$name" "$CONDITION" ;; esac
    case "$description" in [Rr]ead-only*|*" read-only "*|*"Read-only "*) ;; *) printf '%s: the description does not say read-only\n' "$name" ;; esac
    [ "$(front_value "$file" model)" = haiku ] || printf '%s: model is not haiku\n' "$name"
    turns=$(front_value "$file" maxTurns)
    case "$turns" in ''|*[!0-9]*) printf '%s: no numeric maxTurns\n' "$name" ;; *) [ "$turns" -le "$TURN_CAP" ] || printf '%s: maxTurns %s over %s\n' "$name" "$turns" "$TURN_CAP" ;; esac
    case "$(front_value "$file" tools)" in *Edit*|*Write*) printf '%s: a read-only helper holds %s\n' "$name" "$(front_value "$file" tools)" ;; esac
  done
}

# law_defects <law> <agents dir>: the law not naming the reader, or a send it must never make.
law_defects() {
  grep -qF "${TICK}er-reader${TICK}" "$1" || printf 'the law never names er-reader\n'
  grep -qF "never a ${TICK}fork${TICK}" "$1" || printf 'the law does not refuse a fork\n'
  grep -nE 'subagent_type|"(fork|Explore|Plan|general-purpose)"' "$1" "$2"/*.md | sed 's/^/sends a built-in type: /'
  return 0
}

test_exactly_the_one_helper() {
  assert_eq "agents/ holds exactly the reader" "$EXPECTED" "$(agent_names "$AGENTS")"
}

test_the_reader_keeps_its_shape() {
  assert_eq "the reader names itself, runs on haiku with a turn cap, cannot edit, and says when it is sent" "" "$(agent_defects "$AGENTS")"
}

test_the_law_sends_only_it() {
  assert_eq "the law names the reader, refuses a fork and sends no built-in type" "" "$(law_defects "$LAW" "$AGENTS")"
}

# The checks can fail: a second helper file, a reader that can edit, a misnamed agent, a model
# outside haiku, a missing turn cap, a description without the condition, and a law that names
# no reader are each named.
test_planted_breaches_are_named() {
  mkdir -p "$WORK/agents"
  printf -- '---\nname: er-reader\ndescription: Searches a tree whenever asked.\ntools: Read, Edit\nmodel: haiku\nmaxTurns: 5\n---\nbody\n' > "$WORK/agents/er-reader.md"
  printf -- '---\nname: builder\ndescription: d\ntools: Read\nmodel: sonnet\n---\nNo cap.\n' > "$WORK/agents/er-builder.md"
  assert_eq "a second helper file is named" "er-builder er-reader" "$(agent_names "$WORK/agents")"
  out=$(agent_defects "$WORK/agents")
  assert_contains "a reader that can edit is named" "er-reader: a read-only helper holds" "$out"
  assert_contains "a description without the condition is named" "er-reader: the description does not carry the condition" "$out"
  assert_contains "a misnamed agent is named" "er-builder: name is not er-builder" "$out"
  assert_contains "a model outside haiku is named" "er-builder: model is not haiku" "$out"
  assert_contains "a missing turn cap is named" "er-builder: no numeric maxTurns" "$out"
  printf 'Helpers: send %ser-builder%s with subagent_type "fork".\n' "$TICK" "$TICK" > "$WORK/law.md"
  out=$(law_defects "$WORK/law.md" "$WORK/agents")
  assert_contains "a law that names no reader is named" "the law never names er-reader" "$out"
  assert_contains "a built-in send is named" "sends a built-in type" "$out"
}

test_exactly_the_one_helper
test_the_reader_keeps_its_shape
test_the_law_sends_only_it
test_planted_breaches_are_named
report
