#!/bin/bash
# Guard: the advisor law says one thing in every place that states it. SKILL.md defines the
# advisor tool, carries the always-on bullet of 1.4 and asks about it in the self-audit; 5.7
# exists, is listed in 0.1 and keys on the tool list alone, never on a model; every section a
# row of 5.7's run-point table names cites 5.7 back, and no phase file cites it without a row;
# the four prompts of 5.5 whose shape decides something carry the advisor line word for word
# and the two that decide nothing carry none; 5.1 records it on the substrate line and on the
# reflection; and the cue that carries the rule to a session which never loaded the skill is
# wired to UserPromptSubmit and refuses nothing. Run: bash tests/advisor-wiring.test.sh
# SKILL_MD and REFS_DIR point the test at another law file and another references tree, for a
# watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILL="${SKILL_MD:-$ROOT/skills/engineering-rules/SKILL.md}"
REAL_REFS="${REFS_DIR:-$ROOT/skills/engineering-rules/references}"
REFS=$REAL_REFS
ADVISOR_LINE='If your tools include an advisor, it is the one tool you may use that this prompt does not name'
TICK=$(printf '\140')
FENCE="$TICK$TICK$TICK"

# ref_file <section id>: the reference file whose name starts with the id, or nothing.
ref_file() { find "$REFS" -name "$1-*.md" | head -n 1; }

# run_point_ids: the section id each row of 5.7's run-point table names in its Where column.
run_point_ids() {
  sed -n '/^## The run points/,/^## How the call is set up/p' "$(ref_file 5.7)" \
    | grep -E '^\| ' | grep -vE '^\| (Run point|-)' | awk -F'|' '{ print $3 }' \
    | grep -oE '[0-9]+\.[0-9]+' | sort -u
}

# cites_advisor <file>: 0 when the file cites section 5.7 by id, never on 15.7 or 5.70.
cites_advisor() { [ -f "$1" ] && grep -qE '(^|[^0-9.])5\.7([^0-9]|$)' "$1"; }

# unwired: every run-point section with no file, or whose file never cites 5.7 back.
unwired() {
  for id in $(run_point_ids); do
    file=$(ref_file "$id")
    [ -n "$file" ] || { printf '%s: no reference file\n' "$id"; continue; }
    cites_advisor "$file" || printf '%s: never cites 5.7\n' "$id"
  done
}

# unlisted: every phase file, groups 6 to 13, that cites 5.7 with no row in the table.
unlisted() {
  ids=$(run_point_ids)
  for file in "$REFS"/0[6-9]-*/*.md "$REFS"/1[0-3]-*/*.md; do
    cites_advisor "$file" || continue
    id=$(basename "$file" | grep -oE '^[0-9]+\.[0-9]+')
    printf '%s\n' "$ids" | grep -qxF "$id" || printf '%s: cites 5.7 with no run-point row\n' "$id"
  done
}

