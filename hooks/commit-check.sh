#!/bin/bash
# oneloop commit check.
# The law's checklist at the Commit step, judged by a machine: a `git commit` must carry the
# ticked task line, so the checklist, `docs/oneloop-todos/TODO.md`, must be staged, or named in
# the same command (an add that runs before the commit); a `TODO.md` anywhere else, the root
# included, is not the checklist and does not count. Otherwise the commit becomes a permission
# prompt (`permissionDecision: ask`) whose approval is the yes. The repository is the one
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

# emit_ask: the PreToolUse decision, as the JSON Claude Code reads.
emit_ask() {
  jq -cn --arg r "engineering law (the checklist): this commit leaves $TODO out. Tick the task's line in $TODO and stage it with the change; approve to commit without it." \
    --arg c "engineering law (the checklist): this commit leaves $TODO out. The user is being asked to approve it; their approval is the yes. A rejection means: tick the task's line in $TODO, stage it, and commit again." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r,additionalContext:$c}}'
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
append_log "${cwd##*/}" "guard | commit | ask | ${root##*/} | $TODO not in the commit"
emit_ask
exit 0
