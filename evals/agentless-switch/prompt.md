---
schema_version: "1"
name: agentless-switch
description: The switch still works in the other direction. `/engineering-rules:agents off` before a quick-mode request keeps every phase in the main conversation, so the Agent tool is never called, while the ledger, the scouts and the review still run.
tags: [skill, routes, agentless]
runs: 2
max_turns: 25
timeout_seconds: 900
allowed_tools: [Write, Edit, Read, Bash, AskUserQuestion, Skill, Agent]
expected_outcome: The switch records "Agents: off, by user choice" with its one-line cost, the quick-mode task that follows never calls the Agent tool at any point, and the phase ledger, the scouts and the review still run in the main conversation.
---
/engineering-rules:agents off

/engineering-rules:quick add a function `sum(a, b)` that returns `a + b` to a new file `sum.js` in this directory, exported as a CommonJS module, with a test in `sum.test.js` that runs under `node --test`
