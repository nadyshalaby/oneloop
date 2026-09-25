#!/bin/bash
# engineering-rules advisor cue.
# Runs on UserPromptSubmit, which fires on every prompt and takes no matcher. It prints one short
# line into the turn: the logic-first gate (1.4), since a session with only the law in context
# built a fully specified ask without it, stressed at the user's word (9.15.0: a hard gate in
# plain chat and the workflow alike, so the user stays on top of every piece of logic built,
# still a reminder, never a block), and the moments the advisor is consulted (1.4, 5.7).
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
engineering-rules advisor cue (law 1.4): LOGIC FIRST is a hard gate, in plain chat and the workflow alike: before building logic the user hasn't seen (a new task, approach or plan), explain it (the explain skill) and get their yes through AskUserQuestion; no edit before it. They must stay on top of all logic built. A detailed or fixed ask, or "commit when done", is not a yes; approved logic carried on, or a trivial edit, needs none. Advisor (when listed) before a plan, ranked options, anything hard to undo, or done.
CUE
exit 0
