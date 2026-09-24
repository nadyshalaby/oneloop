---
name: engineering-rules:engineering-rules
argument-hint: "[what you want done]"
description: >-
  The engineering-rules phase workflow: the phase ledger, the eight phases (clarify, plan, spec
  review, implement, debug, verify, review, finish), the routes, the intake and the phase agents.
  The always-on engineering law already binds every session through the user-global CLAUDE.md;
  this skill adds the phases. Use it only when the user names the engineering-rules workflow or
  one of its routes (full mode, quick mode, shaping, explore a feature, audit, triage, skill
  authoring, design spec, update log) in their words, or when a /engineering-rules: command loads it.
---

# Engineering rules: the phase workflow

> The always-on law, `~/.claude/engineering-rules/law/engineering-law.md`, is already in context through the
> user-global `CLAUDE.md` and binds every task. This skill adds the phase workflow; everything in
> it binds from the moment it loads until the task is done. Every file under
> `~/.claude/engineering-rules/references/` is read at the moment its phase calls for it, and once read, it binds
> too. **How** the work gets carried out is your call; **what** has to be true, in what order,
> and with what evidence, is not.

## How to read this skill

The always-on law is the short form in `~/.claude/engineering-rules/law/engineering-law.md`; the workflow's own law
(1.4, 1.7, 1.8) is here. Everything else lives in `~/.claude/engineering-rules/references/`, one file per
section, numbered exactly as the map at the end of this file numbers it. Read a reference at the moment its phase
calls for it, from disk, never from memory: yourself when it is short, or through a fork that
reads it in its own context and returns the lines that apply (1.8, 5.5); in agentless mode (4.4)
always yourself. What the fork returns binds exactly as the file does. Section `0.1` carries the
full per-section table.

**Nothing found on the way is chased; the law's 1.9 wins over every reference that says otherwise.** Every scout row and every review finding is tagged `introduced` or `present at base`, checked against the base commit, and only an `introduced` one is this task's to fix. Where 9.1's sweep, 9.5's dispositions, the checks of 12.3 to 12.7, 13.2's class 10 or 1.9's long form say to remove dead code that was already there, fix a member of a defect's family the goal does not name, or fix anything `present at base`, the row is disposed as `follow-up, present at base` instead: written down with its `file:line` and handed to the user, never fixed in this task.

| Tag | What it is |
|---|---|
| `[law]` / `[rule]` | Binding on every task, always. |
| `[doctrine]` | Binding whenever you write code. |
| `[catalog]` | A stable ID scheme other sections cite. Look up an ID; never read end to end. |
| `[route]` | A way in. Follow it when the prompt matches its trigger. |
| `[phase]` | The protocol for one phase of the workflow. |
| `[check]` | Work with a fixed method, verification list and report shape. |
| `[reference]` | Detail a phase or route sends you to. Read when it is named. |
| `[contract]` / `[protocol]` / `[rubric]` / `[template]` | A shape something must conform to. |
| `[scout]` | A deterministic scan with a staging table. |

## Invocation, the three ways in

This skill loads three ways, and all three bind identically; none is a lighter version of
another.

1. **By the user's word**: they name the engineering-rules workflow or one of its routes in their
   message. The request is that message, and it classifies under 4.1. The workflow never starts
   on its own because a task touches code; the always-on law covers that.
2. **By name with a request**: `/engineering-rules:engineering-rules <what you want done>`.
   The request is what follows the name, and it classifies under 4.1 exactly as prose does.
   This form carries no route token; every route has a sub-command of its own.
3. **Through a route sub-command**: `/engineering-rules:quick`, `:full`, `:shape`,
   `:explore-feature`, `:audit`, `:triage`, `:skill`, `:design` or `:log`, followed by what that
   route needs. The sub-command loads this skill, picks its row outright, and the
   classification in 4.1 does not run. A tenth, `/engineering-rules:agents`, picks no
   route: phase agents are the default (1.8), and this one switches them off for the
   conversation and back on again, bare or with a request. The whole contract is 4.4.

