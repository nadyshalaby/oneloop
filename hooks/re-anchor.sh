#!/bin/bash
# engineering-rules re-anchor.
# Runs on SessionStart when a session resumes or its context was compacted. A summary of the
# law is not the law (1.7, step 7): after context loss the always-on law is read again from
# disk before anything else. This hook prints that instruction into the new context with the
# path to read, names the code rules to read before writing code (they load with a code
# read, and the loss may have taken them), and adds the last phase-ledger position it finds
# in the transcript, so the ledger re-opens on the right item (5.1, pause and resume). Plain
# text on stdout is context for a SessionStart hook. Any other start reason, or input that
# cannot be read, prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"
# shellcheck source=./ledger-position.sh
. "$here/ledger-position.sh"

ER_HOME="${ENGINEERING_RULES_HOME:-$(cd -P "$here/.." && pwd)}"
LAW="$ER_HOME/law/engineering-law.md"
RULES="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/rules/engineering-code.md"
WORKFLOW="$ER_HOME/skills/engineering-rules/SKILL.md"
SCAN_BYTES=4000000

# The last ledger heading Claude printed in the transcript's final bytes; empty when there is
# none. Only Claude's reply text counts, never a heading quoted in a file or a tool result.
last_position() {
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  tail -c "$SCAN_BYTES" "$transcript" 2>/dev/null | claude_text | read_ledger_position
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = SessionStart ] || exit 0
reason=$(hook_field '.how_started // .source // empty')
case "$reason" in
  compact) happened="context was compacted" ;;
  resume) happened="session resumed" ;;
  *) exit 0 ;;
esac
transcript=$(hook_field '.transcript_path // empty')
cwd=$(hook_field '.cwd // empty')
position=$(last_position)
printf 'engineering-rules re-anchor (%s). A summary of the law is not the law: if the always-on law is no longer verbatim in your context, read it from disk before the next step (1.7, step 7): %s\n' "$happened" "$LAW"
printf 'The code rules are part of it: before writing code, read them from disk unless they are verbatim in your context: %s\n' "$RULES"
if [ -n "$position" ]; then
  printf 'Last phase-ledger position printed before the loss: %s. A phase-workflow task was in flight: re-read the workflow skill (%s), re-print the ledger with that item open and continue from it; nothing from before carries over as proof (5.1).\n' "$position" "$WORKFLOW"
else
  printf 'No phase-ledger position was found in the transcript. If a task was in flight, re-open its ledger from the last print you can see.\n'
fi
append_log "${cwd##*/}" "anchor | $reason | ${position:-no ledger position}"
exit 0
