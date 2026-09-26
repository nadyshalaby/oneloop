#!/bin/bash
# oneloop loop reminder.
# Runs on UserPromptSubmit, which fires on every prompt and takes no matcher, and prints exactly
# one line into the turn: the loop's four standing rules (the law: one mode, the scope gate and
# its "go" pre-approval, proof before "done", the risk-zone yes). It judges nothing and refuses
# nothing. Input that cannot be read, or another event, prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = UserPromptSubmit ] || exit 0
printf '%s\n' 'one loop · wait for yes unless "go" · proof required · risk zones need my yes'
exit 0
