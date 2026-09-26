#!/bin/bash
# oneloop scope check.
# The law's Scope step, its scope ratchet and its checklist, read by a machine before an edit
# inside a git repository and handed to Claude as a POINTER to fix, never a prompt (14.0.0, the
# user's words: "nothing should block file edits, the model shall strictly apply the engineering
# rules/laws without asking for edit permissions or to correct it. it should be in auto-pilot
# mode with self-control"; "hooks shall point and claude fixes raised problems"). The scope is
# what the checklist says: the `scope:` of every `- [~]`
# line (a task in flight) of `docs/oneloop-todos/TODO.md`; a `- [ ]` line is parked and counts
# for nothing until it is flipped, and a `TODO.md` anywhere else, the root included, is not the
# checklist. An edit to a file no in-flight line covers (by name, or by a folder it is under)
# is pointed at with the fix: put it on the task line; an edit while no line is in flight is
# pointed at with the fix: add or flip a line (and, while a root TODO.md exists with no
# checklist, git mv it and its archive into docs/oneloop-todos/ first). Nothing blocks the edit,
# in any permission mode; Claude fixes what was pointed at, at once. Nothing to judge (another
# tool or event, no repository, a file outside it, the checklist and its archive themselves,
# unreadable input): exit 0 with no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

TODO=docs/oneloop-todos/TODO.md
ARCHIVE=docs/oneloop-todos/TODO.archive.md

# in_flight_scope <checklist>: the files of every `- [~]` line, joined with `, `; empty when none.
in_flight_scope() {
  sed -n -E 's/^- \[~\] .*scope:[[:space:]]*//p' "$1" 2>/dev/null | tr -d '`*' \
    | sed -E 's/\)[[:space:]]*$//; s/[[:space:]]+$//' | grep . | paste -s -d , - | sed -E 's/,[[:space:]]*/, /g'
}

# in_scope <rel> <files> <prefixes>: the path is named by the scope, exactly or by a folder it
# is under; an absolute entry under one of the prefixes (the repository's physical root, the
# session's cwd as it knows it) counts by its relative form.
in_scope() {
  for entry in $(printf '%s' "$2" | tr ',' ' '); do
    for prefix in $(printf '%s' "$3" | tr ' ' '\n'); do entry=${entry#"$prefix"/}; done
    entry=${entry#./}
    case "$1" in "$entry"|"${entry%/}"/*) return 0 ;; esac
  done
  return 1
}

# existing_parent <path>: the nearest directory on the path that exists, for a file or a
# folder that is about to be created.
existing_parent() {
  probe=${1%/*}
  [ "$probe" = "$1" ] && probe=.
  while [ -n "$probe" ] && [ ! -d "$probe" ]; do probe=${probe%/*}; done
  printf '%s' "${probe:-/}"
}

# emit_pointer <text>: the context Claude reads beside the tool result; no decision, so nothing blocks.
emit_pointer() {
  jq -cn --arg c "engineering law (the loop): $1" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
case "$(hook_field '.tool_name // empty')" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
parent=$(existing_parent "$path")
root=$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null) || exit 0
physical="$(cd "$parent" 2>/dev/null && pwd -P)/${path#"$parent"/}"
case "$physical" in "$root"/*) rel=${physical#"$root"/} ;; *) exit 0 ;; esac
case "$rel" in "$TODO"|"$ARCHIVE") exit 0 ;; esac
project="${cwd##*/}"
scope=$(in_flight_scope "$root/$TODO")
if [ -z "$scope" ]; then
  moved=""
  [ -e "$root/TODO.md" ] && [ ! -e "$root/$TODO" ] && moved="git mv the root TODO.md and its archive into docs/oneloop-todos/ (their old home), then "
  text="no task in flight in $TODO. Fix it now: ${moved}add \`- [~] <task> (scope: <files>)\` to it, or flip its parked \`- [ ]\` line for this work, then go on; nothing blocks this edit."
  why="no task in flight"
elif ! in_scope "$rel" "$scope" "$root $cwd"; then
  text="$rel is outside the scope of the task in flight (scope: $scope). Fix it now: add $rel to that task line in $TODO and restate the scope in one line, then go on; nothing blocks this edit."
  why="outside scope"
else
  exit 0
fi
append_log "$project" "guard | scope | fix | $rel | $why"
emit_pointer "$text"
exit 0
