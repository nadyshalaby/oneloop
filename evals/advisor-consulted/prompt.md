---
schema_version: "1"
name: advisor-consulted
description: Every decision goes past the advisor where the tool list holds one. A quick-mode task records the advisor on the ledger line, states the decision before each call, treats what comes back as a report rather than proof, and never writes a verdict for a call it did not make.
tags: [skill, law, advisor, decisions]
runs: 2
max_turns: 30
timeout_seconds: 900
allowed_tools: [Write, Edit, Read, Bash, AskUserQuestion, Skill, Agent]
expected_outcome: The sub-command loads the skill, the ledger line records "Advisor: on" or "Advisor: none in this session", and the run follows 5.7 either way. With an advisor in the tool list it is called before the clarify batch goes out, before the approach is settled, before Phase 4 ticks and before the review's decision table is final, each call preceded by a line stating the decision, its options and the evidence, and each tick carrying an "advisor:" verdict. With none in the list, the decisions are stated the same way and no advisor verdict is written anywhere.
---
/engineering-rules:quick add a function `sum(a, b)` that returns `a + b` to a new file `sum.js` in this directory, exported as a CommonJS module, with a test in `sum.test.js` that runs under `node --test`
