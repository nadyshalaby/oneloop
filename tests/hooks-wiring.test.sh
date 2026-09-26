#!/bin/bash
# Guard: every hook hooks/hooks.json runs is a script that exists in hooks/, every command
# reaches it through the plugin root Claude Code expands (`${CLAUDE_PLUGIN_ROOT}/hooks/`), every
# hook script that reads Claude Code's event input is wired to an event, the fragment sets no
# status line (a plugin cannot; bin/setup-statusline.sh does), the one hook that reaches the
# Bash tool is the commit check (it asks, never blocks; git safety itself binds through the
# law), the prompt hook carries no matcher, because UserPromptSubmit takes none, and the loop's
# hooks sit where the law puts them (the law on every session start; the one-line reminder
# alone on every prompt; the risk-zone prompt, the scope check, the code rules and the
# code-rules warning on every edit; the code rules on every read; the risk-zone record after
# every edit that went through). Run: bash tests/hooks-wiring.test.sh
# HOOKS_JSON points the test at another fragment, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
HOOKS_JSON="${HOOKS_JSON:-$ROOT/hooks/hooks.json}"
PREFIX="bash \"\${CLAUDE_PLUGIN_ROOT}/hooks/"

# wired_commands <manifest>: every command string in it, one per line.
wired_commands() { jq -r '.hooks[][] | .hooks[].command' "$1"; }

# wired_scripts <manifest>: the script names those commands run, sorted, once each.
wired_scripts() { wired_commands "$1" | sed -E 's#.*/hooks/([^"]+)".*#\1#' | sort -u; }

# event_scripts: the hook scripts that read an event on stdin, sorted.
event_scripts() { grep -l 'read_hook_input ||' "$ROOT"/hooks/*.sh | sed 's#.*/##' | sort -u; }

# scripts_on <manifest> <event> <matcher>: the scripts the event runs under that exact matcher, in order.
scripts_on() { jq -r --arg e "$2" --arg m "$3" '.hooks[$e][] | select((.matcher // "") == $m) | .hooks[].command' "$1" | sed -E 's#.*/hooks/([^"]+)".*#\1#' | tr '\n' ' '; }

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

test_every_command_goes_through_the_plugin_root() {
  stray=$(wired_commands "$HOOKS_JSON" | grep -v -F "$PREFIX")
  assert_contains "every command runs bash on a script under the plugin root" "<none>" "${stray:-<none>}"
}

# A plugin's hooks fragment cannot set the status line, so a statusLine key here would be dead.
test_no_status_line_in_the_fragment() {
  assert_eq "the fragment sets no status line" false "$(jq 'has("statusLine")' "$HOOKS_JSON")"
  assert_eq "the fragment holds hooks and nothing else" "hooks" "$(jq -r 'keys | join(" ")' "$HOOKS_JSON")"
}

test_only_the_commit_check_reaches_bash() {
  assert_eq "the one matcher that reaches Bash is the literal Bash" "Bash" "$(bash_matchers "$HOOKS_JSON" | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "and it runs the commit check alone" "commit-check.sh " "$(scripts_on "$HOOKS_JSON" PreToolUse Bash)"
}

test_the_nine_events_are_wired() {
  events=$(jq -r '.hooks | keys[]' "$HOOKS_JSON" | sort | tr '\n' ' ')
  assert_eq "the nine events" "Notification PostToolUse PreToolUse SessionStart Stop StopFailure SubagentStart SubagentStop UserPromptSubmit " "$events"
}

# The loop's guards sit where the law says: the law on every session start, the one-line
# reminder alone on every prompt, the risk-zone prompt, the scope check, the code rules and
# the code-rules warning on every edit, the code rules on every read, and the risk-zone record
# after every edit that went through.
test_the_loop_hooks_sit_where_the_law_says() {
  assert_eq "every session start carries the law" "session-start.sh " "$(scripts_on "$HOOKS_JSON" SessionStart 'startup|resume|clear|compact|fork')"
  assert_eq "and nothing else starts a session" "session-start.sh" "$(jq -r '.hooks.SessionStart[].hooks[].command' "$HOOKS_JSON" | sed -E 's#.*/hooks/([^"]+)".*#\1#' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "the prompt hook is the one-line reminder and nothing else" "loop-reminder.sh " "$(scripts_on "$HOOKS_JSON" UserPromptSubmit '')"
  assert_eq "every edit runs the risk-zone prompt, the scope check, the code rules, then the code-rules warning" "risk-zone.sh scope-check.sh code-rules.sh edit-guard.sh " "$(scripts_on "$HOOKS_JSON" PreToolUse 'Edit|Write|MultiEdit|NotebookEdit')"
  assert_eq "every read runs the code rules" "code-rules.sh " "$(scripts_on "$HOOKS_JSON" PreToolUse Read)"
  assert_eq "every edit that went through is recorded by the risk-zone hook" "risk-zone.sh " "$(scripts_on "$HOOKS_JSON" PostToolUse 'Edit|Write|MultiEdit|NotebookEdit')"
  gone=$(wired_scripts "$HOOKS_JSON" | grep -E 'advisor|lane|plan-note|re-anchor' || true)
  assert_eq "no advisor, lane, plan-note or re-anchor hook is wired" "" "$gone"
}

