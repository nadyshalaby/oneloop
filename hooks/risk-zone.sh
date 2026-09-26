#!/bin/bash
# oneloop risk-zone guard.
# The law's Guards: the FIRST edit in a session to a file whose path matches the risk regex
# (login, payments, migrations, env files, infra, deploy settings, secrets ...) is POINTED AT,
# never prompted (14.0.0, the user's words: "nothing should block file edits … auto-pilot mode
# with self-control"). On PreToolUse for Edit, Write, MultiEdit and NotebookEdit this hook hands
# Claude, beside the tool result, the matched word and what the law asks there: say what changes
# in at most 5 lines in the final reply, and ask first, through AskUserQuestion, only for a change
# Claude itself judges critical. On PostToolUse for the same tools it records an edit that went
# through, so later edits to the same file in the same session are not pointed at again.
# The regex is `risk_regex` in settings/loop.json, unless the project's CLAUDE.md (the map) sets
# its own on a `risk_regex:` line. The path is matched as the project knows it (relative to the
# git root, else the session's cwd). Unreadable input, another tool or event, no regex, or a
# path outside the zones is nothing to judge: exit 0 with no output.
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

CONFIG="${ONELOOP_HOME:-$(cd -P "$here/.." && pwd)}/settings/loop.json"
STATE_DIR="${TMPDIR:-/tmp}/oneloop-risk"

# project_map <path>: the CLAUDE.md of the repository the file is in, else the cwd's, else nothing.
project_map() {
  dir=${1%/*}
  [ "$dir" = "$1" ] && dir=.
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$top" ] && [ -f "$top/CLAUDE.md" ]; then printf '%s' "$top/CLAUDE.md"
  elif [ -n "$cwd" ] && [ -f "$cwd/CLAUDE.md" ]; then printf '%s' "$cwd/CLAUDE.md"
  fi
}

# risk_regex <path>: the map's own `risk_regex:` line when it has one, else the config's default.
risk_regex() {
  map=$(project_map "$1")
  own=""
  [ -n "$map" ] && own=$(sed -n -E 's/^risk_regex:[[:space:]]*//p' "$map" | head -n 1)
  if [ -n "$own" ]; then printf '%s' "$own"; return; fi
  [ -f "$CONFIG" ] && jq -r '.risk_regex // empty' "$CONFIG" 2>/dev/null
}

# matched_word <rel> <regex>: the first alternative of the regex the path matches, for the reason.
matched_word() {
  printf '%s' "$2" | tr '|' '\n' | while IFS= read -r alt; do
    [ -n "$alt" ] && printf '%s' "$1" | grep -qE -- "$alt" && { printf '%s' "$alt"; break; }
  done
}

# record_file <rel>: the file that says this session already edited this path and was pointed at.
record_file() { printf '%s/%s/%s' "$STATE_DIR" "${session:-no-session}" "$(printf '%s' "$1" | cksum | cut -d ' ' -f 1)"; }

# emit_pointer <rel> <word>: the context Claude reads beside the tool result; no decision, so nothing blocks.
emit_pointer() {
  jq -cn --arg c "engineering law (Guards): $1 is a risk zone (its path matches \`$2\`), and this is the first edit to it in this session; nothing blocks it. Say what changes there in at most 5 lines in the final reply. A change you judge critical (money, auth or permissions, data loss or a migration, a public contract, a behaviour the user did not ask to change) is asked through AskUserQuestion before it is built, not after." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
}

read_hook_input || exit 0
event=$(hook_field '.hook_event_name // empty')
case "$event" in PreToolUse|PostToolUse) ;; *) exit 0 ;; esac
tool=$(hook_field '.tool_name // empty')
case "$tool" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
session=$(hook_field '.session_id // empty')
project="${cwd##*/}"
rel=$(relative_path "$path" "$cwd")
regex=$(risk_regex "$path")
[ -n "$regex" ] || exit 0
printf '%s' "$rel" | grep -qE -- "$regex" || exit 0
record=$(record_file "$rel")
if [ "$event" = PostToolUse ]; then
  mkdir -p "${record%/*}" 2>/dev/null && : > "$record"
  append_log "$project" "guard | risk | edited | $rel"
  exit 0
fi
[ -f "$record" ] && exit 0
word=$(matched_word "$rel" "$regex")
append_log "$project" "guard | risk | first | $rel | matches ${word:-$regex}"
emit_pointer "$rel" "${word:-$regex}"
exit 0