- **Whole invocation:** `$ARGUMENTS`

That line renders empty when this skill was loaded by the user's word in prose, was invoked bare, or was loaded by a sub-command; empty is not a route and not a request.

**The intake, and the three times it must not fire.** When the user invoked this skill by name
with nothing after it, walk them through the options through the wizard tool, the way 4.4 lays
out: what they are here for, then which route, then agents or agentless, then the request. The
flow starts only when all three facts are settled, and nothing is classified, opened or read for
the task before then. The intake never fires in the other three cases: not when the user named
the workflow in a message that carries the task, not when the message carries a request in any form, however
short, and not when a sub-command loaded it. A menu in front of somebody who already said what
they want is ceremony, and 4.1 forbids reading a task's shape as a request for more of it.

**Phase agents are the default** (1.8, 4.4). Every phase runs as the agent its row in 1.8's map
names, on the model that row names: `sonnet` where the phase writes code or runs commands, `opus`
where it plans, judges or decides. This session keeps the anchor, the ledger, every question, the
gate and every claim. `/engineering-rules:agents off`, the user's own words, or the intake's
question switches the conversation to agentless: every phase then runs here, nothing is dropped.

## Definitions, binding wherever the word is used

| Term | Meaning |
|---|---|
| **Trivial ask** | Exactly three shapes, and no fourth: (a) a factual question answered without editing anything; (b) a one-line change to a comment, a string literal or documentation that changes no behaviour; (c) read-only inspection that leads to no edit. Anything that changes behaviour, however small, is substantive. |
| **Substantive ask** | Everything that is not trivial: any edit, creation, deletion, move, rename or configuration change. |
| **Read-only ask** | A question or inspection that will not lead to an edit in this task. If it does lead to one, the ledger opens at that moment. |
| **UI-bearing** | Any change to markup, styles, tokens, components, screens, layout, motion, copy shown in a UI, or visual assets, on web or native. |
| **Production code** | Every file that ships. Test files (`*.test.*`, `*.spec.*`, `*_test.*`, `*_spec.*`, `test_*`, and anything under `tests/`, `__tests__/`, `test/` or `spec/`), generated files and migrations are not production code for the purposes of the bans in 1.1, with two exceptions written for test files: the suppression ban still holds there (its sole exception is in 1.1), and the focused-or-skipped-test ban exists only there. Nothing else is exempt. |
| **Domain code** | Services, use-cases, repositories, business rules, validators, jobs and workers. Not scripts, not tests, not CLI glue, not presentation. |
| **Hot path** | Anything run per request, per render, per row, per job or per frame, or inside a loop over data-sized input. |
| **Touched scope** | `git diff --name-only <base>..HEAD -- . ':(exclude)docs/work/*'`, where `<base>` is the commit recorded at task start. |
| **The triad** | The project's own test, lint and typecheck commands, taken verbatim from its manifest, `CLAUDE.md` or README. Never guessed. |
| **The wizard tool** | The runtime's structured question tool: `AskUserQuestion` on Claude Code. |
| **The agent tool** | The runtime's subagent tool: `Agent` on Claude Code. Every phase agent runs on a type Claude Code ships itself, none on an agent of this setup's: `subagent_type: "fork"` for a reader that needs the conversation (the scouts, the question batch), `"Explore"` for a wide read-only search, `"Plan"` for the spec reviewer of Phase 2.5 and for the planner when it is hunting a root cause, both read-only by construction, and `"general-purpose"` for the planner of Phase 2, which writes the work-doc itself, for the reviewer of the diff, the mechanic and a builder, each sent its shape's prompt from 5.5 pasted whole. Every send but a fork names its `model`, from the map in 1.8: `sonnet` where the phase writes code or runs commands, `opus` where it plans, judges or decides. Section 1.8 is this skill's standing request for it. In agentless mode (4.4), the opt-out, nothing is sent to it and every phase runs here. |
| **Phase agent** | The agent that carries one phase's work: a reader, a planner, a spec reviewer, a builder, a mechanic or a reviewer (5.5), on the type and model 1.8's map gives that run point. Never an owner of a phase, a tick or a claim. The phase stays this session's, and what comes back is a report until this session re-runs it. |
| **Agentless mode** | The opt-out mode: every phase agent's work runs in this session for the whole task and nothing is sent to the agent tool. Switched on by `/engineering-rules:agents off`, by the user's own words in the message that starts the task, or through the intake (4.4), and it holds for the conversation until they switch back. Recorded once, on the agent line (1.8). |
| **Follow-up** | Anything true, useful and outside the main goal: a pre-existing defect, a law break in a file you happened to open, a missing test, a smell, a better idea. Written down with its `file:line` the moment it is seen, fixed in a task of its own, never in this one (1.9). |
| **The notification tool** | The runtime's push-notification tool: `PushNotification` on Claude Code. One line to the desktop and, with Remote Control, the phone. |
| **The advisor tool** | The runtime's second-opinion tool: `advisor` on Claude Code, a model the user chose, at least as capable as the one running, which takes no input, reads the whole conversation and returns guidance. It is in the tool list only where the user set one and the runtime accepts the pairing, in this session and in each agent separately, so its absence is a fact about that context, never an error (1.4, 5.7). |
| **The ledger substrate** | The runtime's todo tracker when it exposes one; otherwise the printed block. Named once at the first print. On Claude Code the tracker is the `Task` family (`TaskCreate`, `TaskList`, `TaskUpdate`, `TaskGet`), which arrives deferred and is loaded once at task start before the first call; there is no `TodoWrite` (5.1). |
| **Exit artifact** | The concrete thing that must exist before a ledger item may tick. One per phase, listed in section 5.1. |

