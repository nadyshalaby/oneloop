---
name: engineering-rules:skill
description: "Skill authoring under the engineering-rules law, picked by your word: a new reusable skill, written last, that passes its structural checks. Usage: /engineering-rules:skill <what the skill should do>"
argument-hint: "[what the skill should do]"
disable-model-invocation: true
---

# Skill authoring, by the user's word

The user typed `/engineering-rules:skill`. That picks skill authoring (16.12) outright: a
new reusable skill, invoked by name later, not a one-off script.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:engineering-rules` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:engineering-rules`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the request**: what the skill should do, and for whom. It is the whole invocation.
   When it is empty, it is what this conversation was last discussing; when there is
   nothing, ask through `AskUserQuestion`, one question.
3. **Read 16.12 from disk and run it** as a `/engineering-rules:do` task: 16.12 shapes its
   plan, and the file is written last, in the order 16.12 fixes.

A sub-command picks the route; it waives no check, and the law binds throughout.
