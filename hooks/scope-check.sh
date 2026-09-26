#!/bin/bash
# oneloop scope check.
# The law's Scope step, its scope ratchet and its checklist, read by a machine before an edit
# inside a git repository and handed to Claude as a POINTER to fix, never a prompt (14.0.0, the
# user's words: "nothing should block file edits, the model shall strictly apply the engineering
# rules/laws without asking for edit permissions or to correct it. it should be in auto-pilot
# mode with self-control"; "hooks shall point and claude fixes raised problems"). The scope is
# what the checklist says: the `scope:` of every `- [~]` line (a task in flight) of
# `docs/oneloop-todos/TODO.md`; a `- [ ]` line is parked and counts for nothing until it is
# flipped, and a `TODO.md` anywhere else, the root included, is not the checklist. An edit to a
# file no in-flight line covers (by name, or by a folder it is under) is pointed at with the
# fix: put it on the task line; an edit while no line is in flight is pointed at with the fix:
# add or flip a line (and, while a root TODO.md exists with no checklist, git mv it and its
# archive into docs/oneloop-todos/ first).
# 14.1.0, the Scope step's visible output too: Claude's thinking is invisible, and a dry run
# showed a model writing the scope line and the explanation there and believing it had printed
# them. So, once the scope passes, the hook reads the session transcript for this turn's reply
# text (the assistant text blocks after the last human message: one typed, a string or text
# blocks with no tool result, not injected, not a compaction summary; or one queued mid-turn)
# and points when that text carries no `scope:`, or no explanation (the problem with the effect
# or the risks), or, 14.2.0, no pseudocode (a fenced block, ```: a session printed numbered prose
# steps in its place, the user's screenshot of 2026-09-26): print what is missing as chat text,
# then go on. A turn with NO stored reply text
# is not judged: some sessions' transcripts keep none of the text sent along with a tool call
# (seen 2026-09-26 in the session that built this), so silence there is not proof of a missing
# line, and the one case this catches is text that was stored and lacks the line, the dry run's
# very case (a progress line printed, the rest thought). A transcript that is missing or
# unreadable skips the check the same way; of a big one only the last 2 MB
# are read, minus the cut first line, since the turn is at its end; a line the reader cannot
# make sense of (not JSON, or an odd shape) is skipped, never an abort. Nothing blocks the edit, in any permission mode;
# Claude fixes what was pointed at, at once. Nothing to judge (another tool or event, no
# repository, a file outside it, the checklist and its archive themselves, unreadable input):
# exit 0 with no output.
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
TRANSCRIPT_TAIL=2000000

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

# transcript_lines <transcript>: the whole file, or the last TRANSCRIPT_TAIL bytes of a big one
# without the line the cut may have broken.
transcript_lines() {
  size=$(wc -c < "$1" | tr -d ' ')
  if [ "$size" -le "$TRANSCRIPT_TAIL" ]; then cat "$1"; else tail -c "$TRANSCRIPT_TAIL" "$1" | sed '1d'; fi
}

# turn_text <transcript>: this turn's reply text, the assistant text blocks after the last human
# message, one block per line with its line breaks folded; empty when the turn has none.
turn_text() {
  transcript_lines "$1" | jq -rR '
    def human: .type == "user" and ((.isMeta // false) | not) and ((.isCompactSummary // false) | not)
      and (((.message.content | type) == "string")
        or (((.message.content | type) == "array") and any(.message.content[]?; .type == "text")
            and (any(.message.content[]?; .type == "tool_result") | not)));
    def queued: .type == "attachment" and .attachment.type == "queued_command" and (.attachment.humanTurn // false);
    (fromjson? // empty) | try (if human or queued then "H"
         elif .type == "assistant" then (.message.content[]? | select(.type == "text") | "T " + (.text | gsub("[\n\r]"; " ")))
         else empty end) catch empty' 2>/dev/null \
    | awk '/^H$/ { turn = ""; next } { turn = turn substr($0, 3) "\n" } END { printf "%s", turn }'
}

# missing_output <transcript>: sets text and why when this turn's stored reply text lacks the
# scope line, the explanation, or the explanation's pseudocode (a fenced block); leaves them
# empty when all are there, or when the transcript kept no reply text for the turn at all.
missing_output() {
  turn=$(turn_text "$1")
  [ -n "$turn" ] || return 0
  if ! printf '%s' "$turn" | grep -q 'scope:'; then
    text="no scope line is visible in this turn (your thinking is invisible). Fix it now: print the progress line, \`scope: <files>\`, the note of at most 3 lines and the explanation (the problem, the pseudocode as a fenced block, the effect, the risks) as chat text, then go on; nothing blocks this edit."
    why="scope line not visible"
  elif ! printf '%s' "$turn" | grep -qi 'problem' || ! printf '%s' "$turn" | grep -qiE 'effect|risk'; then
    text="the explanation is not visible in this turn (your thinking is invisible). Fix it now: print it as chat text, the problem, the pseudocode as a fenced block, the effect, the risks, then go on; nothing blocks this edit."
    why="explanation not visible"
  elif ! printf '%s' "$turn" | grep -q '```'; then
    text="the pseudocode is not visible in this turn: the explanation has no fenced block, and numbered steps in prose are not pseudocode. Fix it now: print the pseudocode as chat text, a fenced block in IF, FOR, RETURN and ←, then go on; nothing blocks this edit."
    why="pseudocode not visible"
  fi
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
text=""
why=""
if [ -z "$scope" ]; then
  moved=""
  [ -e "$root/TODO.md" ] && [ ! -e "$root/$TODO" ] && moved="git mv the root TODO.md and its archive into docs/oneloop-todos/ (their old home), then "
  text="no task in flight in $TODO. Fix it now: ${moved}add \`- [~] <task> (scope: <files>)\` to it, or flip its parked \`- [ ]\` line for this work, then go on; nothing blocks this edit."
  why="no task in flight"
elif ! in_scope "$rel" "$scope" "$root $cwd"; then
  text="$rel is outside the scope of the task in flight (scope: $scope). Fix it now: add $rel to that task line in $TODO and restate the scope in one line, then go on; nothing blocks this edit."
  why="outside scope"
else
  transcript=$(hook_field '.transcript_path // empty')
  [ -n "$transcript" ] && [ -r "$transcript" ] && missing_output "$transcript"
fi
[ -n "$text" ] || exit 0
append_log "$project" "guard | scope | fix | $rel | $why"
emit_pointer "$text"
exit 0
