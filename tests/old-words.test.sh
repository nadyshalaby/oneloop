#!/bin/bash
# Guard: the names of everything the law retired stay out of what the model and the user read:
# the old six-phase flow (cleanup releases 1 to 4 renamed every page, skill, agent, hook and
# folder away from it), since 10.0.0 the phases, lanes, scouts, sweep, helpers, gates, advisor
# and plan note the loop replaced, and since 11.0.0 the installer era (the engineering-rules
# name, install.sh, the CLAUDE.md block, the rules copy, the re-anchor hook) the plugin
# replaced, and since 14.0.0 the hooks that asked (a hook that warns or asks, the guard's
# prompt) the pointing guards replaced. It proves names, not rules: an old rule written in new
# words passes it. Allowed on
# purpose: the changelog and the tests (history and data), the two `Phase 01` examples of a bad
# section label (15.22, 15.24), the status line setup's handling of the old status line, and
# the README's one line on unwiring the old install.
# Run: bash tests/old-words.test.sh. OLD_WORDS_ROOT points the test at another tree, for a
# watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT="${OLD_WORDS_ROOT:-$(repo_root)}" || exit 1
OLD='Phase [0-9]|Sprint Backlog|Sprint Review|\bsprint\b|[Aa]cceptance [Cc]riteri|Daily Updates?\b|Evidence Ledger|Retrospective|wizard tool|question tool|stage end|stage-end|every stage\b|update log|update-log|full mode|quick mode|[Ss]ub-command|Approach section|phase agents?|phase-[0-9]|phase-discipline|fast lane|careful lane|lane\.sh|[Pp]hase ledger|Verify & Deploy|work-doc|plan note|the advisor\b|advisor tool|advisor cue|advisor-cue|er-builder|er-reviewer|build is the default|the workflow skill|/engineering-rules:workflow|logic gate|logic-first|ship gate|cleanup sweep|scout\.sh|sweep\.sh|Implement step|Plan step|Done-when|Done when|engineering-rules|engineering_rules|ENGINEERING_RULES|install\.sh|claude-md-block|re-anchor\.sh|~/\.claude/rules|warns or asks|guard.s prompt|edit and asks|weighed at the prompt|the prompt weighs|hooks ask\b'
TICK=$(printf '\140')
ALLOWED="${TICK}Phase 01${TICK}|^bin/setup-statusline\\.sh:[0-9]+:.*engineering-rules|^README\\.md:[0-9]+:.*install\\.sh --uninstall"
READ="references skills agents law README.md CLAUDE.md hooks settings bin .claude-plugin"

# old_hits <root>: every line of what is read that names an old-flow word, the allowed ones
# left out; hooks/tests/ is test data, so it is not read here.
old_hits() {
  (builtin cd "$1" && for p in $READ; do [ -e "$p" ] && grep -rnE --exclude-dir=tests "$OLD" "$p"; done) | grep -vE "$ALLOWED"
}

# old_paths <root>: every folder or file still named for the old flow, for what 10.0.0 removed
# (the workflow skill's folder, the scripts folder, the advisor, the ledger, the lanes, the
# scouts and the sweep) or for the installer era 11.0.0 replaced (install.sh and its test, the
# CLAUDE.md block, the re-anchor hook).
old_paths() {
  (builtin cd "$1" && { [ ! -e scripts ] || printf 'scripts\n'; [ ! -e install.sh ] || printf 'install.sh\n'; find references skills agents tests hooks settings \( -name '*phase-[0-9]*' -o -name '*phase-discipline*' -o -name '*phase-agents*' -o -name '*finish*' -o -name '*update-log*' -o -name '*shaping*' -o -name '*sub-command*' -o -name 'workflow' -o -name '*advisor*' -o -name '*ledger*' -o -name 'perf-scout*' -o -name 'lane.sh' -o -name 'sweep.sh' -o -name 'install.test.sh' -o -name 'claude-md-block*' -o -name 're-anchor*' \) -print 2>/dev/null; })
}

test_no_old_word_is_read() {
  hits=$(old_hits "$ROOT")
  assert_eq "no old-flow word in what is read" "<none>" "${hits:-<none>}"
}

test_no_old_name_is_left() {
  paths=$(old_paths "$ROOT")
  assert_eq "no folder or file named for the old flow" "<none>" "${paths:-<none>}"
}

# The checks can fail: an old word, an old folder name, an old word in a hook and the names
# 10.0.0 removed (a lane, a helper, a gate, the sweep; the workflow folder, the scripts folder,
# an advisor hook) and a hook that asks (14.0.0) each come back and are named; an allowed line
# stays quiet.
test_planted_names_are_caught() {
  mkdir -p "$WORK/tree/references/13-phase-6-finish" "$WORK/tree/hooks" "$WORK/tree/skills/workflow" "$WORK/tree/scripts"
  printf 'Read it at Phase 4.\n' > "$WORK/tree/references/13-phase-6-finish/x.md"
  printf 'the two %sPhase 01%s examples of a bad label\n' "$TICK" "$TICK" > "$WORK/tree/references/y.md"
  printf '# ask through the wizard tool\n' > "$WORK/tree/hooks/z.sh"
  printf 'The fast lane skips the ship gate; er-reviewer runs the cleanup sweep.\n' > "$WORK/tree/references/lanes.md"
  printf 'Clone it to ~/.claude/engineering-rules and run install.sh.\n' > "$WORK/tree/references/installer.md"
  printf '%s\n' "A hook warns or asks, and a name is weighed at the guard's prompt." > "$WORK/tree/references/asks.md"
  : > "$WORK/tree/hooks/advisor-cue.sh"
  : > "$WORK/tree/hooks/re-anchor.sh"
  : > "$WORK/tree/install.sh"
  out=$(old_hits "$WORK/tree")
  assert_contains "an old word is named" "references/13-phase-6-finish/x.md:1:Read it at Phase 4." "$out"
  assert_contains "an old word in a hook is named" "hooks/z.sh:1:# ask through the wizard tool" "$out"
  assert_contains "a name 10.0.0 removed is named" "references/lanes.md:1:The fast lane" "$out"
  assert_contains "the installer era is named" "references/installer.md:1:Clone it to" "$out"
  assert_contains "a hook that asks, which 14.0.0 retired, is named" "references/asks.md:1:A hook warns or asks" "$out"
  assert_missing "an allowed line stays quiet" "y.md" "$out"
  paths=$(old_paths "$WORK/tree")
  assert_contains "an old folder name is named" "references/13-phase-6-finish" "$paths"
  assert_contains "a workflow folder is named" "skills/workflow" "$paths"
  assert_contains "a scripts folder is named" "scripts" "$paths"
  assert_contains "an advisor hook is named" "hooks/advisor-cue.sh" "$paths"
  assert_contains "a re-anchor hook is named" "hooks/re-anchor.sh" "$paths"
  assert_contains "an installer is named" "install.sh" "$paths"
}

test_no_old_word_is_read
test_no_old_name_is_left
test_planted_names_are_caught
report
