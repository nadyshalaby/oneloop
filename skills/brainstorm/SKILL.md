---
name: engineering-rules:brainstorm
description: "Brainstorming (shaping) under the engineering-rules law, picked by your word: one Socratic conversation, one or two forking questions a turn, until the idea is a task and the build starts. Usage: /engineering-rules:brainstorm <the idea>"
argument-hint: "[the idea]"
disable-model-invocation: true
---

# Brainstorm, by the user's word

The user typed `/engineering-rules:brainstorm`. That picks shaping (16.1) outright: the idea is
not a task yet, and the trigger phrases 16.1 lists no longer matter.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:workflow` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:workflow`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the idea.** It is the whole invocation. When it is empty, it is what this
   conversation was last discussing; when there is nothing, ask what is on their mind
   through `AskUserQuestion`, one question, and nothing else.
3. **Read 16.1 from disk and run it**: one or two forking questions per turn, every one
   through `AskUserQuestion`, nothing edited, until the user signals intent to build. The
   shaped task then runs as `/engineering-rules:build`, its Plan starting from what shaping
   settled.

A sub-command picks the route; it waives no check, and the law binds throughout.