## The workflow's own law

These three sections bind from the moment this skill loads. The rest of the always-on law
(1.1 to 1.3, 1.5, 1.6, 1.9 to 1.11) is the short form already in context.

### 1.4 [rule] Phase discipline

- **Every substantive task opens the phase ledger** (section 5.1) at task start, in every mode, before any code. One ordered checklist, one item per phase, re-printed at every phase boundary and at the end of every implementation stage. On Claude Code the tracker is the `Task` family, loaded once at task start before the first call; where the runtime has none, print the block in chat, say once which substrate you are on, and in full mode keep the durable copy in the work-doc's `## 0. Phase ledger`. A missing tool is never a reason to drop the ledger. **In chat, name a task by what it does, never by a number, a code or a serial:** *"the invite-expiry fix"*, not *"task 3"*. The only carve-outs are the three trivial shapes in Definitions.
- **Phases run in order, one open at a time.** No later phase starts while an earlier one is open. This is the refuse-to-advance law and the whole point of the ledger.
- **No phase is ever silently skipped.** A phase that genuinely does not apply is ticked complete with a one-line reason. Never deleted, never dropped in silence, in any mode.
- **Every question goes through the wizard tool.** Any question, decision, approval or request for feedback put to the user, in every phase: a fork the plan leaves open, fix approvals, the finish menu, a mid-task fork. A plain numbered list in chat is forbidden. The recommended option is first and carries ` (Recommended)`.
- **Every decision goes past the advisor tool, whenever the tool list holds one.** Before an approach or a plan is committed to, before a recommendation is put to the user, before acting on a review or a root cause, before a change of direction, before anything hard to undo, and before verified or done is said: state the decision, the options and the evidence in a line or two, call the advisor, then decide. The test is the tool list, never the model this session or an agent runs on. Its answer is a report, never proof (1.5): the user's words, the anchor, this law and fresh evidence outrank it, and a clash is said in one line. No advisor tool is never an error: say so once, on the line that names the substrate, and decide alone with the same care. On Claude Code the advisor cue hook this setup installs puts this rule into every prompt, so it binds a session that never loaded this skill; it judges nothing and refuses nothing, because the tool list belongs to the session. The run points, the record that rides the tick and the line the deciding agents carry are 5.7.
- **A tick with no reflection is an untrusted tick, and a deferred write is no tick at all.** One line saying what changed and whether it passed, then flip the item, then open the next, in one saved edit. There is no later. In full mode the work-doc edit comes before the chat re-print; in Phase 3 the checkbox and the Daily Updates entry land together as each task closes; at the close, the one edit that writes `status: done` is followed immediately by the archive move. **In full mode the work-doc is the map and nothing overrides it:** the phase it shows open is the phase you are in, the task it lists next is the task you take, and a task is reordered by editing the doc first, with the reason written down. Nothing at the tool boundary enforces this; it holds because you hold it (7.3).
- **Every tick also goes out through the notification tool.** At every phase boundary and every stage end, right after the re-print, send the ledger heading and the one-line reflection as one line under 200 characters. The user may be away from the terminal, and this is the one step that reaches them there. The runtime drops the line when they are watching, which is never an error; a runtime with no notification tool says so once and carries on.
- **A check-in every ten minutes, not only at the boundaries.** Bring the work-doc up to date, print the three-line brief (doing, done, todo) in plain words, run the drift check (1.9), then carry on; a check-in never ends the work, and when work will keep running after your turn ends you start the recurring one before you stop. The protocol is 5.6.

