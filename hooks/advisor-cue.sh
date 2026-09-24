#!/bin/bash
# engineering-rules advisor cue.
# Runs on UserPromptSubmit, which fires on every prompt and takes no matcher. The advisor rule
# (the law's 1.4, reference 5.7) binds every task, including the ones that never load the workflow,
# and a rule that only lives in a file nobody opened is a rule that does not bind. Plain text on
# stdout is context for this event, so the cue is one short block: what to consult, when, what
# its answer is worth, and what to do when the tool list holds no advisor. It judges nothing and
# refuses nothing; the tool list belongs to the session, not to a hook. Input that cannot be
# read, or another event, prints nothing and exits 0.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"

ADVISOR_REF="${ENGINEERING_RULES_HOME:-$(cd -P "$here/.." && pwd)}/references/05-working-references/5.7-the-advisor.md"

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = UserPromptSubmit ] || exit 0

printf 'engineering-rules advisor cue. When your tools include an advisor, call it before you settle an approach or a plan, rank the options you put to the user, act on a review or a root cause, change direction, do anything hard to undo, or call anything done. State the decision, its options and your evidence first, then call. What it returns is a report, never proof: the user, the anchor, the law and fresh evidence outrank it. No advisor in the tool list is not an error; decide with the same care, and never write a verdict for a call you did not make. Protocol: %s\n' "$ADVISOR_REF"
exit 0
