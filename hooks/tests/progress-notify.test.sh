#!/bin/bash
# Fixture tests for progress-notify.sh. Run: bash hooks/tests/progress-notify.test.sh
# osascript is shimmed on PATH so nothing pops and nothing runs; the shim records its argv so
# the test can prove the title and the body travel as arguments and never as AppleScript. Every
# turn end notifies (10.0.0: in the loop each one is a wait for the user, the scope line, a
# question or the final reply), with the reply's first prose line as the body.
# PROGRESS_NOTIFY_SH points the test at another copy of the script, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${PROGRESS_NOTIFY_SH:-$here/../progress-notify.sh}"
mkdir -p "$WORK/bin" "$WORK/config"
cat > "$WORK/bin/osascript" <<'SHIM'
#!/bin/bash
printf '%s\n' "$@" >> "$OSASCRIPT_ARGV"
[ -z "${OSASCRIPT_FAIL:-}" ]
SHIM
chmod +x "$WORK/bin/osascript"
export PATH="$WORK/bin:$PATH" CLAUDE_CONFIG_DIR="$WORK/config" OSASCRIPT_ARGV="$WORK/osascript.argv"
LOG="$WORK/config/progress.log"
ARGV="$OSASCRIPT_ARGV"
SOURCE_LINE='display notification (item 1 of argv) with title (item 2 of argv)'
# One notification is one osascript call of eight arguments: -e, on run argv, -e, the source
# line, -e, end run, the body, the title.
ARGV_PER_CALL=8

run_hook() {
  printf '%s' "$1" | bash "$SCRIPT"
}

read_log_line() {
  sed -n "${1}p" "$LOG" | cut -d '|' -f 2-
}

count_log_lines() {
  if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else printf '0'; fi
}

count_argv_lines() {
  if [ -f "$ARGV" ]; then wc -l < "$ARGV" | tr -d ' '; else printf '0'; fi
}

test_stop_notifies_with_the_first_prose_line() {
  run_hook '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"## Done\n\n- [x] lint\n\nTwo files changed; lint, typecheck and 87 tests pass."}'
  assert_eq "stop logs the first prose line, headings and checklist rows skipped" " proj | stop | Two files changed; lint, typecheck and 87 tests pass." "$(read_log_line 1)"
  assert_eq "stop notifies through argv, body then title" "$(printf '%s\n' "$SOURCE_LINE" 'Two files changed; lint, typecheck and 87 tests pass.' 'Claude · proj')" "$(sed -n '4p;7p;8p' "$ARGV")"
}

test_every_turn_end_notifies() {
  before=$(count_argv_lines)
  run_hook '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"scope: src/a.ts, src/b.ts"}'
  assert_eq "a scope line is logged" " proj | stop | scope: src/a.ts, src/b.ts" "$(read_log_line 2)"
  assert_eq "and notified: every turn end is a wait for the user" "$((before + ARGV_PER_CALL))" "$(count_argv_lines)"
  assert_eq "with the line as the body" "scope: src/a.ts, src/b.ts" "$(tail -n 2 "$ARGV" | head -n 1)"
}

test_notification_event() {
  run_hook '{"hook_event_name":"Notification","cwd":"/tmp/proj","notification_type":"permission_prompt","message":"Claude needs your permission to run git push"}'
  assert_eq "notification logs a waiting line" " proj | waiting | permission_prompt | Claude needs your permission to run git push" "$(read_log_line 3)"
  assert_eq "notification title names the project" "Claude needs you · proj" "$(tail -n 1 "$ARGV")"
}

test_quoted_directory_name() {
  run_hook '{"hook_event_name":"Notification","cwd":"/tmp/x\" & (do shell script \"id\") & \"","notification_type":"permission_prompt","message":"Claude needs permission"}'
  assert_eq "a quote in the directory name stays inside one argument" 'Claude needs you · x" & (do shell script "id") & "' "$(tail -n 1 "$ARGV")"
  assert_eq "no AppleScript source ever carries the directory name" "0" "$(grep -c 'display notification .*do shell script' "$ARGV")"
}