### 1.7 [rule] Run discipline, how a task starts, advances, loops back and ends

**At task start, in this order, before any code.**

1. Classify the ask against Definitions: trivial, read-only or substantive. Say which in one line. A trivial ask ends here after the answer or the one-line edit.
2. Pick the route from the table below. State it and the mode in one line: *"Full mode."* or *"Quick mode, because you asked for it."*, then *"Agents on, the default."*, or *"Agents off, because you asked for it."* with the cost line 4.4 names when the user switched the default off.
3. Record the base commit: `git rev-parse HEAD`. Every touched-scope command in the task uses it.
4. Open the ledger with the items section 5.1 lists for the mode. Name the substrate once, and on the same line record agent availability (1.8) and whether the tool list holds an advisor (1.4, 5.7).
5. Read the Phase 1 reference (6.1) from disk, then follow it. Every phase begins by reading its own reference file; nothing runs from memory.
6. Detect the rules in play: the project's `CLAUDE.md`, `AGENTS.md` and documented layout, plus the user-global `CLAUDE.md`. Apply Precedence.

**At every phase boundary, in this order.**

1. Confirm the exit artifact for the closing phase exists (the table in 5.1). If it does not, the phase is not over.
2. One-line reflection: what changed, did it pass, what is next.
3. Tick the closing item and open the next, in one edit; in full mode edit the work-doc first, then re-print.
4. Send the heading line and the reflection through the notification tool (1.4), one line under 200 characters.
5. Read the next phase's reference file from disk.
6. Restate the anchor's North-Star Goal and its top Non-Goal in one line, so drift is visible.
7. **Re-anchor after context loss.** If the always-on law or this skill is no longer verbatim in your context, because the conversation was compacted or summarized, re-read `~/.claude/engineering-rules/law/engineering-law.md` and this skill before doing anything else in the new phase. A summary of the law is not the law. On Claude Code, the re-anchor hook this setup installs prints this instruction and the last ledger position into the new context after a compaction or a resume; the re-read is still yours to do.

**Loop-back, when a later phase sends you back.** A red in Phase 4, a Critical or Important finding in Phase 5, a red re-verify in Phase 6, or a task you cannot finish in Phase 3, sends you back to Phase 3 (or 3b when stuck). Re-open the earlier item as `- [>]` with `reopened: <reason>` appended, leave every later item open, and run forward again through every phase in between. Never patch and skip ahead. Every re-run of a phase produces fresh evidence; nothing from the earlier pass carries over as proof.

