---
name: design-spec
description: "The design-spec route of the engineering law, picked by your word: author, extract or refresh the project's design spec. Usage: /oneloop:design-spec [author|extract|refresh] [a direction]"
argument-hint: "[author|extract|refresh] [a direction]"
disable-model-invocation: true
---

# Design spec, by the user's word

The user typed `/oneloop:design-spec`. That picks the design-spec route (15.19)
outright: author, extract or refresh the project's design spec.

- **Whole invocation:** `$ARGUMENTS`

1. **Read the request**: the mode 15.19 names (author, extract or refresh) and a direction
   from the library (15.4) when the user named one. It is the whole invocation. Empty means
   15.19 detects the mode from the repository; nothing is asked before it has looked.
2. **Read 15.19 from disk and run it**, with 15.1 to 15.6 as it names them, as a task of the
   loop (the always-on law): writing or changing the spec is an edit, so it gets the scope
   line and the note before anything is written.

A command picks the route; it waives no check, and the law binds throughout.
