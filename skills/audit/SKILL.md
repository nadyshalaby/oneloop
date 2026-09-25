---
name: engineering-rules:audit
description: "Codebase audit under the engineering-rules law, picked by your word: the whole codebase against its own rules and the catalogs, not a per-diff review. Usage: /engineering-rules:audit [a project root or directory]"
argument-hint: "[a project root or directory]"
disable-model-invocation: true
---

# Codebase audit, by the user's word

The user typed `/engineering-rules:audit`. That picks the audit (16.3) outright: the whole
codebase against its rules, never a per-diff review.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:workflow` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:workflow`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the scope.** It is the whole invocation: a project root or a directory. Empty
   means the current project, which the preflight in 16.3 confirms; nothing is asked before
   it has looked.
3. **Read 16.3 from disk and run it**; it reaches 16.4 to 16.8 as it goes. The remediation
   proposes and confirms per finding through `AskUserQuestion`, and every fix taken runs as
   `/engineering-rules:workflow`.

A command picks the route; it waives no check, and the law binds throughout.
