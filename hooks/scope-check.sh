#!/bin/bash
# oneloop scope check.
# The law's Scope step, its scope ratchet and its checklist, judged by a machine before an
# edit inside a git repository: the file must be on the approved scope, and the repository's
# checklist, `docs/oneloop-todos/TODO.md`, must hold an open task line. The scope comes from
# the checklist itself: at Scope, Claude adds `- [ ] <task> (scope: <files>)` to it, and that
# edit is a tool call the session transcript always keeps (Claude's chat text is not always
# kept, so it never counts here; a line added to a `TODO.md` anywhere else, the root included,
# is not the checklist and counts for nothing). The
# approved scope is the scope of the last such line added before the user last replied (their
# reply is the yes, whether typed, picked in a pick-list, which Claude Code stores as the
# AskUserQuestion tool's result, or sent while Claude was working, which it stores as a queued
# command), or, when that reply says "go", of the first one added after it (the pre-approval).
# A pick-list option whose description carries `scope: <files>` proposes that scope the moment
# the user picks it, so the pick is its yes (`/oneloop:start` lists open task lines that way).
# A line added later waits for a new yes, even after "go"; a line turning `[~]` or `[x]` adds
# nothing. An edit before any approved scope, to a file the scope does not name (a path, or a
# folder it is under), or while the checklist has no `- [ ]` or `- [~]` line, becomes a
# permission prompt (`permissionDecision: ask`) whose approval is the yes; with no checklist
# but a root TODO.md, the reason also says to move that one and its archive there with git mv.
# Nothing to judge (another tool or event, no repository, a file outside it, the checklist and
# its archive themselves, no readable transcript, unreadable input): exit 0 with no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

