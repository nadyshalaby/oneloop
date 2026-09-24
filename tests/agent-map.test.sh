#!/bin/bash
# Guard: the map of run point to agent to model says the same thing in all three places that
# state it (SKILL.md 1.8, the shapes and the runtime table of 5.5). Every map row names one of
# the six shapes, one of the four agent types Claude Code ships and a model the law allows;
# every shape a row names has its prompt block in 5.5; and the type-and-model pairs of the
# runtime table are exactly the pairs of the map, so a model can never be changed in one file
# alone. Run: bash tests/agent-map.test.sh
# SKILL_MD and DELEGATION_MD point the test at another pair of files, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILL="${SKILL_MD:-$ROOT/skills/engineering-rules/SKILL.md}"
DELEGATION="${DELEGATION_MD:-$ROOT/references/05-working-references/5.5-the-phase-agents-what-this-session-keeps.md}"
SHAPES="reader|planner|spec reviewer|reviewer|builder|mechanic"
TYPES="fork|Explore|Plan|general-purpose"
MODELS="sonnet|opus|session"

# cell <n>: field n of a markdown table row on stdin, trimmed, backticks stripped.
cell() { awk -F'|' -v n="$1" '{ gsub(/^[ \140]+|[ \140]+$/, "", $n); print $n }'; }

# map_rows: the rows of the map table in 1.8, one per run point.
map_rows() { grep -E '^\| (Phase|Run point) ' "$SKILL" | grep -v '^| Run point |'; }

# runtime_rows: the rows of the runtime table in 5.5, one per run point.
runtime_rows() { sed -n '/^## On the runtime/,/^Builders are/p' "$DELEGATION" | grep -E '^\| [a-z]' | grep -v '^| Run point |'; }

# listed <value> <pipe-separated list>: 0 when the value is one whole entry of the list.
listed() { case "|$2|" in *"|$1|"*) return 0 ;; esac; return 1; }

# model_of <cell>: the model a Model cell names, normalised; a fork's reads "session".
model_of() { case "$1" in *sonnet*) printf sonnet ;; *opus*) printf opus ;; *"session's"*|none*) printf session ;; *) printf '%s' "$1" ;; esac; }

# shape_of <cell>: the shape a Shape or Prompt cell names, "reviewer" for both reviewers.
shape_of() { case "$1" in *"spec reviewer"*) printf 'spec reviewer' ;; *reviewer*) printf reviewer ;; *) printf '%s' "$1" ;; esac; }

# map_defects: one line per map row that names a shape, a type or a model the law does not.
map_defects() {
  while IFS= read -r row; do
    point=$(printf '%s\n' "$row" | cell 2)
    shape=$(shape_of "$(printf '%s\n' "$row" | cell 3)")
    type=$(printf '%s\n' "$row" | cell 4)
    model=$(model_of "$(printf '%s\n' "$row" | cell 5)")
    listed "$shape" "$SHAPES" || printf '%s: unknown shape %s\n' "$point" "$shape"
    listed "$type" "$TYPES" || printf '%s: unknown type %s\n' "$point" "$type"
    listed "$model" "$MODELS" || printf '%s: unknown model %s\n' "$point" "$model"
    [ "$type" = fork ] || [ "$model" != session ] || printf '%s: a fresh type with no model\n' "$point"
    [ "$type" != fork ] || [ "$model" = session ] || printf '%s: a fork carrying a model\n' "$point"
  done < <(map_rows)
}

# missing_prompts: every shape a map row names whose prompt block is absent from 5.5.
missing_prompts() {
  while IFS= read -r row; do
    shape=$(shape_of "$(printf '%s\n' "$row" | cell 3)")
    type=$(printf '%s\n' "$row" | cell 4)
    [ "$type" = fork ] && continue
    grep -qi "^### The $shape" "$DELEGATION" || printf '%s: no prompt block in 5.5\n' "$shape"
  done < <(map_rows) | sort -u
}

# pairs_of <rows function> <type field> <model field>: the sorted type-and-model pairs.
pairs_of() {
  while IFS= read -r row; do
    printf '%s %s\n' "$(printf '%s\n' "$row" | cell "$2")" "$(model_of "$(printf '%s\n' "$row" | cell "$3")")"
  done < <("$1") | sort -u
}

test_every_map_row_is_legal() {
  rows=$(map_rows | grep -c .)
  defects=$(map_defects)
  assert_contains "every map row names a known shape, type and model ($rows rows)" "<none>" "${defects:-<none>}"
}

test_every_shape_has_a_prompt() {
  missing=$(missing_prompts)
  assert_contains "every shape a map row names has its prompt in 5.5" "<none>" "${missing:-<none>}"
}

test_the_runtime_table_agrees_with_the_map() {
  assert_eq "the runtime table's type-and-model pairs are the map's" "$(pairs_of map_rows 4 5)" "$(pairs_of runtime_rows 3 4)"
}

test_the_model_words_are_in_the_law() {
  assert_contains "1.8 names the model on every send but a fork" "every time but a fork" "$(cat "$SKILL")"
  assert_contains "5.5 says a fork cannot take another model" "cannot be put on another model" "$(cat "$DELEGATION")"
}

# The checks have to be able to fail: a row on an unknown model, a fork carrying a model, a
# shape with no prompt block and a runtime row whose model drifted are all named.
test_planted_breaches_are_named() {
  tick=$(printf '\140')
  { printf '| Run point | Shape (5.5) | Type | Model | Why this one |\n'
    printf '| Phase 9, the ghost | ghost | %sgeneral-purpose%s | %shaiku%s | because |\n' "$tick" "$tick" "$tick" "$tick"
    printf '| Phase 9, the fork | reader | %sfork%s | %sopus%s | because |\n' "$tick" "$tick" "$tick" "$tick"
  } > "$WORK/skill.md"
  SKILL="$WORK/skill.md"
  assert_contains "a row on a model the law does not name is named" "unknown model haiku" "$(map_defects)"
  assert_contains "a row on a shape with no prompt is named" "unknown shape ghost" "$(map_defects)"
  assert_contains "a fork carrying a model is named" "a fork carrying a model" "$(map_defects)"
  assert_contains "a shape with no prompt block is named" "ghost: no prompt block" "$(missing_prompts)"
}

test_every_map_row_is_legal
test_every_shape_has_a_prompt
test_the_runtime_table_agrees_with_the_map
test_the_model_words_are_in_the_law
test_planted_breaches_are_named
report
