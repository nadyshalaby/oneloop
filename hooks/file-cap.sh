#!/bin/bash
# engineering-rules file cap.
# Runs on PostToolUse for Edit, Write, MultiEdit and NotebookEdit. The law's 1.1 caps a file
# at 500 lines, and the cap binds every code file, tests included. After an edit lands, this
# hook counts the file. A file this change pushed over the cap gets one line of context naming
# the file and the count, so the split happens before the stage ends instead of at the review.
# A file that was already over the cap at the last commit is not this task's to fix (1.9): the
# line says so and asks for a follow-up instead of a split, once per session and file, so an
# old oversize never pulls the work off its goal and never costs the same line twice. It never
# blocks: a PostToolUse hook cannot, and a file over the cap is a finding, not a refusal. Prose
# and generated files are not code and are not counted. Unreadable input, or a file that is
# not there, is nothing to count: exit 0, no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"
# shellcheck source=./path-kind.sh
. "$here/path-kind.sh"

CAP=500

# lines_at_last_commit <path>: the file's line count at HEAD; empty when git holds no copy.
lines_at_last_commit() {
  dir=${1%/*}
  spec="HEAD:./${1##*/}"
  git -C "$dir" cat-file -e "$spec" 2>/dev/null || return 0
  git -C "$dir" show "$spec" 2>/dev/null | wc -l | tr -d ' '
}

# told_marker <path>: the file recording that this session was told about the path; empty
# when the input names no session, which means telling every time.
told_marker() {
  [ -n "$session" ] || return 0
  printf '%s/engineering-rules-cap-%s-%s' "${TMPDIR:-/tmp}" "$session" "$(printf '%s' "$1" | cksum | cut -d ' ' -f 1)"
}

# context <text>: the PostToolUse context Claude reads.
context() {
  jq -cn --arg c "$1" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PostToolUse ] || exit 0
case "$(hook_field '.tool_name // empty')" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] && [ -f "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
session=$(hook_field '.session_id // empty')
case "$(path_kind "$(relative_path "$path" "$cwd")")" in prose|generated) exit 0 ;; esac
lines=$(wc -l < "$path" | tr -d ' ')
[ "$lines" -gt "$CAP" ] || exit 0
before=$(lines_at_last_commit "$path")
if [ -n "$before" ] && [ "$before" -gt "$CAP" ]; then
  marker=$(told_marker "$path")
  [ -n "$marker" ] && [ -f "$marker" ] && exit 0
  [ -n "$marker" ] && : > "$marker"
  append_log "${cwd##*/}" "cap | file-lines | $path | $lines lines, $before at the last commit | follow-up"
  context "cap.file-lines $path: $lines lines, already over the $CAP-line cap at the last commit ($before). Not this task's to fix (1.9): write it down as a follow-up with its path and carry on; do not split it here."
  exit 0
fi
append_log "${cwd##*/}" "cap | file-lines | $path | $lines lines"
context "cap.file-lines $path: $lines lines. The law (1.1) caps a file at $CAP lines; split it by responsibility before this stage ends."
exit 0
