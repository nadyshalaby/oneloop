#!/bin/bash
# oneloop code rules.
# The code rules bind every line of code written, and the law loads them with the first code
# file a session reads. A plugin cannot put a rules file where Claude Code would load it by
# path, so this hook does that work: on PreToolUse for Read and for the four edit tools, when
# the file's extension is one the code rules' `paths:` globs name and no earlier event in this
# session has done it, it hands Claude the code rules (the text under the front matter) as
# context beside the tool result, then leaves a marker so the session pays for them once.
# Everything else (another tool or event, a file the globs do not cover, a later code file in
# the same session, unreadable input, a rules file that cannot be read) is nothing to do: exit 0
# with no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

ROOT="${ONELOOP_HOME:-$(cd -P "$here/.." && pwd)}"
RULES="$ROOT/law/engineering-code.md"
STATE_DIR="${TMPDIR:-/tmp}/oneloop-code-rules"

# code_extensions: the extensions inside the braces of the globs under the front matter's
# paths: key, one per line.
code_extensions() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } /^  - "/ { print }' "$RULES" \
    | sed -E 's/.*\{//; s/\}.*//' | tr ',' '\n'
}

# is_code <path>: the file's extension is one the globs name.
is_code() {
  name=${1##*/}
  case "$name" in *.*) ext=${name##*.} ;; *) return 1 ;; esac
  code_extensions | grep -qx -- "$ext"
}

# rules_text: the code rules without their front matter.
rules_text() { awk 'NR == 1 && $0 == "---" { skip = 1; next } skip { if ($0 == "---") skip = 0; next } { print }' "$RULES"; }

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
case "$(hook_field '.tool_name // empty')" in Read|Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
[ -r "$RULES" ] || exit 0
is_code "$path" || exit 0
session=$(hook_field '.session_id // empty')
marker="$STATE_DIR/${session:-no-session}"
[ -f "$marker" ] && exit 0
cwd=$(hook_field '.cwd // empty')
mkdir -p "$STATE_DIR" 2>/dev/null && : > "$marker"
{
  printf 'oneloop: the code rules, part of the engineering law, loaded with the first code file of this session (%s). They bind every line of code you write.\n\n' "${path##*/}"
  rules_text
} | jq -Rs '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: .}}'
append_log "${cwd##*/}" "code-rules | loaded | ${path##*/}"
exit 0
