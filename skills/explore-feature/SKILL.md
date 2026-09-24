---
name: engineering-rules:explore-feature
description: "Explore one feature under the engineering-rules law, picked by your word: one entry point traced to its leaves and published as a browsable page, every cited line verified against the working tree first, with what one real run did at every function on the page, masked, from the project's own test or a request you fire. Usage: /engineering-rules:explore-feature <the entry point>"
argument-hint: "[the entry point]"
disable-model-invocation: true
---

# Explore a feature, by the user's word

The user typed `/engineering-rules:explore-feature`. That picks the explore-feature route
(16.9) outright: one execution path, traced from its entry point to its leaves, published
as one page the user can click through.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:engineering-rules` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:engineering-rules`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the entry point.** It is the whole invocation. When it is empty, ask for it
   through `AskUserQuestion`, one question; 16.9 stops on an ambiguous entry point anyway,
   so it is settled before anything is read.
3. **Read 16.9 from disk and run it**, with 16.10 and 16.11 as it names them. The page
   template, the three scripts it runs and the capture's loaders live beside this file,
   under `assets/`, `scripts/` and `capture/`. The route edits nothing in the explored
   repository, so no ledger opens unless the user turns a finding into a task, which then
   runs as `/engineering-rules:do`.

A sub-command picks the route; it waives no check, and the law binds throughout.
