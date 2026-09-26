#!/bin/bash
# engineering-rules scope check.
# The law's Scope step, its scope ratchet and its checklist, judged by a machine before an
# edit inside a git repository: the file must be on the approved scope line, and the
# repository's TODO.md must hold an open task line. The approved scope line comes from the
# session transcript: the `scope: <files>` line that stood when the user last replied (their
# reply is the yes), or, when that reply says "go", the first scope line printed after it (the
# pre-approval). A scope line restated later waits for a new yes, even after "go". An edit
# before any approved scope line, to a file the line does not name (a path, or a folder it is
# under), or while TODO.md has no `- [ ]` or `- [~]` line, becomes a permission prompt
# (`permissionDecision: ask`) whose approval is the yes. Nothing to judge (another tool or
# event, no repository, a file outside it, TODO.md and TODO.archive.md themselves, no readable
# transcript, unreadable input): exit 0 with no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

# The jq program that reduces the transcript to the events that matter, in order: `H<tab>text`
# for a message the user typed (not a tool result, not a skill's injected text, not a
# compaction summary) and `S<tab>files` for a scope line in a reply Claude wrote.
read -r -d '' EVENTS <<'JQ'
def human: .message.content
  | if type == "string" then .
    elif type == "array" then (if any(.[]; .type == "tool_result") then null else ([.[] | select(.type == "text") | .text] | join(" ")) end)
    else null end;
if .type == "user" and (.isMeta // false) == false and (.isCompactSummary // false) == false then
  (human) as $t | if $t == null then empty else "H\t" + ($t | gsub("[\n\t]"; " ") | .[0:2000]) end
elif .type == "assistant" then
  [.message.content[]? | select(.type == "text") | .text] | join("\n") | split("\n")[]
  | select(test("^[^A-Za-z]*scope:")) | "S\t" + (sub("^[^A-Za-z]*scope:[[:space:]]*"; "") | gsub("[`*]"; ""))
else empty end
JQ

# events <transcript>: the H and S lines, oldest first.
events() { jq -r "$EVENTS" "$1" 2>/dev/null; }

# says_go <text>: the word "go" in the user's message, as the law reads it.
says_go() { printf '%s' "$1" | grep -qiE '(^|[^[:alnum:]_])go([^[:alnum:]_]|$)'; }

# approved_scope <transcript>: the files of the approved scope line, empty when none is.
approved_scope() {
  last_h=""; s_last=""; s_at_h=""; n_after=0; s_after1=""
  while IFS=$'\t' read -r kind text; do
    case "$kind" in
      H) last_h=$text; s_at_h=$s_last; n_after=0; s_after1="" ;;
      S) s_last=$text; n_after=$((n_after + 1)); [ "$n_after" -eq 1 ] && s_after1=$text ;;
    esac
  done <<EOF
$(events "$1")
EOF
  if says_go "$last_h" && [ "$n_after" -ge 1 ]; then printf '%s' "$s_after1"; else printf '%s' "$s_at_h"; fi
}

# in_scope <rel> <files> <prefixes>: the path is named by the scope line, exactly or by a
# folder it is under; an absolute entry under one of the prefixes (the repository's physical
# root, the session's cwd as it knows it) counts by its relative form.
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

# emit_ask <reason>: the PreToolUse decision, as the JSON Claude Code reads.
emit_ask() {
  jq -cn --arg r "engineering law (the loop): $1." \
    --arg c "engineering law (the loop): $1. The user is being asked to approve this edit; their approval is the yes. A rejection means: restate the scope or add the task line, then try again." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r,additionalContext:$c}}'
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
case "$(hook_field '.tool_name // empty')" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
transcript=$(hook_field '.transcript_path // empty')
parent=$(existing_parent "$path")
root=$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null) || exit 0
physical="$(cd "$parent" 2>/dev/null && pwd -P)/${path#"$parent"/}"
case "$physical" in "$root"/*) rel=${physical#"$root"/} ;; *) exit 0 ;; esac
case "$rel" in TODO.md|TODO.archive.md) exit 0 ;; esac
[ -n "$transcript" ] && [ -r "$transcript" ] || exit 0
project="${cwd##*/}"
reason=""; why=""
scope=$(approved_scope "$transcript")
if [ -z "$scope" ]; then
  reason="no approved scope line yet: print \`scope: <files>\` and the note, then wait for the yes"; why="no scope"
elif ! in_scope "$rel" "$scope" "$root $cwd"; then
  reason="$rel is outside the approved scope line (scope: $scope): restate the scope and wait for the yes"; why="outside scope"
fi
if ! grep -qE '^- \[( |~)\] ' "$root/TODO.md" 2>/dev/null; then
  reason="${reason:+$reason; }TODO.md has no open task line: add \`- [ ] <task>\` first"; why="${why:+$why + }no task line"
fi
[ -n "$reason" ] || exit 0
append_log "$project" "guard | scope | ask | $rel | $why"
emit_ask "$reason"
exit 0
