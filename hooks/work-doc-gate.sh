#!/bin/bash
# engineering-rules work-doc gate.
# Runs on PreToolUse for Edit, Write, MultiEdit and NotebookEdit. In full mode the work-doc is
# the map: it says which phase is open and which task is next, and SKILL.md 1.4 and 1.9 say the
# work happens in that order, with every tick written as it lands. This hook holds that line at
# the tool boundary. While a live work-doc exists under docs/work/, an edit to a code or test
# file is refused unless the doc agrees with it: exactly one phase open, a phase that may write
# code, every task in progress ahead of every task still waiting, and every ticked task
# already written up under Daily Updates. Prose and generated files are never gated, so the
# work-doc, the README and the docs stay editable at any point, and a task with no live
# work-doc (quick mode, a trivial ask, a repository that keeps none) is nothing to gate: exit 0
# with no output. The doc is the only source; this file holds no plan of its own.
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

WORK_DIR=docs/work
# The phases that may write code: implement, debug, the review's fix pass, the finish cleanup.
CODE_PHASES='Phase (3|3b|5|6)'

# project_root <cwd>: the git top level, else the cwd, so the gate finds docs/work from anywhere.
project_root() { git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${1:-.}"; }

# live_docs <root>: every work-doc still in flight, one per line; docs/work/done/ is archived.
live_docs() { find "$1/$WORK_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort; }

# emit <decision> <reason>: the PreToolUse decision, as the JSON Claude Code reads.
emit() {
  jq -cn --arg d "$1" --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
}

# defect <work-doc>: the first thing the doc and the edit disagree about, as `code|detail`,
# or nothing when the doc says this edit may happen. One pass, in the doc's own order.
defect() {
  awk '
    /^## / { ledger = ($0 ~ /Phase ledger/); backlog = ($0 ~ /Sprint Backlog/); updates = ($0 ~ /Daily Updates/); next }
    ledger && /^- \[/ { items++; if ($0 ~ /^- \[>\]/) { open++; phase = trim($0) } next }
    backlog && /^- \[/ {
      tasks++
      if ($0 ~ /^- \[>\]/) { running++; if (waiting && !late) late = trim($0) }
      else if ($0 !~ /^- \[x\]/) waiting++
      if ($0 ~ /^- \[x\]/) { ticked++; id = taskid($0); if (id != "") { ids[++n] = id } }
      next
    }
    updates && /^### / { entries++; sub(/^### /, ""); split($0, w, /[ (,]/); wrote[w[1]] = 1; next }
    function trim(s) { sub(/^- \[.\] */, "", s); gsub(/\*\*/, "", s); return substr(s, 1, 80) }
    function taskid(s,   m) { if (match(s, /\*\*[A-Za-z]+[0-9]+\*\*/)) { m = substr(s, RSTART + 2, RLENGTH - 4); return m } return "" }
    END {
      if (!items) { print "no-ledger|"; exit }
      if (!open) { print "no-open-phase|"; exit }
      if (open > 1) { print "two-open-phases|" open; exit }
      if (phase !~ /'"$CODE_PHASES"'/) { print "wrong-phase|" phase; exit }
      if (!tasks) { print "no-backlog|"; exit }
      if (late) { print "out-of-order|" late; exit }
      for (i = 1; i <= n; i++) if (!wrote[ids[i]]) { print "unwritten|" ids[i]; exit }
      if (n == 0 && ticked > entries) { print "unwritten-count|" ticked " ticked, " entries " written"; exit }
    }' "$1"
}

# reason <code> <detail> <doc>: the refusal, in the law's own words, naming what to do next.
reason() {
  law='The work-doc is the map, and the work follows it in its order (SKILL.md 1.4, 1.9, 7.3).'
  case "$1" in
    no-ledger) printf '%s %s has no phase ledger, so nothing says which phase this edit belongs to. Write the "## 0. Phase ledger" block with its items (5.1) before the next code edit.' "$law" "$3" ;;
    no-open-phase) printf '%s No item in the phase ledger of %s is in progress. Open the phase you are in, with the in-progress mark, before writing code.' "$law" "$3" ;;
    two-open-phases) printf '%s The phase ledger of %s has %s items in progress. One item is open at a time (5.1); close the one you finished, with its reflection, then open the next.' "$law" "$3" "$2" ;;
    wrong-phase) printf '%s The open phase is "%s", which does not write code. Code lands in Phase 3, 3b, the Phase 5 fix pass or the Phase 6 cleanup; finish the open phase and tick it with its exit artifact first.' "$law" "$2" ;;
    no-backlog) printf '%s %s has no Sprint Backlog, so no task authorizes this edit. Write the backlog (7.2) before building.' "$law" "$3" ;;
    out-of-order) printf '%s The task in progress is "%s", and an earlier task in the Sprint Backlog is still waiting. Tasks are taken in the order the backlog lists them, and parallel stages are the next ones, never a later one. Move the task in the doc first and say why, or finish what is ahead of it.' "$law" "$2" ;;
    unwritten) printf '%s Task %s is ticked in the Sprint Backlog with no "### %s" entry under Daily Updates. A tick with no written proof is no tick at all (1.4): write the entry, then carry on.' "$law" "$2" "$2" ;;
    unwritten-count) printf '%s The Sprint Backlog of %s is ahead of Daily Updates (%s). Every tick is written as it lands (1.4).' "$law" "$3" "$2" ;;
    *) printf '%s %s and this edit disagree.' "$law" "$3" ;;
  esac
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
case "$(hook_field '.tool_name // empty')" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
case "$(path_kind "$(relative_path "$path" "$cwd")")" in prose|generated) exit 0 ;; esac
root=$(project_root "$cwd")
docs=$(live_docs "$root")
[ -n "$docs" ] || exit 0
count=$(printf '%s\n' "$docs" | grep -c .)
if [ "$count" -gt 1 ]; then
  append_log "$project" "gate | work-doc | deny | two-live-docs | $path"
  emit deny "The work-doc is the map, and a task has exactly one (7.3). $root/$WORK_DIR holds $count live work-docs; archive the finished one under $WORK_DIR/done/ before writing more code."
  exit 0
fi
found=$(defect "$docs")
[ -n "$found" ] || exit 0
append_log "$project" "gate | work-doc | deny | ${found%%|*} | $path"
emit deny "$(reason "${found%%|*}" "${found#*|}" "$docs")"
exit 0
