#!/bin/bash
# Guard: at Phase 2 the planner writes the work-doc, and the whole law says so in one voice.
# The map row for the plan is a general-purpose agent (a Plan agent cannot write), the root
# cause of Phase 3b stays a read-only Plan agent, the planner prompt names the one path it may
# write and bans everything else, 7.1 keeps the read-back that replaced the session's
# transcription, and no file anywhere still tells the reader that a planner never writes.
# Run: bash tests/planner-writes.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
REF=$ROOT/skills/engineering-rules/references
SKILL=$ROOT/skills/engineering-rules/SKILL.md
DELEGATION=$REF/05-working-references/5.5-the-phase-agents-what-this-session-keeps.md
PLAN=$REF/07-phase-2-plan/7.1-phase-2-plan.md

TICK=$(printf '\140')

# row_needle <agent type>: the shape, type and model cells of a planner row of 1.8's map.
row_needle() { printf '| planner | %s%s%s | %sopus%s |' "$TICK" "$1" "$TICK" "$TICK" "$TICK"; }

# planner_prompt: the planner's prompt block of 5.5, from its heading to the fence that ends it.
planner_prompt() { sed -n '/^### The planner/,/^### The spec reviewer/p' "$DELEGATION"; }

# map_row <run point>: the row of 1.8's map whose run point matches, or nothing.
map_row() { grep -E "^\| Phase [0-9b.]+, .*$1" "$SKILL"; }

# stale_claims <dir>: every line under <dir> still saying a planner writes nothing. The
# changelog is excepted, because an entry there records what the law said on the day it was
# written; the scan reads the working tree, so an uncommitted stale claim counts too.
stale_claims() {
  git -C "$1" grep --no-index -n -F -e 'Never writes the work-doc' -e 'The session writes the work-doc' \
    -e 'and you write none of it' -e 'neither writes anything itself' -- \
    'skills/*' 'README.md' 'hooks/*' || true
}

test_the_plan_row_is_a_writer() {
  row=$(map_row 'the plan')
  assert_contains "1.8 sends the plan to a general-purpose agent" "$(row_needle general-purpose)" "$row"
  assert_contains "1.8 says that send holds one path" 'exactly one path, the work-doc' "$row"
}

test_the_root_cause_row_stays_read_only() {
  row=$(map_row 'the hypothesis chain')
  assert_contains "1.8 keeps the root cause on a read-only Plan agent" "$(row_needle Plan)" "$row"
}

test_the_prompt_names_the_one_path_and_bans_the_rest() {
  prompt=$(planner_prompt)
  assert_contains "the prompt says the planner writes the doc itself" 'you write that decision into the work-doc yourself' "$prompt"
  assert_contains "the prompt names the one writable path" 'docs/work/<YYYY-MM-DD>-<slug>.md' "$prompt"
  assert_contains "the prompt bans every other write" 'Write that one path and nothing else' "$prompt"
  assert_contains "the prompt keeps the root-cause send writing nothing" 'you hold no edit tool at all, and you write nothing' "$prompt"
  assert_contains "the prompt leaves the publish with the session" 'the publish is the session' "$prompt"
  assert_contains "the prompt makes the planner check its own file" 'Check your own file before you return' "$prompt"
  assert_contains "the self-check covers the plan against itself" 'The plan against itself' "$prompt"
  assert_contains "the self-check covers ledger and task state" 'Ledger and task state' "$prompt"
}

test_no_plan_gate_survives() {
  plan=$(cat "$PLAN")
  assert_missing "7.1 no longer stops for a sign-off" 'Shall I go ahead' "$plan"
  assert_contains "7.1 says the plan out loud instead" '## Step 5. Say what you are about to build' "$plan"
  assert_contains "7.1 states the stop is gone" 'no longer stops for a sign-off' "$plan"
  found=""
  for f in "$ROOT"/hooks/*work-doc*; do [ -e "$f" ] && found=$f; done
  assert_eq "no hook gates an edit against the work-doc" "" "$found"
  assert_missing "hooks.json wires no work-doc gate" 'work-doc-gate' "$(cat "$ROOT/hooks/hooks.json")"
}

test_the_read_back_survives() {
  plan=$(cat "$PLAN")
  assert_contains "7.1 keeps a read-back step" '## Step 2. Read what came back, against the repository' "$plan"
  assert_contains "7.1 checks the tree for a second path" 'git status --porcelain' "$plan"
  assert_contains "7.1 says why the read-back exists" 'the transcription that used to force you to read it is gone' "$plan"
  assert_contains "7.1 publishes after the read-back, before the gate" '## Step 3. Publish the page' "$plan"
}

test_no_file_still_says_the_planner_never_writes() {
  assert_eq "nothing outside the changelog says a planner writes nothing" "" "$(stale_claims "$ROOT")"
}

# The checks have to be able to fail: a map row moved back to a Plan agent, a prompt with the
# write permission cut out, a 7.1 with no read-back, and a stale claim left in a skill file.
test_planted_breaches_are_named() {
  printf '| Phase 2, the plan, its stages and their order (7.1) | planner | %sPlan%s | %sopus%s | because |\n' \
    "$TICK" "$TICK" "$TICK" "$TICK" > "$WORK/skill.md"
  SKILL=$WORK/skill.md
  assert_missing "a plan row back on a read-only Plan agent is named" "$(row_needle general-purpose)" "$(map_row 'the plan')"
  SKILL=$ROOT/skills/engineering-rules/SKILL.md

  printf '### The planner\n\nYou plan and you never write.\n\n### The spec reviewer\n' > "$WORK/5.5.md"
  DELEGATION=$WORK/5.5.md
  assert_missing "a prompt with no write permission is named" 'Write that one path and nothing else' "$(planner_prompt)"
  DELEGATION=$REF/05-working-references/5.5-the-phase-agents-what-this-session-keeps.md

  printf '# 7.1\n\n## Step 1. Send the planner\n\n## Step 2. The gate\n' > "$WORK/7.1.md"
  PLAN=$WORK/7.1.md
  assert_missing "a 7.1 with no read-back is named" '## Step 2. Read what came back' "$(cat "$PLAN")"
  PLAN=$REF/07-phase-2-plan/7.1-phase-2-plan.md

  mkdir -p "$WORK/skills"
  printf 'the planner: Never writes the work-doc, never asks.\n' > "$WORK/skills/x.md"
  assert_contains "a stale claim left in a skill file is named" 'skills/x.md:1:' "$(stale_claims "$WORK")"
}

test_the_plan_row_is_a_writer
test_the_root_cause_row_stays_read_only
test_the_prompt_names_the_one_path_and_bans_the_rest
test_the_read_back_survives
test_no_file_still_says_the_planner_never_writes
test_no_plan_gate_survives
test_planted_breaches_are_named
report
