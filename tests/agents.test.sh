#!/bin/bash
# Guard: the workflow's helpers are exactly the three custom agents in agents/, each with its
# own model and turn cap, and nothing else is ever sent. Every agent file names itself after
# its file, says what it is for, runs on a model the law allows (haiku, sonnet or opus) with a
# turn cap, and holds only the tools its job needs: the reader and the reviewer cannot edit,
# the builder can. The deciding helpers (builder, reviewer) carry the advisor line and the
# reader, which decides nothing, carries none. The workflow page names all three and sends no
# fork and no built-in agent type. AGENTS_DIR and WORKFLOW_MD point the test at other copies,
# for a watched failure. Run: bash tests/agents.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
AGENTS="${AGENTS_DIR:-$ROOT/agents}"
WORKFLOW="${WORKFLOW_MD:-$ROOT/skills/engineering-rules/SKILL.md}"
EXPECTED="er-builder er-reader er-reviewer"
READ_ONLY="er-reader er-reviewer"
DECIDING="er-builder er-reviewer"
ADVISOR_LINE='If your tools include an advisor'
TURN_CAP=40

# front_value <file> <key>: the frontmatter value of the key, empty when absent.
front_value() { sed -n '2,/^---$/p' "$1" | sed -n -E "s/^$2: *//p" | head -n 1; }

# agent_names <dir>: every agent file's name, from its file name, sorted.
agent_names() { find "$1" -maxdepth 1 -name '*.md' | sed 's#.*/##; s#\.md$##' | sort | tr '\n' ' ' | sed 's/ $//'; }

# listed <name> <space-separated list>: 0 when the name is in the list.
listed() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# tool_defects <name> <file>: a read-only agent that can edit, or a builder that cannot.
tool_defects() {
  tools=$(front_value "$2" tools)
  if listed "$1" "$READ_ONLY"; then
    case "$tools" in *Edit*|*Write*) printf '%s: a read-only helper holds %s\n' "$1" "$tools" ;; esac
  else
    case "$tools" in *Edit*Write*|*Write*Edit*) ;; *) printf '%s: cannot edit (%s)\n' "$1" "$tools" ;; esac
  fi
}

# agent_defects <dir>: one line per departure from the shape every agent keeps.
agent_defects() {
  for file in "$1"/*.md; do
    name=${file##*/}; name=${name%.md}
    [ "$(front_value "$file" name)" = "$name" ] || printf '%s: name is not %s\n' "$name" "$name"
    [ -n "$(front_value "$file" description)" ] || printf '%s: no description\n' "$name"
    case "$(front_value "$file" model)" in haiku|sonnet|opus) ;; *) printf '%s: model is not haiku, sonnet or opus\n' "$name" ;; esac
    turns=$(front_value "$file" maxTurns)
    case "$turns" in ''|*[!0-9]*) printf '%s: no numeric maxTurns\n' "$name" ;; *) [ "$turns" -le "$TURN_CAP" ] || printf '%s: maxTurns %s over %s\n' "$name" "$turns" "$TURN_CAP" ;; esac
    tool_defects "$name" "$file"
  done
}

# advisor_defects <dir>: a deciding agent with no advisor line, or the reader carrying one.
advisor_defects() {
  for file in "$1"/*.md; do
    name=${file##*/}; name=${name%.md}
    if listed "$name" "$DECIDING"; then grep -qF "$ADVISOR_LINE" "$file" || printf '%s: no advisor line\n' "$name"
    else grep -qF "$ADVISOR_LINE" "$file" && printf '%s: carries an advisor line\n' "$name"; fi
  done
  return 0
}

# send_defects <file>: an agent the workflow page does not name, or a send it must never make.
send_defects() {
  for name in $EXPECTED; do grep -qF "\`$name\`" "$1" || printf 'the workflow never names %s\n' "$name"; done
  grep -nE 'subagent_type|"(fork|Explore|Plan|general-purpose)"' "$1" | sed 's/^/sends a built-in type: /'
  return 0
}

test_exactly_the_three_helpers() {
  assert_eq "agents/ holds exactly the three helpers" "$EXPECTED" "$(agent_names "$AGENTS")"
}

test_every_helper_keeps_its_shape() {
  assert_eq "every helper names itself, has a model, a turn cap and only the tools it needs" "" "$(agent_defects "$AGENTS")"
  assert_eq "the builder and the reviewer carry the advisor line, the reader none" "" "$(advisor_defects "$AGENTS")"
}

test_the_workflow_sends_only_them() {
  assert_eq "the workflow names all three and sends no built-in type" "" "$(send_defects "$WORKFLOW")"
  assert_contains "and says so" "nothing else is sent (no fork, no built-in type)" "$(tr '\n' ' ' < "$WORKFLOW" | tr -s ' ')"
}

# The checks can fail: a misnamed agent, a model outside the set, a missing turn cap, a reader
# that can edit, a builder that cannot, a lost advisor line, a reader carrying one, an unnamed
# helper and a fork send are each named.
test_planted_breaches_are_named() {
  mkdir -p "$WORK/agents"
  printf -- '---\nname: er-reader\ndescription: d\ntools: Read, Edit\nmodel: haiku\nmaxTurns: 5\n---\n%s.\n' "$ADVISOR_LINE" > "$WORK/agents/er-reader.md"
  printf -- '---\nname: builder\ndescription: d\ntools: Read\nmodel: gpt\n---\nNo line.\n' > "$WORK/agents/er-builder.md"
  out=$(agent_defects "$WORK/agents")
  assert_contains "a reader that can edit is named" "er-reader: a read-only helper holds" "$out"
  assert_contains "a misnamed agent is named" "er-builder: name is not er-builder" "$out"
  assert_contains "a model outside the set is named" "er-builder: model is not haiku, sonnet or opus" "$out"
  assert_contains "a missing turn cap is named" "er-builder: no numeric maxTurns" "$out"
  assert_contains "a builder that cannot edit is named" "er-builder: cannot edit" "$out"
  out=$(advisor_defects "$WORK/agents")
  assert_contains "a deciding helper that lost the line is named" "er-builder: no advisor line" "$out"
  assert_contains "a reader carrying the line is named" "er-reader: carries an advisor line" "$out"
  tick=$(printf '\140')
  printf 'Send %ser-reader%s and %ser-builder%s with subagent_type "fork".\n' "$tick" "$tick" "$tick" "$tick" > "$WORK/workflow.md"
  out=$(send_defects "$WORK/workflow.md")
  assert_contains "an unnamed helper is named" "the workflow never names er-reviewer" "$out"
  assert_contains "a built-in send is named" "sends a built-in type" "$out"
}

test_exactly_the_three_helpers
test_every_helper_keeps_its_shape
test_the_workflow_sends_only_them
test_planted_breaches_are_named
report