**User waivers, what the user may and may not switch off.** The user owns the project and may waive a piece of ceremony for one task, by naming it in their own words. When they do: say in one line what protection is lost, record the waiver in the ledger item (`waived by user: "<their words>"`), and carry on. Nothing else is waivable, whatever the wording: the hard caps and bans, claim integrity, the wizard tool for questions, the ship gate on a blocking leg, the fix of a Critical finding against this change, the scouts, the ledger itself, and git safety below. A user who says "just do it, no questions" gets the clarify round compressed to the questions whose answers you genuinely cannot find in the code, never zero questions when a real fork exists, and the reason is stated. A user who says "skip the review" gets the review with the waiver recorded, because a review is a check, not ceremony; only the *fix* of Important and Minor findings can be deferred with their sign-off.

**Git safety, in every phase.** Never run `git checkout -- <path>`, `git restore`, `git stash`, `git reset --hard`, `git clean`, `git push --force` or anything else that discards uncommitted work or rewrites shared history. Copy a file if you need a backup. Never `git add -A`, `git add .` or `git commit -a`; stage explicit paths. Never `--no-verify` unless the user explicitly said so. Never `--amend` after a hook failed. Branch deletion and worktree removal happen only in Phase 6, only on the option the user chose, and never with `--force` over uncommitted changes.

**The phase agents, and what stays in this session.** This session is the spine: it owns the anchor, the ledger, every question to the user, the verification it ticks on, and every claim it makes. Every phase's work goes out to the agent and the model 1.8's map names; the thinking that rests on it stays here. The standing authorization, the map, the record line and the refusal that backs them are 1.8. The six shapes, the return contract, the brief every non-fork agent carries and the runtime mapping are 5.5.

**Before the update log, the law self-audit.** Print this block filled in, in chat and in the work-doc when there is one. Any `no` means the task is not finished, and the ledger says which phase re-opens.

```
Law self-audit
1. Every phase ticked with its exit artifact, none deleted, skips reasoned?   yes / no
2. Every question to the user went through the wizard tool?                   yes / no
3. Every scout ran at every stage end and at Phase 5 start (the design scout too on UI-bearing work), every row dispositioned? yes / no
4. Evidence Ledger has a row per task and per acceptance bullet, all fresh?    yes / no
5. The three ship-gate rows are present, each ✅ or a reasoned skip?           yes / no
6. Phase 5 coverage ledger has a row per touched path, decision table empty?   yes / no
7. Touched scope has zero banned tokens, zero cap breaks, zero inline types?   yes / no
8. Every new file is placed and named per section 2.2?                         yes / no
9. No git command that discards work was run; no AI attribution in commits?    yes / no
10. Every claim in the update log has a proof row behind it?                   yes / no
11. Agent availability recorded once at task start, every phase's send made or reasoned? yes / no
12. Every agent result re-run here before the tick that rests on it?          yes / no
13. Every stage swept its own leftovers, nothing found on the way fixed (each filed as a follow-up), every new symbol's reuse search shown? yes / no
14. Phase 1 closed on a coverage map with no holes, the intent confirmed through Q0, every fact and recommendation tagged with a source from this session, none from memory? yes / no
15. Every phase ran on the agent and model 1.8's map names, or carries its reason? yes / no
16. The goal delivered and verified, every other finding filed as a follow-up, none silently fixed (1.9)? yes / no
17. Where this task deployed anything, the six proof rows and the live verify (1.11) are pasted? yes / no
18. Every file read whole where it was changed, every number counted this session, no claim resting on "should" (1.10)? yes / no
19. Every advisor run point (5.7) consulted where the tool list held one, or recorded as none, and no verdict written for a call never made? yes / no
```

**Never say.** "Should work", "looks good", "I believe this is fine", "tests should pass", "I'll add tests later", "probably", "you're absolutely right" before verifying, "done" before the ledger says so. Say what you ran and what it returned.

### 1.8 [rule] The phase agents, the standing authorization and the model map

