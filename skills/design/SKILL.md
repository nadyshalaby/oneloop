---
name: engineering-rules:design
description: "The design-spec route of the engineering-rules law, picked by your word: author, extract or refresh the project's design spec. Usage: /engineering-rules:design [author|extract|refresh] [a direction]"
argument-hint: "[author|extract|refresh] [a direction]"
disable-model-invocation: true
---

# Design spec, by the user's word

The user typed `/engineering-rules:design`. That picks the design-spec route (15.19)
outright: author, extract or refresh the project's design spec.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:engineering-rules` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:engineering-rules`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the request**: the mode 15.19 names (author, extract or refresh) and a direction
   from the library (15.4) when the user named one. It is the whole invocation. Empty means
   15.19 detects the mode from the repository; nothing is asked before it has looked.
3. **Read 15.19 from disk and run it**, with 15.1 to 15.6 as it names them, as a
   `/engineering-rules:do` task: writing or changing the spec is substantive.

A sub-command picks the route; it waives no check, and the law binds throughout.
