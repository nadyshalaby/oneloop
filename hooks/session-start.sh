#!/bin/bash
# oneloop session start.
# The law reaches every session here, in two parts. A plugin cannot add to CLAUDE.md, so on
# SessionStart (a fresh start, a resume, a clear, a compaction, a fork) this hook hands Claude
# Code the core law as session context; and Claude Code keeps only a 2KB preview of a hook
# context above 10,000 characters (the rest goes to a file the model would have to read). So
# hooks.json runs this script twice, with `1` and with `2`, and each run carries one part of the
# law: the split is the `## ` heading nearest the middle by characters, or the line nearest the
# middle when that heading would leave a part over PART_CAP. Each part is headed by one line
# naming the part and its lines, the plugin version and the harness root, so the paths the law
# uses (`references/`, `law/engineering-code.md`, `settings/loop.json`) resolve from either part.
# After a compaction or a resume, part 2 adds the re-anchor: the law is the law, a task in
# flight resumes at the loop step it was in, and nothing from before the loss counts as proof.
# Unreadable input, another event, a part that is not 1 or 2, or a law file that cannot be read
# (one log line each): exit 0 with no output.
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
# The characters of law one part may carry: with its header and the anchor it stays under the
# 10,000 Claude Code shows whole.
PART_CAP=9000

# version: the plugin's version from its manifest, for the header line.
version() { jq -r '.version // "unversioned"' "$MANIFEST" 2>/dev/null || printf 'unversioned'; }

# split_line: the number of the first line of part 2: the `## ` heading whose first character
# sits nearest half the law's characters, when it leaves both parts under PART_CAP; else the
# line that sits nearest the half.
split_line() {
  awk -v cap="$PART_CAP" '
    { text[NR] = $0; start[NR] = total; total += length($0) + 1 }
    function nearest(headings,   i, gap, best, off) {
      best = 0; gap = total
      for (i = 2; i <= NR; i++) {
        if (headings && text[i] !~ /^## /) continue
        off = start[i] - total / 2
        if (off < 0) off = -off
        if (off < gap) { gap = off; best = i }
      }
      return best
    }
    END {
      line = nearest(1)
      if (!line || start[line] > cap || total - start[line] > cap) line = nearest(0)
      print (line ? line : NR + 1)
    }' "$LAW"
}

# anchor <reason>: the re-anchor lines a compaction or a resume adds, nothing otherwise.
anchor() {
  case "$1" in
    compact) printf 'Context was compacted. A summary of the law is not the law: the law in its two parts is the law. A task that was in flight resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof.\n' ;;
    resume) printf 'Session resumed. A task that was in flight resumes at the loop step it was in (scope, edit, check or commit); nothing from before the loss counts as proof.\n' ;;
    *) : ;;
  esac
}

# header <part> <first line> <last line>: the line above a part: the plugin version, the part
# and its lines, the harness root.
header() {
  printf 'oneloop %s, the engineering law, always on, part %s of 2 (lines %s to %s of law/engineering-law.md; the other part is another SessionStart context, and the two together are the whole law). Harness root: %s (the paths references/, law/ and settings/ below are under it).\n\n' "$(version)" "$1" "$2" "$3" "$ROOT"
}

# context <reason> <part>: the header, that part of the law verbatim, and on part 2 the anchor
# when there is one.
context() {
  split=$(split_line)
  last=$(awk 'END { print NR }' "$LAW")
  if [ "$2" = 1 ]; then
    header 1 1 $((split - 1))
    head -n $((split - 1)) "$LAW"
  else
    header 2 "$split" "$last"
    tail -n +"$split" "$LAW"
    extra=$(anchor "$1")
    [ -z "$extra" ] || printf '\n%s\n' "$extra"
  fi
}

part=${1:-}
read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = SessionStart ] || exit 0
reason=$(hook_field '.how_started // .source // empty')
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
case "$part" in
  1 | 2) : ;;
  *) append_log "$project" "law | ${reason:-start} | part not 1 or 2"; exit 0 ;;
esac
[ -r "$LAW" ] || { append_log "$project" "law | missing | $LAW"; exit 0; }
context "$reason" "$part" | jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
append_log "$project" "law | ${reason:-start} | part $part"
exit 0