**This skill asks for the agent tool. Read this paragraph as the permission it is.** A runtime whose
own rule is that the agent tool gets used only when the user, a project file or a skill asks for it
has been asked, here, in the always-on law, from the moment this skill loads. The permission is on
this line, it is not conditional on anyone repeating it, and no further invitation is coming; a
permission that lives in a reference you reach only after you already decided to delegate is a
permission that never arrives.

**Every phase runs as an agent, and that is the default.** This session stays the spine: it owns the
anchor, the ledger and every tick, every question to the user, the verification a tick rests on, the
gate, what gets committed, and every claim. The *work* of a phase goes out to the agent the map
below names, on the model that row names, carrying that shape's prompt from 5.5 pasted whole. Where
the runtime has no agent tool, or the user switched the default off (4.4, agentless), every row
collapses into this session: the same files are read, the same tables come back, the same commands
run with their output pasted, in the same order. Nothing is ever skipped because nobody could be
sent.

**The map. One row per run point, and the model is part of the row.**

| Run point | Shape (5.5) | Type | Model | Why this one |
|---|---|---|---|---|
| Phase 1, composing the question batch (6.1) | reader | `fork` | this session's, by construction | ~500 lines of contract, preamble, banks and map that would otherwise do your thinking for the rest of the task; a fork already holds the conversation, so a `model` on it is ignored |
| Phase 1, the repo brief and any wide search (6.13, 6.14) | reader | `Explore` | `sonnet` | a read-only sweep of the tree is search, not judgment |
| Phase 2, the plan, its stages and their order, written into the work-doc (7.1) | planner | `general-purpose` | `opus` | decomposition, ordering and contended resources are architecture decisions, and a wrong one is paid for in every later phase; the context that makes them is the one that writes them down, so this send holds an edit tool for exactly one path, the work-doc, and the session reads it back before the gate |
| Phase 2.5, the spec review (8.2), full mode | spec reviewer | `Plan` | `opus` | the context that wrote the plan cannot see its blind spots, and a defect caught here never reaches code |
| Phase 3, each implementation stage (9.1, 9.2), and every fix pass that loops back into one | builder | `general-purpose` | `sonnet` | writing code to a plan that opus already judged, inside a fixed allowlist, is what sonnet is fastest at |
| Phase 3 stage ends and Phase 5 start, the scouts (9.4, 9.5, 15.29 on UI-bearing work) | reader | `fork` | this session's, by construction | ~1000 lines, re-read at every single run point |
| Phase 3b, the hypothesis chain and the root cause (10.1) | planner | `Plan` | `opus` | a wrong root cause sends the next three hours the wrong way, and a tree full of half-finished work wants a planner that cannot touch it |
| Phase 4, every count, grep, coverage reconcile and planted-instance proof (11.1, 1.5) | mechanic | `general-purpose` | `sonnet` | raw output is the evidence, and producing it here spends the context that has to judge it |
| Phase 5, the five checks (12.3 to 12.7) | reviewer | `general-purpose` | `opus` | fresh eyes on a diff is the most expensive judgment in the task, and the context that wrote the diff cannot make it |
| Phase 6, the cleanup-sweep scans and the re-verify runs (13.2) | mechanic | `general-purpose` | `sonnet` | twelve mechanical scans whose output this session judges |

**The model is named on the send, every time but a fork.** `model: "sonnet"` or `model: "opus"` as
the row says, whatever model this session runs on. A fork inherits this conversation and this
session's model by construction and ignores a `model`, which is why the two reader rows differ. A
send naming no model, or a different one, is not the send this map asked for.

**Record the verdict once, at task start, on the line that names the ledger substrate:** `Agents:
on, the default; every phase runs on the map in 1.8.` after one probe of the runtime, `Agents:
unavailable, every phase runs in this session.` when that probe finds no agent tool, or `Agents:
off, by user choice; every phase runs in this session.` when the user switched the default off
(4.4). Never re-probe mid-task, and never carry a probe over from a previous task; the user's switch
holds for the whole conversation once given. That recorded line is the only thing the refusal below
accepts as an excuse, which is why it is written before it is needed rather than produced when it
would be convenient.

