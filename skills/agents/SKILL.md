---
name: engineering-rules:agents
description: "The helper switch of the engineering-rules workflow: its three helpers (a reader, parallel builders and the reviewer, each on its own model) are on by default. `off` runs their work in this chat instead, for the task in flight and every task after it, until you switch back. Usage: /engineering-rules:agents [off | what you want done]"
argument-hint: "[off | what you want done]"
disable-model-invocation: true
---

# The helper switch, by the user's word

The user typed `/engineering-rules:agents`. The workflow's three helpers, `er-reader`,
`er-builder` and `er-reviewer`, are on by default. This switch turns them off, or back on, for
the task in flight and for every task that starts in this conversation.

- **Whole invocation:** `$ARGUMENTS`

1. **Load the workflow**, unless the `engineering-rules:engineering-rules` skill is already
   loaded in this conversation: invoke the Skill tool with `engineering-rules:engineering-rules`.
   (The always-on law is already in context through CLAUDE.md; its code rules load with
   the first code file read.)
2. **Read the invocation.**
   - The single word `off`: print `Helpers: off by user; their work runs in this session.`
     From the next step of the task in flight, the sweep, the parallel tasks and the review
     run here, from the same files (the review from `~/.claude/agents/er-reviewer.md`);
     nothing already done is re-done. Then stop.
   - Empty: print `Helpers: on.` With a task in flight, the helpers resume from its next
     step; with none, wait for the task. Nothing else starts, and nothing is asked.
   - Anything else is the request: helpers on, and it runs as `/engineering-rules:do`.

Turning the helpers off moves where the work happens; it removes no check, and the review
still runs on every diff that changes behaviour.
