---
name: engineering-rules:build
description: "The engineering-rules workflow on a request: plan, implement, verify and deploy, skipping what is already done or fully known. Usage: /engineering-rules:build <what you want done>"
argument-hint: "[what you want done]"
disable-model-invocation: true
---

# Build, by the user's word

The user typed `/engineering-rules:build`, the default route.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:workflow` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:workflow`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the request.** It is the whole invocation. When it is empty, it is the most recent
   ask in this conversation, in the user's own words; when there is none either, ask for it
   through `AskUserQuestion`, and ask nothing else.
3. **Run the three phases on it**, from the resume check, skipping only what the workflow's skip
   rule allows.