**The ledger refuses.** A phase whose agent was neither sent nor reasoned does not tick, however
green the work looks. The reason goes on the ledger item as `agent skipped: <reason>`, and exactly
three reasons are valid: the recorded `Agents: unavailable` or `Agents: off` line above, a user
waiver in their own words (1.7), or a send that was made and returned nothing usable, in which case
the reason says what came back. *"Faster on my own"*, *"the file is short"*, *"I already know what
it says"* and *"briefing it costs more than reading it"* are not reasons, and the last one is
answered by the fork needing no brief at all. A tick taken over a missing send is a false tick, and
1.5 governs false ticks.

**An agent's output is a report, never proof.** Re-run the check here before the tick that rests on
it. Send independent agents in one message so they run at once, wait for every one still running,
and never write a tick that depends on a result which has not arrived.

**What never leaves this session**, in short: the anchor, the ledger and every tick; every question
to the user and every answer; the verification a tick rests on; every scout disposition; the
decision on what gets fixed; the ship gate; the self-audit; the update log; and what gets staged and
committed. An agent asked to do one of these has been sent the wrong job, and its answer is not
usable even when it is right. The six shapes, the return contract, the brief and the runtime mapping
are 5.5, read before the first send and after a compaction.

## Picking the route

Every substantive prompt takes exactly one route. Pick it from what the user asked for, never from how large the task looks.

| Route | Sub-command | Right when | Section |
|---|---|---|---|
| **Full mode** | `/engineering-rules:full` | The default for any substantive prompt: every check, plus a written plan, a spec review and a work-doc. | 4.3 |
| **Quick mode** | `/engineering-rules:quick` | Only when the user asks for it by name. Keeps every check and drops three pieces of ceremony. | 4.2 |
| **Shaping** | `/engineering-rules:shape` | The idea is not a task yet. One or two forking questions per turn, graduating on the first build verb. | 16.1 |
| **Explore a feature** | `/engineering-rules:explore-feature` | Understanding how a feature runs, hop by hop, from one entry point to its leaves: a browsable page, every cited line verified. | 16.9 |
| **Codebase audit** | `/engineering-rules:audit` | Auditing a whole codebase against its rules. Not a per-diff review. | 16.3 |
| **Review triage** | `/engineering-rules:triage` | A batch of review findings needs a per-finding accept, push-back, defer or needs-restatement decision. | 16.2 |
| **Skill authoring** | `/engineering-rules:skill` | Writing a new reusable skill that has to pass structural checks. | 16.12 |
| **Design spec** | `/engineering-rules:design` | Authoring, extracting or refreshing the project's design spec. | 15.19 |
| **Update log** | `/engineering-rules:log` | Printing the plain-language summary of the current task, mid-flight. | 16.13 |

**Routing rules.**

- **Full is the default, quick is the floor.** Quick mode runs Clarify, Implement, Debug-when-stuck, Verify, the full five-check Review, and Finish. What it drops is the written plan, the spec review and the four-option landing menu. Never a check, never the ship gate, never the evidence rules, never the question contract.
- **No shape routes away from full.** A small diff, a one-file change or a familiar fix does not demote a task to quick. Only the user's words do. Offer quick mode in one line when a task looks like a five-minute fix; do not take it.
- **Quick mode is user-locked in both directions.** It starts when they name it and no other way; full never downgrades into it.
- **A read-only ask is not a route.** Answer it. The ledger opens the moment an edit is decided.
- **When two routes fit, say so and pick one.** State which and why in one line, then go.
- **A route that is not quick or full still obeys the always-on law**, including the wizard tool, claim integrity and git safety.
- **A sub-command outranks the classifier, never the law** (4.4). It picks the row and skips the classification in 4.1; it does not waive a phase, a check or a gate. Quick mode named by `/engineering-rules:quick` is named by the user, which is the one way quick mode ever starts.
- **`/engineering-rules:agents` is not a route.** Phase agents are the default (1.8); this sub-command is the switch that turns them off for the conversation (`off`) and back on again (4.4), and it combines with every row above.

