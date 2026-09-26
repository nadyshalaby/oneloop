---
name: brainstorm
description: "Brainstorming under the engineering law, picked by your word: one Socratic conversation, one or two forking questions a turn, until the idea is a task and the loop starts. Usage: /oneloop:brainstorm <the idea>"
argument-hint: "[the idea]"
disable-model-invocation: true
---

# Brainstorm, by the user's word

The user typed `/oneloop:brainstorm`. That picks the brainstorm (16.1) outright: the
idea is not a task yet.

- **Whole invocation:** `$ARGUMENTS`

1. **Read the idea.** It is the whole invocation. When it is empty, it is what this
   conversation was last discussing; when there is nothing, ask what is on their mind
   through `AskUserQuestion`, one question, and nothing else.
2. **Read 16.1 from disk and run it**: one or two forking questions per turn, every one
   through `AskUserQuestion`, nothing edited, until the user signals intent to build. The
   task then runs the loop (the always-on law): its Scope step opens on the distillation,
   prints the scope line and the note, and waits for the yes.

A command picks the route; it waives no check, and the law binds throughout.
