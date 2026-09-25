#!/bin/bash
# engineering-rules re-anchor.
# Runs on SessionStart when a session resumes or its context was compacted. A summary of the law
# is not the law: after context loss the always-on law is read again from disk before anything
# else. This hook prints that instruction into the new context with the path to read, and names
# the code rules to read before writing code (they load with a code read, and the loss may have
# taken them). Plain text on stdout is context for a SessionStart hook. Any other start reason, or
# input that cannot be read, prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

ER_HOME="${ENGINEERING_RULES_HOME:-$(cd -P "$here/.." && pwd)}"
LAW="$ER_HOME/law/engineering-law.md"
RULES="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rules/engineering-code.md"

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = SessionStart ] || exit 0
reason=$(hook_field '.how_started // .source // empty')
case "$reason" in
  compact) happened="context was compacted" ;;
  resume) happened="session resumed" ;;
  *) exit 0 ;;
esac
cwd=$(hook_field '.cwd // empty')
printf 'engineering-rules re-anchor (%s). A summary of the law is not the law: if the always-on law is no longer verbatim in your context, read it from disk before the next step: %s\n' "$happened" "$LAW"
printf 'The code rules are part of it: before writing code, read them from disk unless they are verbatim in your context: %s\n' "$RULES"
printf 'A task that was in flight resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof.\n'
append_log "${cwd##*/}" "anchor | $reason"
exit 0