## The map

Every section is a file in `~/.claude/engineering-rules/references/`. The number is the section id; "section 2.2" means the file whose name starts with `2.2`. The full per-section table is in `0.1`.

| Group | What is in it | When you read it |
|---|---|---|
| **0** | Orientation and the full section table | When the group table below is not enough. |
| **1** | Always-on law, 1.1 to 1.11 | The short form is in context through CLAUDE.md; 1.4, 1.7 and 1.8 are above; the long forms of the rest are group 1's files. |
| **2** | Doctrine: code quality (2.1), file and folder law (2.2) | Before writing code, and before creating any file or folder. |
| **3** | Catalogs: performance (3.1), security (3.2), test scenarios (3.3), clean code (3.4) | Look up an ID or a fix direction; never read end to end. |
| **4** | Routes: how one is picked (4.1), quick mode (4.2), full mode (4.3), the sub-commands, the intake and the agent modes (4.4) | At task start; 4.4 the moment the skill is invoked bare, a sub-command loads it, or the user switches the agents off or on. |
| **5** | Working references: the ledger (5.1), the goal anchor (5.2), voice (5.3), full mindset (5.4), the phase agents (5.5), the check-in (5.6), the advisor (5.7) | 5.1, 5.2, 5.6 and 5.7 at task start; 5.3 governs every chat line; 5.4 at Phase 1; 5.5 before the first send, and again after a compaction. |
| **6** | Phase 1, Clarify: the phase (6.1), the question contract (6.2), the banks (6.3–6.11), domain mechanisms (6.12), the repo brief (6.13), investigating code (6.14), the coverage map (6.15) | When a task opens. |
| **7** | Phase 2, Plan: the phase (7.1), the work-doc template (7.2), work-doc rules (7.3) | Full mode, when writing the plan. |
| **8** | Phase 2.5, Spec review (8.1, 8.2) | Full mode, after the plan is written. |
| **9** | Phase 3, Implement: the phase (9.1), implement and test (9.2), the checklist (9.3), the perf scout (9.4), the law scout (9.5) | While building. |
| **10** | Phase 3b, Debug when stuck (10.1) | Only when stuck twice on one symptom. |
| **11** | Phase 4, Verify: the phase (11.1), in detail (11.2), the ship gate (11.3), cross-package (11.4) | When proving the change works. |
| **12** | Phase 5, Review: the phase (12.1), coverage (12.2), the five checks (12.3–12.7), challenge (12.8), merge and escalate (12.9) | When reviewing the diff. |
| **13** | Phase 6, Finish: the phase (13.1), in detail (13.2) | When closing out. |
| **14** | Anti-patterns, seven worked examples (14.1) | Phase 3, and whenever an approach feels grand. |
| **15** | Design: the visual law (15.1), the spec package (15.2), the contract (15.3), the direction library (15.4), extract (15.5), picking a spec (15.6), twelve directions (15.7–15.18), authoring (15.19), the read and the dials (15.20), the design-system map (15.21), page composition (15.22), copy and imagery (15.23), the AI-tell catalog (15.24), motion (15.25), implementation guardrails (15.26), the pattern vocabulary (15.27), the redesign protocol (15.28), the design scout (15.29), the pre-flight (15.30), image-first and brand work (15.31) | Any UI-bearing work, from Phase 1. |
| **16** | Other routes: shaping (16.1), triage (16.2), audit (16.3–16.8), explore-feature (16.9–16.11), skill authoring (16.12), update log (16.13) | When the route table sends you there. |
| **17** | Twelve ready-made design specs (17.1–17.12) | Starting a design spec fresh. A droppable appendix; nothing depends on it. |
