#!/bin/bash
# Shared by progress-notify.sh, re-anchor.sh and statusline.sh: the phase-ledger heading Claude
# prints, "## 0. Phase ledger  (3 of 6, Phase 4)", and how to read the position out of it.
LEDGER_HEADING='## 0\. Phase ledger +\([^)]*\)'
LEDGER_PREFIX='## 0. Phase ledger'

# read_ledger_position: text on stdin, the last "(N of M, Phase X)" on stdout, empty when none.
read_ledger_position() {
  heading=$(grep -E -o "$LEDGER_HEADING" | tail -n 1)
  position="${heading#"$LEDGER_PREFIX"}"
  printf '%s' "${position#"${position%%[![:space:]]*}"}"
}

# claude_text: transcript lines on stdin, the text of Claude's own replies that mention the
# ledger on stdout. Tool inputs, tool results, thinking and file contents are left out, so a
# heading quoted from a document, a test or a diff is never read as one Claude printed. A line
# cut short, as a byte slice can start with, is skipped.
claude_text() {
  LC_ALL=C grep -F "$LEDGER_PREFIX" | jq -Rr 'fromjson? | select(.type == "assistant")
    | .message.content | if type == "array" then .[] | select(.type == "text") | .text else empty end' 2>/dev/null
}
