---
name: engineering-rules:release-notes
description: "Prints the engineering-rules release notes for the task in flight: the plain-language summary, on demand, mid-flight (16.13). Usage: /engineering-rules:release-notes"
disable-model-invocation: true
---

# Release notes, on demand

The user typed `/engineering-rules:release-notes`. That picks the release notes (16.13) outright. It takes
no request: printing a summary is not a task, and it sends no helper.

1. **Load the workflow**, unless the `engineering-rules:workflow` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:workflow`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read 16.13 from disk** and print the notes from the ledger, the work-doc, the evidence
   and the commits of the task in flight in this conversation. Every claim in it has a proof
   row behind it (law 1.5).
3. **When no task is in flight**, say so in one line and print nothing else. The ledger does
   not move, nothing is ticked, and nothing else starts.
