---
name: triage
description: "Review triage under the engineering law, picked by your word: a batch of review findings becomes a per-finding accept, push-back, defer or needs-restatement table. Usage: /oneloop:triage <the pasted findings>"
argument-hint: "[the pasted findings]"
disable-model-invocation: true
---

# Review triage, by the user's word

The user typed `/oneloop:triage`. That picks review triage (16.2) outright: a
batch of review findings becomes one decision per finding.

- **Whole invocation:** `$ARGUMENTS`

1. **Read the findings.** They are the whole invocation or, when it is empty, the batch
   pasted most recently in this conversation; when there is neither, ask for them through
   `AskUserQuestion`, one question, and nothing else.
2. **Read 16.2 from disk and run it.** A finding accepted for a fix runs as a task of the
   loop (the always-on law) when the user says go.

A command picks the route; it waives no check, and the law binds throughout.
