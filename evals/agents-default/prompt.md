---
schema_version: "1"
name: agents-default
description: Phase agents are the default. A quick-mode request with no switch runs each phase as the agent and model 1.8's map names, while the ledger, the scouts, the dispositions and the review stay in the main conversation.
tags: [skill, routes, agents, models]
runs: 2
max_turns: 30
timeout_seconds: 900
allowed_tools: [Write, Edit, Read, Bash, AskUserQuestion, Skill, Agent]
expected_outcome: The sub-command loads the skill, states quick mode and "Agents on, the default", records "Agents: on" on the ledger line, sends the implementation stage to a general-purpose agent on sonnet and the review to a general-purpose agent on opus, keeps the ledger, the scout dispositions and every tick in the main conversation, and prints the phase ledger.
---
/engineering-rules:quick add a function `sum(a, b)` that returns `a + b` to a new file `sum.js` in this directory, exported as a CommonJS module, with a test in `sum.test.js` that runs under `node --test`
