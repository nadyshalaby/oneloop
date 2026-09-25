#!/bin/bash
# Guard: the advisor law says one thing in every place that states it. The core law carries
# the rule, keyed on the tool list, with its answer ranked as a report and no verdict written
# for a call never made; the workflow page records whether there is one at the start and names
# its run points (the plan, the review, the self-audit); 5.7 exists, is listed in the law's map
# and keys on the tool list alone, never on a model; and the cue that carries the rule to every
# prompt is wired to UserPromptSubmit, answers only that event, names 5.7 and refuses nothing. The
# helpers' own advisor lines are tests/agents.test.sh's. LAW_MD, WORKFLOW_MD and REFS_DIR point
# the test at other copies, for a watched failure. Run: bash tests/advisor-wiring.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
LAW="${LAW_MD:-$ROOT/law/engineering-law.md}"
WORKFLOW="${WORKFLOW_MD:-$ROOT/skills/workflow/SKILL.md}"
REFS="${REFS_DIR:-$ROOT/references}"
TICK=$(printf '\140')

# ref_file <section id>: the reference file whose name starts with the id, or nothing.
ref_file() { find "$REFS" -name "$1-*.md" | head -n 1; }

# folded <file>: the file on one line with its whitespace folded, so wrapped prose matches.
folded() { tr '\n' ' ' < "$1" | tr -s ' \t' ' '; }

# law_gaps <law> <workflow>: one line per statement of the rule that is missing.
law_gaps() {
  law=$(folded "$1"); flow=$(folded "$2")
  for want in "Every decision goes past the ${TICK}advisor${TICK} tool when the tool list holds one" \
      'Its answer is a report, not proof' 'No advisor: say so once' \
      'never write a verdict for a call you did not make (5.7)'; do
    case "$law" in *"$want"*) ;; *) printf 'the law lacks: %s\n' "$want" ;; esac
  done
  for want in 'Advisor: yes | no.' 'the advisor checks the plan' 'Consult the advisor, then decide' \
      'the advisor at plan, review, direction, done'; do
    case "$flow" in *"$want"*) ;; *) printf 'the workflow lacks: %s\n' "$want" ;; esac
  done
}

test_the_law_and_the_workflow_state_the_rule() {
  assert_eq "the core law states the rule and the workflow names its run points" "" "$(law_gaps "$LAW" "$WORKFLOW")"
}

test_the_protocol_file_is_listed_and_model_blind() {
  file=$(ref_file 5.7)
  assert_contains "5.7 exists" '5.7-the-advisor.md' "${file:-<missing>}"
  assert_contains "the law's map lists 5.7" "5.7 the advisor" "$(folded "$LAW")"
  protocol=$(cat "$file")
  assert_contains "5.7 keys on the tool list alone" 'The test is the tool list, and nothing else.' "$protocol"
  assert_contains "5.7 keeps the step when there is no advisor" 'The step does not drop out; only the call' "$protocol"
  assert_contains "5.7 ranks the answer under evidence" 'A report, never proof' "$protocol"
  assert_contains "5.7 ranks the answer under the user" 'The user, the goal and this law outrank it.' "$protocol"
}

test_the_cue_is_wired_at_the_prompt_boundary() {
  wired=$(jq -r '.hooks.UserPromptSubmit[]?.hooks[]?.command' "$ROOT/settings/hooks.json")
  assert_contains "the cue runs on UserPromptSubmit" 'hooks/advisor-cue.sh' "$wired"
  if [ -f "$ROOT/hooks/advisor-cue.sh" ]; then present=present; else present=missing; fi
  assert_contains "the cue script is there" present "$present"
  cue=$(cat "$ROOT/hooks/advisor-cue.sh")
  assert_contains "the cue answers only its own event" '= UserPromptSubmit ] || exit 0' "$cue"
  assert_contains "the cue names the protocol file" '5.7-the-advisor.md' "$cue"
  assert_contains "5.7 says the cue refuses nothing" 'It judges
nothing and refuses nothing.' "$(cat "$(ref_file 5.7)")"
}

# The check can fail: a law that lost the no-advisor line and a workflow that lost the plan's
# run point are both named.
test_planted_breaches_are_named() {
  grep -vF 'No advisor: say so once' "$LAW" > "$WORK/law.md"
  sed 's/the advisor checks the plan/the plan is checked/' "$WORKFLOW" > "$WORK/workflow.md"
  out=$(law_gaps "$WORK/law.md" "$WORK/workflow.md")
  assert_contains "a law that lost a statement is named" "the law lacks: No advisor: say so once" "$out"
  assert_contains "a workflow that lost a run point is named" "the workflow lacks: the advisor checks the plan" "$out"
}

test_the_law_and_the_workflow_state_the_rule
test_the_protocol_file_is_listed_and_model_blind
test_the_cue_is_wired_at_the_prompt_boundary
test_planted_breaches_are_named
report
