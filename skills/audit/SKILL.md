---
name: audit
description: "Codebase audit under the engineering law, picked by your word: the whole codebase against its own rules and the catalogs, not a per-diff review. Usage: /oneloop:audit [a project root or directory]"
argument-hint: "[a project root or directory]"
disable-model-invocation: true
---

# Codebase audit, by the user's word

The user typed `/oneloop:audit`. That picks the audit (16.3) outright: the whole
codebase against its rules, never a per-diff review.

- **Whole invocation:** `$ARGUMENTS`

1. **Read the scope.** It is the whole invocation: a project root or a directory. Empty
   means the current project, which the preflight in 16.3 confirms; nothing is asked before
   it has looked.
2. **Read 16.3 from disk and run it**; it reaches 16.4 to 16.8 as it goes. The remediation
   proposes and confirms per finding through `AskUserQuestion`, and every fix taken runs as
   a task of the loop (the always-on law): scope, edit, check, commit.

A command picks the route; it waives no check, and the law binds throughout.
