#!/bin/bash
# engineering-rules advisor cue.
# Runs on UserPromptSubmit, which fires on every prompt and takes no matcher. It prints one short
# line into the turn: the logic-first gate (1.4), since a session with only the law in context
# built a fully specified ask without it, and the moments the advisor is consulted (1.4, 5.7).
# The rest of the rule lives in the always-on law. It judges nothing and refuses nothing; the
# tool list belongs to the session, not to a hook. Input that cannot be read, or another event,
# prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = UserPromptSubmit ] || exit 0

cat <<'CUE'
engineering-rules advisor cue (law 1.4): logic first: explain a new task's logic (the explain skill) and get the user's yes before changing anything; a detailed or fixed ask, or "commit when done", is not a yes. Advisor (when listed) before a plan, ranked options, anything hard to undo, or done.
CUE
exit 0