# The jq program that reduces the transcript to the events that matter, in order: `H<tab>text`
# for a message from the user (typed while Claude was idle: a user line that is not a tool
# result, an injected text or a compaction summary; picked: the result of an AskUserQuestion
# call Claude made; typed while Claude worked: a queued_command attachment with a human turn)
# and `S<tab>files` for a `- [ ] ... scope:` line an Edit, Write or MultiEdit adds to the
# checklist (a line its old text already held is not added; of several added at once, the
# last, since a task line is appended to its group), and for the `scope: <files>` an
# AskUserQuestion option's description carries (to the end of its line, or the first `. ` or
# `; `) when the answer picked that option (Claude Code stores a pick as `"<question>"="<label>"`),
# placed just before that answer's H. One pass, keeping the questions of the pick-lists asked
# so far, by the call's id.
TODO=docs/oneloop-todos/TODO.md
ARCHIVE=docs/oneloop-todos/TODO.archive.md
read -r -d '' EVENTS <<'JQ'
def text_of: if type == "string" then . elif type == "array" then ([.[]? | .text? // ""] | join(" ")) else "" end;
def typed: .message.content
  | if type == "string" then .
    elif type == "array" then (if any(.[]; .type == "tool_result") then null else ([.[] | select(.type == "text") | .text] | join(" ")) end)
    else null end;
def asked: [.message.content[]? | select(.type == "tool_use" and .name == "AskUserQuestion") | {key: .id, value: (.input.questions // [])}] | from_entries;
def answered($asks): [.message.content[]? | select(.type == "tool_result") | (.tool_use_id // "") as $i | select($asks | has($i)) | .content | text_of] | join(" ");
def option_files: sub("^.*scope:[[:space:]]*"; "") | split("\n")[0] | sub("(\\. |; ).*$"; "") | gsub("[`*]"; "") | sub("[.;[:space:]]+$"; "");
def picked($asks): [.message.content[]? | select(.type == "tool_result") | (.tool_use_id // "") as $i | select($asks | has($i)) | (.content | text_of) as $a
  | $asks[$i][]? | .question as $q | .options[]? | . as $o | select(($a | contains("\"" + $q + "\"=\"" + ($o.label // "") + "\"")) and (($o.description // "") | test("scope:"))) | $o.description]
  | if length > 0 then ["S\t" + (.[-1] | option_files)] else [] end;
def todo_edit: select(.type == "tool_use" and (.name == "Edit" or .name == "Write" or .name == "MultiEdit") and ((.input.file_path // "") | test("(^|/)docs/oneloop-todos/TODO\\.md$")));
def new_text: [.input.content // empty, .input.new_string // empty, (.input.edits[]? | .new_string // empty)] | join("\n");
def old_text: [.input.old_string // empty, (.input.edits[]? | .old_string // empty)] | join("\n");
def files: sub("^.*scope:[[:space:]]*"; "") | gsub("[`*]"; "") | sub("\\)[[:space:]]*$"; "") | sub("[[:space:]]+$"; "");
def proposals: .message.content[]? | todo_edit | (old_text | split("\n")) as $old
  | [new_text | split("\n")[] | select(test("^- \\[ \\] .*scope:")) | select(. as $line | any($old[]; . == $line) | not)]
  | select(length > 0) | .[-1] | "S\t" + files;
def h: "H\t" + (gsub("[\n\t]"; " ") | .[0:2000]);
foreach inputs as $l ({asks: {}, out: []};
  .out = []
  | if $l.type == "user" and ($l.isMeta // false) == false and ($l.isCompactSummary // false) == false then
      .asks as $asks | ($l | typed) as $t | ($l | answered($asks)) as $a
      | if $t != null then .out = [$t | h] elif $a != "" then .out = ($l | picked($asks)) + [$a | h] else . end
    elif $l.type == "attachment" and $l.attachment.type == "queued_command" and $l.attachment.humanTurn == true then
      ($l.attachment.prompt // "") as $q | if $q != "" then .out = [$q | h] else . end
    elif $l.type == "assistant" then .asks += ($l | asked) | .out = [$l | proposals]
    else . end;
  .out[])
JQ

# events <transcript>: the H and S lines, oldest first.
events() { jq -n -r "$EVENTS" "$1" 2>/dev/null; }

# says_go <text>: the word "go" in the user's message, as the law reads it.
says_go() { printf '%s' "$1" | grep -qiE '(^|[^[:alnum:]_])go([^[:alnum:]_]|$)'; }

# approved_scope <transcript>: the files of the approved scope, empty when none is.
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

# emit_ask <reason>: the PreToolUse decision, as the JSON Claude Code reads.
emit_ask() {
  jq -cn --arg r "engineering law (the loop): $1." \
    --arg c "engineering law (the loop): $1. The user is being asked to approve this edit; their approval is the yes. A rejection means: restate the scope on the task line in $TODO or add the task line, then try again." \
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
case "$rel" in "$TODO"|"$ARCHIVE") exit 0 ;; esac
[ -n "$transcript" ] && [ -r "$transcript" ] || exit 0
project="${cwd##*/}"
reason=""; why=""
scope=$(approved_scope "$transcript")
if [ -z "$scope" ]; then
  reason="no approved scope yet: add \`- [ ] <task> (scope: <files>)\` to $TODO, print the scope line and the note, then wait for the yes"; why="no scope"
elif ! in_scope "$rel" "$scope" "$root $cwd"; then
  reason="$rel is outside the approved scope (scope: $scope): restate the scope on the task line in $TODO and wait for the yes"; why="outside scope"
fi
if ! grep -qE '^- \[( |~)\] ' "$root/$TODO" 2>/dev/null; then
  moved=""
  [ -e "$root/TODO.md" ] && [ ! -e "$root/$TODO" ] && moved=" (the root TODO.md is the old home: git mv it and TODO.archive.md into docs/oneloop-todos/ first)"
  reason="${reason:+$reason; }$TODO has no open task line: add \`- [ ] <task> (scope: <files>)\` first$moved"; why="${why:+$why + }no task line"
fi
[ -n "$reason" ] || exit 0
append_log "$project" "guard | scope | ask | $rel | $why"
emit_ask "$reason"
exit 0
