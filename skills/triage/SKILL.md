---
name: engineering-rules:triage
description: "Review triage under the engineering-rules law, picked by your word: a batch of review findings becomes a per-finding accept, push-back, defer or needs-restatement table. Usage: /engineering-rules:triage <the pasted findings>"
argument-hint: "[the pasted findings]"
disable-model-invocation: true
---

# Review triage, by the user's word

The user typed `/engineering-rules:triage`. That picks review triage (16.2) outright: a
batch of review findings becomes one decision per finding.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:workflow` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:workflow`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the findings.** They are the whole invocation or, when it is empty, the batch
   pasted most recently in this conversation; when there is neither, ask for them through
   `AskUserQuestion`, one question, and nothing else.
3. **Read 16.2 from disk and run it.** A finding accepted for a fix runs as
   `/engineering-rules:build` when the user says go.

A sub-command picks the route; it waives no check, and the law binds throughout.
