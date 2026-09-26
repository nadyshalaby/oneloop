#!/bin/bash
# oneloop commit check.
# The law's checklist at the Commit step, judged by a machine: a `git commit` must carry the
# ticked task line, so the checklist, `docs/oneloop-todos/TODO.md`, must be staged, or named in
# the same command (an add that runs before the commit); a `TODO.md` anywhere else, the root
# included, is not the checklist and does not count. Otherwise Claude is POINTED AT the fix
# beside the tool result, never prompted (14.0.0, the user's words: "nothing should block file
# edits … auto-pilot mode with self-control"; "hooks shall point and claude fixes raised
# problems"): nothing blocks the commit; Claude ticks the checklist, stages it and commits it
# right after, and the final reply says so. The repository is the one
# `git -C <dir>` names, else the session's cwd; a `-C` whose value is a shell variable cannot be
# read here and falls back to the cwd. Nothing to judge (another tool or event, a command with
# no commit in it, no repository, unreadable input): exit 0 with no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

# has_commit <command>: the command runs git with a commit subcommand somewhere in it.
has_commit() { printf '%s' "$1" | grep -qE '(^|[^[:alnum:]_])git([^[:alnum:]_].*)?[[:space:]]commit([^[:alnum:]_]|$)'; }

# repo_dir <command> <cwd>: the directory a literal `git -C <dir>` names, else the cwd.
repo_dir() {
  named=$(printf '%s' "$1" | sed -n -E 's/.*git[[:space:]]+-C[[:space:]]+"?([^" ]+)"?.*/\1/p' | head -n 1)
  case "$named" in ''|*'$'*) printf '%s' "$2" ;; *) printf '%s' "$named" ;; esac
}

TODO=docs/oneloop-todos/TODO.md

# emit_pointer: the context Claude reads beside the tool result; no decision, so nothing blocks.
emit_pointer() {
  jq -cn --arg c "engineering law (the checklist): this commit leaves $TODO out; nothing blocks it. Fix it now: tick the task's line in $TODO, stage it and commit it right after, and say so in the final reply." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
[ "$(hook_field '.tool_name // empty')" = Bash ] || exit 0
command=$(hook_field '.tool_input.command // empty')
has_commit "$command" || exit 0
case "$command" in *"$TODO"*) exit 0 ;; esac
cwd=$(hook_field '.cwd // empty')
root=$(git -C "$(repo_dir "$command" "$cwd")" rev-parse --show-toplevel 2>/dev/null) || exit 0
git -C "$root" diff --cached --name-only 2>/dev/null | grep -qx "$TODO" && exit 0
append_log "${cwd##*/}" "guard | commit | fix | ${root##*/} | $TODO not in the commit"
emit_pointer
exit 0
