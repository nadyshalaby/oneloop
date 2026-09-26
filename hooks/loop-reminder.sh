#!/bin/bash
# oneloop loop reminder.
# Runs on UserPromptSubmit, which fires on every prompt and takes no matcher, and prints exactly
# one line into the turn: the loop's four standing rules (the law: one mode, auto-pilot where a
# guard points and Claude fixes, proof before "done", the two questions left: a clarification or
# a critical logic change). It judges nothing and refuses nothing. Input that cannot be read, or another event, prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = UserPromptSubmit ] || exit 0
printf '%s\n' 'one loop · auto-pilot: a guard points, you fix · proof required · ask only a clarification or a critical logic change'
exit 0
