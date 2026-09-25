#!/bin/bash
# Guard: the old six-phase flow's names stay out of everything the model and the user read.
# Cleanup releases 1 to 4 moved every page, skill, agent, hook and script to the workflow's own
# names (Plan, Implement, Verify & Deploy and the review; the work-doc's Done when, Log,
# Evidence and Follow-ups; AskUserQuestion; a command) and renamed the folders and files named
# for the old phases. It proves names, not rules: an old rule written in new words passes it.
# Allowed on purpose: the changelog and the tests (history and data), 16.13's older labels (so a
# work-doc from before the lite workflow can still be read) and the two `Phase 01` examples of a
# bad section label (15.22, 15.24). Run: bash tests/old-words.test.sh. OLD_WORDS_ROOT points the
# test at another tree, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT="${OLD_WORDS_ROOT:-$(repo_root)}" || exit 1
OLD='Phase [0-9]|Sprint Backlog|Sprint Review|\bsprint\b|[Aa]cceptance [Cc]riteri|Daily Updates?\b|Evidence Ledger|Retrospective|wizard tool|question tool|stage end|stage-end|every stage\b|update log|update-log|full mode|quick mode|[Ss]ub-command|Approach section|phase agents?|phase-[0-9]|phase-discipline'
ALLOWED="older labels|OLDER LABELS|\`Phase 01\`"
READ="references skills agents law README.md install.sh hooks settings scripts"

# old_hits <root>: every line of what is read that names an old-flow word, the allowed ones
# left out; hooks/tests/ is test data, so it is not read here.
old_hits() {
  (builtin cd "$1" && for p in $READ; do [ -e "$p" ] && grep -rnE --exclude-dir=tests "$OLD" "$p"; done) | grep -vE "$ALLOWED"
}

# old_paths <root>: every folder or file still named for the old flow.
old_paths() {
  (builtin cd "$1" && find references skills agents tests hooks scripts \( -name '*phase-[0-9]*' -o -name '*phase-discipline*' -o -name '*phase-agents*' -o -name '*finish*' -o -name '*update-log*' -o -name '*shaping*' -o -name '*sub-command*' \) -print 2>/dev/null)
}

test_no_old_word_is_read() {
  hits=$(old_hits "$ROOT")
  assert_eq "no old-flow word in what is read" "<none>" "${hits:-<none>}"
}

test_no_old_name_is_left() {
  paths=$(old_paths "$ROOT")
  assert_eq "no folder or file named for the old flow" "<none>" "${paths:-<none>}"
}

# The checks can fail: an old word, an old folder name and an old word in a hook each come back
# and are named; an allowed line stays quiet.
test_planted_names_are_caught() {
  mkdir -p "$WORK/tree/references/13-phase-6-finish" "$WORK/tree/hooks"
  printf 'Read it at Phase 4.\n' > "$WORK/tree/references/13-phase-6-finish/x.md"
  printf 'plus the older labels: Sprint Backlog, Daily Updates\n' > "$WORK/tree/references/y.md"
  printf '# ask through the wizard tool\n' > "$WORK/tree/hooks/z.sh"
  out=$(old_hits "$WORK/tree")
  assert_contains "an old word is named" "references/13-phase-6-finish/x.md:1:Read it at Phase 4." "$out"
  assert_contains "an old word in a hook is named" "hooks/z.sh:1:# ask through the wizard tool" "$out"
  assert_missing "an allowed line stays quiet" "y.md" "$out"
  assert_contains "an old folder name is named" "references/13-phase-6-finish" "$(old_paths "$WORK/tree")"
}

test_no_old_word_is_read
test_no_old_name_is_left
test_planted_names_are_caught
report