test_quoted_reply() {
  run_hook '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"Said \"done\" and \\ moved on."}'
  assert_eq "a quote and a backslash in the reply reach the body intact" 'Said "done" and \ moved on.' "$(tail -n 2 "$ARGV" | head -n 1)"
}

test_bad_input() {
  before=$(count_log_lines)
  err=$(printf 'not json at all' | bash "$SCRIPT" 2>&1); status=$?
  assert_eq "malformed stdin exits 0 with nothing on stderr" "0|" "$status|$err"
  printf '' | bash "$SCRIPT"; assert_eq "empty stdin exits 0" "0" "$?"
  run_hook '{"hook_event_name":"PreToolUse","cwd":"/tmp/proj"}'; assert_eq "an unhandled event exits 0" "0" "$?"
  assert_eq "none of them wrote a log line" "$before" "$(count_log_lines)"
}

test_jq_missing() {
  before=$(count_log_lines)
  printf '%s' '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"x"}' | env PATH="$WORK/bin" /bin/bash "$SCRIPT"
  assert_eq "jq missing: exit 0" "0" "$?"
  assert_eq "jq missing: no log line" "$before" "$(count_log_lines)"
}

test_notifier_failure() {
  printf '%s' '{"hook_event_name":"Notification","cwd":"/tmp/proj","notification_type":"idle_prompt","message":"waiting"}' | OSASCRIPT_FAIL=1 bash "$SCRIPT"
  assert_eq "a failing notifier is recorded on the waiting line" " proj | waiting | idle_prompt | waiting | notify-failed" "$(tail -n 1 "$LOG" | cut -d '|' -f 2-)"
  printf '%s' '{"hook_event_name":"Stop","cwd":"/tmp/proj","last_assistant_message":"final reply"}' | OSASCRIPT_FAIL=1 bash "$SCRIPT"
  assert_eq "and on the stop line" " proj | stop | final reply | notify-failed" "$(tail -n 1 "$LOG" | cut -d '|' -f 2-)"
}

test_stop_failure() {
  run_hook '{"hook_event_name":"StopFailure","cwd":"/tmp/proj","error_type":"rate_limit","error_message":"Rate limit reached, retry in 30s"}'
  assert_eq "a stop failure logs an error line" " proj | error | rate_limit | Rate limit reached, retry in 30s" "$(tail -n 1 "$LOG" | cut -d '|' -f 2-)"
  assert_eq "and notifies with the error type in the body" "$(printf '%s\n' 'rate_limit: Rate limit reached, retry in 30s' 'Claude stopped on an error · proj')" "$(tail -n 2 "$ARGV")"
}

test_subagent_lines() {
  run_hook '{"hook_event_name":"SubagentStart","cwd":"/tmp/proj","agent_type":"er-reader","task_description":"Search the tree for every caller of loadUser"}'
  assert_eq "a helper send logs its shape and brief" " proj | helper | start | er-reader | Search the tree for every caller of loadUser" "$(tail -n 1 "$LOG" | cut -d '|' -f 2-)"
  before=$(count_argv_lines)
  run_hook '{"hook_event_name":"SubagentStop","cwd":"/tmp/proj","agent_type":"er-reader","last_assistant_message":"## Report\n\nTwo callers, both in src/users/."}'
  assert_eq "a helper return logs its first prose line" " proj | helper | stop | er-reader | Two callers, both in src/users/." "$(tail -n 1 "$LOG" | cut -d '|' -f 2-)"
  assert_eq "helper lines raise no desktop notification" "$before" "$(count_argv_lines)"
}

test_stop_notifies_with_the_first_prose_line
test_every_turn_end_notifies
test_notification_event
test_quoted_directory_name
test_quoted_reply
test_bad_input
test_jq_missing
test_notifier_failure
test_stop_failure
test_subagent_lines
report
