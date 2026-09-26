---
name: release-notes
description: "Prints the release notes for the task in flight: the plain-language summary, only when you type it (16.13). Usage: /oneloop:release-notes"
disable-model-invocation: true
---

# Release notes, on demand

The user typed `/oneloop:release-notes`. That picks the release notes (16.13) outright.
It takes no request: printing a summary is not a task, and it sends no helper. Nothing prints
them unasked: the loop's final reply is the files changed, the check results and the side finds.

1. **Read 16.13 from disk** and print the notes from the commits, the check results and the
   side finds of the task in flight in this conversation. Every claim in it has a check run
   this session behind it (law 1.5).
2. **When no task is in flight**, say so in one line and print nothing else. Nothing is
   edited, and nothing else starts.