# prompt_block <shape>: the fenced prompt of 5.5 under "### The <shape>", fences left out.
prompt_block() {
  awk -v h="### The $1" '
    index($0, h) == 1 { on = 1; next }
    on && /^```/ { fences++; if (fences == 2) exit; next }
    on && fences == 1
  ' "$(ref_file 5.5)"
}

# prompt_defects: a deciding prompt with no advisor line, or a silent one carrying it.
prompt_defects() {
  for shape in planner "spec reviewer" reviewer builder; do
    case "$(prompt_block "$shape")" in *"$ADVISOR_LINE"*) ;; *) printf '%s: no advisor line\n' "$shape" ;; esac
  done
  for shape in reader mechanic; do
    case "$(prompt_block "$shape")" in *"$ADVISOR_LINE"*) printf '%s: carries an advisor line\n' "$shape" ;; esac
  done
}

test_the_law_file_states_the_rule() {
  law=$(cat "$SKILL")
  assert_contains "Definitions names the advisor tool" '| **The advisor tool** |' "$law"
  assert_contains "1.4 carries the always-on bullet" '**Every decision goes past the advisor tool, whenever the tool list holds one.**' "$law"
  assert_contains "the rule keys on the tool list, never on a model" 'The test is the tool list, never the model' "$law"
  assert_contains "a session with no advisor is never an error" 'No advisor tool is never an error' "$law"
  assert_contains "task start records it on the substrate line" 'whether the tool list holds an advisor (1.4, 5.7)' "$law"
  assert_contains "the self-audit asks about every run point" 'Every advisor run point (5.7) consulted' "$law"
  assert_contains "the map names the protocol file" 'the advisor (5.7)' "$law"
}

test_the_protocol_file_is_listed_and_model_blind() {
  file=$(ref_file 5.7)
  assert_contains "5.7 exists" '5.7-the-advisor.md' "${file:-<missing>}"
  assert_contains "0.1 lists 5.7" "| ${TICK}5.7${TICK} |" "$(cat "$(ref_file 0.1)")"
  protocol=$(cat "$file")
  assert_contains "5.7 keys on the tool list alone" 'The test is the tool list, and nothing else.' "$protocol"
  assert_contains "5.7 keeps the step when there is no advisor" 'The step does not drop out; only the call' "$protocol"
  assert_contains "5.7 ranks the answer under evidence" 'A report, never proof' "$protocol"
  assert_contains "5.7 ranks the answer under the user" 'The user, the anchor and this law outrank it.' "$protocol"
}

test_every_run_point_is_wired_both_ways() {
  rows=$(run_point_ids | grep -c .)
  count=$((count + 1))
  if [ "$rows" -gt 0 ]; then printf 'ok   the run-point table names %s sections\n' "$rows"
  else printf 'FAIL the run-point table names no section\n'; failures=$((failures + 1)); fi
  missing=$(unwired)
  assert_contains "every section a run point names cites 5.7 back" "<none>" "${missing:-<none>}"
  stray=$(unlisted)
  assert_contains "no phase file cites 5.7 without a run-point row" "<none>" "${stray:-<none>}"
}

test_the_deciding_prompts_carry_the_line() {
  defects=$(prompt_defects)
  assert_contains "four prompts carry the advisor line, the reader and the mechanic none" "<none>" "${defects:-<none>}"
}

test_the_cue_is_wired_at_the_prompt_boundary() {
  wired=$(jq -r '.hooks.UserPromptSubmit[]?.hooks[]?.command' "$ROOT/hooks/hooks.json")
  assert_contains "the cue runs on UserPromptSubmit" 'hooks/advisor-cue.sh' "$wired"
  if [ -f "$ROOT/hooks/advisor-cue.sh" ]; then present=present; else present=missing; fi
  assert_contains "the cue script is there" present "$present"
  cue=$(cat "$ROOT/hooks/advisor-cue.sh")
  assert_contains "the cue answers only its own event" '= UserPromptSubmit ] || exit 0' "$cue"
  assert_contains "the cue names the protocol file" '5.7-the-advisor.md' "$cue"
  assert_contains "1.4 names the hook" "this plugin's advisor cue hook puts this rule into every prompt" "$(cat "$SKILL")"
  assert_contains "5.7 says the cue refuses nothing" 'It judges
nothing and refuses nothing.' "$(cat "$(ref_file 5.7)")"
}

test_the_ledger_records_it() {
  ledger=$(cat "$(ref_file 5.1)")
  assert_contains "5.1 records an advisor on the substrate line" "${TICK}Advisor: on.${TICK}" "$ledger"
  assert_contains "5.1 records a session with none" 'Advisor: none in this session;' "$ledger"
  assert_contains "5.1 puts the verdict on the reflection" "${TICK}advisor: agreed${TICK}" "$ledger"
}

# plant_tree: a references tree whose table names 8.1 and a ghost, where 8.1 cites only
# look-alike ids, 11.1 cites 5.7 with no row, the builder lost its line and the mechanic has one.
plant_tree() {
  mkdir -p "$WORK/refs/05-working-references" "$WORK/refs/08-phase-2-5-spec-review" "$WORK/refs/11-phase-4-verify"
  { printf '## The run points\n\n| Run point | Where | What the advisor weighs |\n|---|---|---|\n'
    printf '| Before the plan is edited | %s8.1%s, acting on it | the findings |\n' "$TICK" "$TICK"
    printf '| Before the ghost | %s99.9%s | nothing |\n\n## How the call is set up\n' "$TICK" "$TICK"
  } > "$WORK/refs/05-working-references/5.7-the-advisor.md"
  printf '# 8.1\n\nActing on it: see 15.7 and 5.70, and nothing else.\n' > "$WORK/refs/08-phase-2-5-spec-review/8.1-phase-2-5-spec-review.md"
  printf '# 11.1\n\nThen the advisor (5.7), before the phase ticks.\n' > "$WORK/refs/11-phase-4-verify/11.1-phase-4-verify.md"
  { printf '### The builder\n\n%s\nYou build one stage.\n%s\n\n' "$FENCE" "$FENCE"
    printf '### The mechanic\n\n%s\n%s.\n%s\n' "$FENCE" "$ADVISOR_LINE" "$FENCE"
  } > "$WORK/refs/05-working-references/5.5-the-phase-agents.md"
}

# The checks have to be able to fail: every planted breach above is named, and a look-alike
# id (15.7, 5.70) is never taken for a citation of 5.7.
test_planted_breaches_are_named() {
  plant_tree
  REFS=$WORK/refs
  assert_contains "a run point whose file never cites 5.7 is named" '8.1: never cites 5.7' "$(unwired)"
  assert_contains "a run point with no reference file is named" '99.9: no reference file' "$(unwired)"
  assert_contains "a pointer with no run-point row is named" '11.1: cites 5.7 with no run-point row' "$(unlisted)"
  assert_contains "a deciding prompt that lost the line is named" 'builder: no advisor line' "$(prompt_defects)"
  assert_contains "a silent prompt carrying the line is named" 'mechanic: carries an advisor line' "$(prompt_defects)"
  REFS=$REAL_REFS
}

test_the_law_file_states_the_rule
test_the_protocol_file_is_listed_and_model_blind
test_every_run_point_is_wired_both_ways
test_the_deciding_prompts_carry_the_line
test_the_cue_is_wired_at_the_prompt_boundary
test_the_ledger_records_it
test_planted_breaches_are_named
report
