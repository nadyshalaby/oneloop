#!/bin/bash
# oneloop session start.
# The law reaches every session here. A plugin cannot add to CLAUDE.md, so on SessionStart (a
# fresh start, a resume, a clear, a compaction, a fork) this hook hands Claude Code the whole
# core law as session context, headed by one line that names the harness root, so the paths the
# law uses (`references/`, `law/engineering-code.md`, `settings/loop.json`) resolve. After a
# compaction or a resume it adds the re-anchor: the law above is the law, a task in flight
# resumes at the loop step it was in, and nothing from before the loss counts as proof.
# Unreadable input, another event, or a law file that cannot be read (one log line): exit 0 with
# no output.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"

ROOT="${ONELOOP_HOME:-$(cd -P "$here/.." && pwd)}"
LAW="$ROOT/law/engineering-law.md"
MANIFEST="$ROOT/.claude-plugin/plugin.json"

# version: the plugin's version from its manifest, for the header line.
version() { jq -r '.version // "unversioned"' "$MANIFEST" 2>/dev/null || printf 'unversioned'; }

# anchor <reason>: the re-anchor lines a compaction or a resume adds, nothing otherwise.
anchor() {
  case "$1" in
    compact) printf 'Context was compacted. A summary of the law is not the law: the law above is the law. A task that was in flight resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof.\n' ;;
    resume) printf 'Session resumed. A task that was in flight resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof.\n' ;;
    *) : ;;
  esac
}

# context <reason>: the header, the law verbatim, then the anchor when there is one.
context() {
  printf 'oneloop %s, the engineering law, always on. Harness root: %s (the paths references/, law/ and settings/ below are under it).\n\n' "$(version)" "$ROOT"
  cat "$LAW"
  extra=$(anchor "$1")
  [ -z "$extra" ] || printf '\n%s\n' "$extra"
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = SessionStart ] || exit 0
reason=$(hook_field '.how_started // .source // empty')
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
[ -r "$LAW" ] || { append_log "$project" "law | missing | $LAW"; exit 0; }
context "$reason" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
append_log "$project" "law | ${reason:-start}"
exit 0
