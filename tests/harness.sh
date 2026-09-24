#!/bin/bash
# Shared by the tests beside it: strict mode, the repo root, a scratch dir removed on exit, the
# pass and fail counters, the three assertions, two builders of transcript lines in Claude
# Code's real shape and the closing report line. Source it first:
#   . "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
set -u
WORK=$(mktemp -d "${TMPDIR:-/tmp}/$(basename "${BASH_SOURCE[1]:-engineering-rules-test}" .sh).XXXXXX")
trap 'rm -rf "$WORK"' EXIT
failures=0
count=0

# repo_root: the repository this harness lives in, whatever directory the test was run from.
repo_root() { git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel; }

# assert_contains <name> <needle> <haystack>: the needle is a fixed string, never a pattern.
assert_contains() {
  count=$((count + 1))
  case "$3" in
    *"$2"*) printf 'ok   %s\n' "$1"; return ;;
  esac
  printf 'FAIL %s\n  wanted: %s\n  in:     %s\n' "$1" "$2" "$3"
  failures=$((failures + 1))
}

# assert_eq <name> <expected> <actual>: the whole value, byte for byte.
assert_eq() {
  count=$((count + 1))
  if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"; return; fi
  printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  failures=$((failures + 1))
}

# assert_missing <name> <needle> <haystack>
assert_missing() {
  count=$((count + 1))
  case "$3" in
    *"$2"*) printf 'FAIL %s\n  did not want: %s\n  in:           %s\n' "$1" "$2" "$3"; failures=$((failures + 1)); return ;;
  esac
  printf 'ok   %s\n' "$1"
}

# reply_line <text>: a transcript line in Claude Code's shape for a reply Claude wrote.
reply_line() {
  jq -cn --arg t "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "text", text: $t}]}}'
}

# quoted_line <text>: transcript lines carrying the text where Claude did not say it, first in
# a tool's input, then in a tool result, as a file Claude wrote or read would put it there.
quoted_line() {
  jq -cn --arg t "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "t1", name: "Write", input: {content: $t}}]}}'
  jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: "t1", content: $t}]}}'
}

# report: the closing line every test prints, and its exit status.
report() {
  printf '%s\n' "$((count - failures)) passed, $failures failed"
  [ "$failures" -eq 0 ]
}