# UserPromptSubmit takes no matcher and fires on every prompt, so a matcher written there is
# ignored by the runtime and misleads the next reader.
test_the_prompt_hook_carries_no_matcher() {
  stray=$(jq -r '.hooks.UserPromptSubmit[] | select(has("matcher")) | .matcher' "$HOOKS_JSON")
  assert_contains "the prompt hook carries no matcher" "<none>" "${stray:-<none>}"
}

# The checks have to be able to fail: a missing script, an unwired script, a command outside
# the plugin root, a status line, a second hook on Bash and a Bash regex on PostToolUse are all
# named.
test_planted_breaches_are_named() {
  jq '.hooks.Stop[0].hooks[0].command = "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/no-such-hook.sh\""' "$HOOKS_JSON" > "$WORK/planted.json"
  named=$(for script in $(wired_scripts "$WORK/planted.json"); do [ -f "$ROOT/hooks/$script" ] || printf '%s' "$script"; done)
  assert_contains "a planted missing script is named" "no-such-hook.sh" "$named"
  ghost=$(comm -23 <(printf 'ghost-hook.sh\n') <(wired_scripts "$HOOKS_JSON"))
  assert_contains "a planted unwired script is named" "ghost-hook.sh" "$ghost"
  jq '.hooks.Stop[0].hooks[0].command = "bash \"$HOME/.claude/somewhere/hooks/progress-notify.sh\""' "$HOOKS_JSON" > "$WORK/home.json"
  assert_contains "a command outside the plugin root is named" "somewhere" "$(wired_commands "$WORK/home.json" | grep -v -F "$PREFIX")"
  jq '.statusLine = {type: "command", command: "echo"}' "$HOOKS_JSON" > "$WORK/status.json"
  assert_eq "a planted status line is named" true "$(jq 'has("statusLine")' "$WORK/status.json")"
  jq '(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks) += [{type: "command", command: "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/edit-guard.sh\""}]' "$HOOKS_JSON" > "$WORK/bash.json"
  assert_eq "a planted second hook on Bash is named" "commit-check.sh edit-guard.sh " "$(scripts_on "$WORK/bash.json" PreToolUse Bash)"
  jq '.hooks.PostToolUse += [{matcher: "^Bash$", hooks: [{type: "command", command: "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/edit-guard.sh\""}]}]' "$HOOKS_JSON" > "$WORK/post-bash.json"
  assert_eq "a planted PostToolUse regex on Bash is named beside the one matcher" "Bash ^Bash$" "$(bash_matchers "$WORK/post-bash.json" | tr '\n' ' ' | sed 's/ $//')"
  jq '.hooks.UserPromptSubmit[0].hooks += [{type: "command", command: "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/advisor-cue.sh\""}]' "$HOOKS_JSON" > "$WORK/two-prompt.json"
  assert_eq "a second prompt hook is caught" "loop-reminder.sh advisor-cue.sh " "$(scripts_on "$WORK/two-prompt.json" UserPromptSubmit '')"
}

test_every_wired_script_exists
test_every_event_script_is_wired
test_every_command_goes_through_the_plugin_root
test_no_status_line_in_the_fragment
test_only_the_commit_check_reaches_bash
test_the_nine_events_are_wired
test_the_loop_hooks_sit_where_the_law_says
test_the_prompt_hook_carries_no_matcher
test_planted_breaches_are_named
report
