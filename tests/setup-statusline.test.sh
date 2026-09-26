#!/bin/bash
# Fixture tests for bin/setup-statusline.sh, run against fake config dirs only, never the real
# ~/.claude. The setup writes oneloop's status line when none is set, when the old
# engineering-rules one or the personal fallback script is there, or when it is already
# oneloop's (then it changes nothing); any other status line is left alone and printed unless
# --force; --check and --remove read and undo it; every write backs settings.json up first and
# keeps its other keys; a settings file that is not JSON is refused, a missing one is created.
# Run: bash tests/setup-statusline.test.sh
# SETUP_STATUSLINE_SH points the test at another copy, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SCRIPT="${SETUP_STATUSLINE_SH:-$ROOT/bin/setup-statusline.sh}"
CFG="$WORK/cfg"
export CLAUDE_CONFIG_DIR="$CFG"
SETTINGS="$CFG/settings.json"

# run [option]: the script's output and exit status, as one string.
run() { bash "$SCRIPT" "$@" 2>&1; printf '\nexit=%s' "$?"; }

# line: the status line command settings.json holds.
line() { jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null; }

# set_line <command>: settings.json with that status line command.
set_line() { jq --arg c "$1" '.statusLine = {type: "command", command: $c}' "$SETTINGS" > "$SETTINGS.n" && mv "$SETTINGS.n" "$SETTINGS"; }

test_unset_gets_oneloops_line() {
  mkdir -p "$CFG"
  printf '{"model": "opus"}\n' > "$SETTINGS"
  assert_contains "the setup exits 0" "exit=0" "$(run)"
  assert_contains "the command looks the installed plugin up on each render" 'installed_plugins.json' "$(line)"
  assert_contains "by its plugin id" '.plugins["oneloop@oneloop"][0].installPath' "$(line)"
  assert_contains "and runs its status line" "exec bash \"\$p/hooks/statusline.sh\"" "$(line)"
  assert_contains "falling back to the personal script" "exec sh \"\$c/statusline-command.sh\"" "$(line)"
  assert_eq "the other keys stay" opus "$(jq -r .model "$SETTINGS")"
  assert_eq "one backup was made first" 1 "$(find "$CFG/backups/oneloop" -name settings.json | wc -l | tr -d ' ')"
}

test_twice_changes_nothing() {
  before=$(cat "$SETTINGS")
  assert_contains "the second run says it is already there" "already oneloop's" "$(run)"
  assert_eq "and the file is byte for byte the same" "$before" "$(cat "$SETTINGS")"
  assert_contains "check passes" "exit=0" "$(run --check)"
}

test_another_status_line_is_left_alone_unless_forced() {
  set_line "echo mine"
  out=$(run --check)
  assert_contains "check fails on another status line" "exit=1" "$out"
  assert_contains "and prints it" "echo mine" "$out"
  out=$(run)
  assert_contains "the setup refuses" "exit=1" "$out"
  assert_contains "says why" "left alone (use --force" "$out"
  assert_eq "and changes nothing" "echo mine" "$(line)"
  assert_contains "force replaces it" "exit=0" "$(run --force)"
  assert_contains "with oneloop's" "oneloop@oneloop" "$(line)"
}

test_the_old_line_and_the_fallback_are_replaced() {
  set_line "f=\"\$HOME/.claude/engineering-rules/hooks/statusline.sh\"; [ -f \"\$f\" ] && exec bash \"\$f\"; echo"
  assert_contains "the old engineering-rules line is replaced" "exit=0" "$(run)"
  assert_contains "by oneloop's" "oneloop@oneloop" "$(line)"
  set_line "sh \"\$HOME/.claude/statusline-command.sh\""
  assert_contains "the personal fallback is replaced" "exit=0" "$(run)"
  assert_contains "by oneloop's, which keeps calling it" 'statusline-command.sh' "$(line)"
}

test_remove() {
  assert_contains "remove exits 0" "exit=0" "$(run --remove)"
  assert_eq "the status line is gone" "" "$(line)"
  assert_eq "the other keys stay" opus "$(jq -r .model "$SETTINGS")"
  assert_contains "a second remove has nothing to remove" "exit=1" "$(run --remove)"
  set_line "echo mine"
  assert_contains "remove leaves another status line alone" "nothing removed" "$(run --remove)"
  assert_eq "unchanged" "echo mine" "$(line)"
}

test_bad_and_missing_settings() {
  printf 'not json\n' > "$SETTINGS"
  assert_contains "a settings file that is not JSON is refused" "not a JSON object" "$(run)"
  rm -f "$SETTINGS"
  assert_contains "a missing settings file is created" "exit=0" "$(run)"
  assert_contains "with the status line" "oneloop@oneloop" "$(line)"
  assert_contains "an unknown option is refused" "unknown option" "$(run --bogus)"
}

test_unset_gets_oneloops_line
test_twice_changes_nothing
test_another_status_line_is_left_alone_unless_forced
test_the_old_line_and_the_fallback_are_replaced
test_remove
test_bad_and_missing_settings
report
