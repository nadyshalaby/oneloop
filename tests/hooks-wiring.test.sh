#!/bin/bash
# Guard: every hook settings/hooks.json runs is a script that exists in hooks/, every command
# reaches it through the fixed home, $HOME/.claude/engineering-rules/hooks/, which install.sh
# merges into ~/.claude/settings.json, every hook script that reads Claude Code's event input
# is wired to an event, the status line runs hooks/statusline.sh (it reads no event), no hook reaches the Bash tool (git safety binds
# through the law, and the shell is not judged at the tool boundary), and the prompt hook carries no matcher, because
# UserPromptSubmit takes none. Run: bash tests/hooks-wiring.test.sh
# HOOKS_JSON points the test at another fragment, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
HOOKS_JSON="${HOOKS_JSON:-$ROOT/settings/hooks.json}"
PREFIX="bash \"\$HOME/.claude/engineering-rules/hooks/"

# wired_commands <manifest>: every command string in it, one per line.
wired_commands() { jq -r '.hooks[][] | .hooks[].command' "$1"; }

# wired_scripts <manifest>: the script names those commands run, sorted, once each.
wired_scripts() { wired_commands "$1" | sed -E 's#.*/hooks/([^"]+)".*#\1#' | sort -u; }

# event_scripts: the hook scripts that read an event on stdin, sorted.
event_scripts() { grep -l 'read_hook_input ||' "$ROOT"/hooks/*.sh | sed 's#.*/##' | sort -u; }

# bash_matchers <manifest>: every PreToolUse or PostToolUse matcher that reaches the Bash tool,
# one per line, judged as Claude Code judges it: the tool name against the matcher as a regex
# (a plain substring over-flags, the safe direction for a pin), a bare `*` or an empty matcher
# reaching every tool, and a matcher that is not a regex named rather than passed.
bash_matchers() { jq -r '.hooks | ((.PreToolUse // [])[], (.PostToolUse // [])[]) | .matcher // "*" | . as $m | select($m == "*" or $m == "" or (try ("Bash" | test($m)) catch true))' "$1"; }

test_every_wired_script_exists() {
  for script in $(wired_scripts "$HOOKS_JSON"); do
    if [ -f "$ROOT/hooks/$script" ]; then present=present; else present=missing; fi
    assert_contains "wired script exists: $script" present "$present"
  done
}

test_every_event_script_is_wired() {
  missing=$(comm -23 <(event_scripts) <(wired_scripts "$HOOKS_JSON"))
  assert_contains "every event-reading script is wired" "<none>" "${missing:-<none>}"
}

test_every_command_goes_through_the_home() {
  stray=$(wired_commands "$HOOKS_JSON" | grep -v -F "$PREFIX")
  assert_contains "every command runs bash on a script in the fixed home" "<none>" "${stray:-<none>}"
}

# The status line is one settings key, not an event; it runs the script here and falls back.
test_the_status_line_runs_the_script() {
  line=$(jq -r '.statusLine.command // empty' "$HOOKS_JSON")
  assert_contains "the status line runs hooks/statusline.sh" "f=\"\$HOME/.claude/engineering-rules/hooks/statusline.sh\"" "$line"
  assert_contains "and falls back to the personal script" "exec sh \"\$HOME/.claude/statusline-command.sh\"" "$line"
}

test_no_hook_reaches_bash() {
  reaching=$(bash_matchers "$HOOKS_JSON")
  assert_contains "no hook reaches Bash" "<none>" "${reaching:-<none>}"
}

test_the_nine_events_are_wired() {
  events=$(jq -r '.hooks | keys[]' "$HOOKS_JSON" | sort | tr '\n' ' ')
  assert_contains "the nine events" "Notification PostToolUse PreToolUse SessionStart Stop StopFailure SubagentStart SubagentStop UserPromptSubmit " "$events"
}

# UserPromptSubmit takes no matcher and fires on every prompt, so a matcher written there is
# ignored by the runtime and misleads the next reader.
test_the_prompt_hook_carries_no_matcher() {
  stray=$(jq -r '.hooks.UserPromptSubmit[] | select(has("matcher")) | .matcher' "$HOOKS_JSON")
  assert_contains "the prompt hook carries no matcher" "<none>" "${stray:-<none>}"
}

# The checks have to be able to fail: a missing script, an unwired script and a hook on Bash
# are all named.
test_planted_breaches_are_named() {
  jq '.hooks.Stop[0].hooks[0].command = "bash \"$HOME/.claude/engineering-rules/hooks/no-such-hook.sh\""' "$HOOKS_JSON" > "$WORK/planted.json"
  named=$(for script in $(wired_scripts "$WORK/planted.json"); do [ -f "$ROOT/hooks/$script" ] || printf '%s' "$script"; done)
  assert_contains "a planted missing script is named" "no-such-hook.sh" "$named"
  ghost=$(comm -23 <(printf 'ghost-hook.sh\n') <(wired_scripts "$HOOKS_JSON"))
  assert_contains "a planted unwired script is named" "ghost-hook.sh" "$ghost"
  jq '.hooks.PreToolUse += [{matcher: "Bash", hooks: [{type: "command", command: "bash \"$HOME/.claude/engineering-rules/hooks/edit-guard.sh\""}]}]' "$HOOKS_JSON" > "$WORK/bash.json"
  assert_contains "a planted PreToolUse hook on Bash is named" "Bash" "$(bash_matchers "$WORK/bash.json")"
  jq '.hooks.PostToolUse += [{matcher: "^Bash$", hooks: [{type: "command", command: "bash \"$HOME/.claude/engineering-rules/hooks/file-cap.sh\""}]}]' "$HOOKS_JSON" > "$WORK/post-bash.json"
  assert_contains "a planted PostToolUse regex on Bash is named" "^Bash$" "$(bash_matchers "$WORK/post-bash.json")"
}

test_every_wired_script_exists
test_every_event_script_is_wired
test_every_command_goes_through_the_home
test_the_status_line_runs_the_script
test_no_hook_reaches_bash
test_the_nine_events_are_wired
test_the_prompt_hook_carries_no_matcher
test_planted_breaches_are_named
report
