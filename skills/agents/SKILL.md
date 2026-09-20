---
name: agents
description: "The agent switch for the engineering-rules law: every phase runs as an agent on its own model by default (sonnet where the phase writes code or runs commands, opus where it plans, judges or decides). `off` runs every phase in this chat instead, for the task in flight and every task after it, until you switch back. Usage: /engineering-rules:agents [off | what you want done]"
argument-hint: "[off | what you want done]"
disable-model-invocation: true
---

# The agent switch, by the user's word

The user typed `/engineering-rules:agents`. Phase agents are the default (1.8,
4.4): every phase runs as the agent and model 1.8's map names, and this session keeps the
anchor, the ledger, every question, the ship gate and every claim. This switch turns that off, or
back on, for the task in flight and for every task that starts in this conversation. It picks
no route; the routes have sub-commands of their own, and this one combines with any of them.

- **Whole invocation:** `$ARGUMENTS`

In this order, before anything else:

1. **Load the law**, unless its always-on section is already verbatim in this context:
   invoke the Skill tool with `engineering-rules:engineering-rules`. Its intake does not
   fire from here.
2. **Read the invocation.**
   - The single word `off` switches to agentless: print the agent line
     `Agents: off, by user choice; every phase runs in this session.` with the cost line 4.4
     names, and from the next run point of the task in flight every phase is the same work
     done here; nothing already done is re-done. Then stop.
   - Empty, with a task in flight (a ledger is open): switch that task back on now. Probe the
     runtime once as 1.8 says, print `Agents: on, by user choice.` (or the unavailable line),
     and the sends resume from the next run point; nothing already done is re-done.
   - Empty, with no task in flight: say in one line that phase agents are on for this
     conversation, probe once and print the agent line, then wait for the task or a route
     sub-command. Nothing else starts, and nothing is asked.
   - Anything else is the request. Agents are on for it, and it classifies under 4.1
     exactly as prose typed into `/engineering-rules:engineering-rules` does: full mode
     unless the words name another route.
3. **With a request, say the route and the mode in one line** (1.7, step 2), *"Agents on, the
   default."* included, then **run the task start** (1.7, from step 3): the base commit, the
   ledger for the route, the agent line as 1.8 records it, then 6.1 from disk.

Everything after that is the law, unchanged. The mode moves where the work happens and the
model that does it. It removes nothing: not a check, not a scout, not a gate.
