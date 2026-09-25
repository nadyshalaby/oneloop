---
name: engineering-rules:workflow
argument-hint: "[what you want done]"
description: >-
  The engineering-rules workflow: plan, implement, verify and deploy, with its ledger, work-doc,
  helpers and routes. Use it only when the user names the engineering-rules workflow or a
  /engineering-rules: command loads it; an everyday word such as build, audit or triage alone
  never starts it.
---

# Engineering rules: the workflow

> On top of the always-on law, this skill binds until the task is done. A reference is read only
> where this page names it, and binds once read. **How** is your call; **what** must be true, in
> what order and with what evidence, is not.

- **Whole invocation:** `$ARGUMENTS`

Bare, with no request anywhere in the conversation, ask through `AskUserQuestion` what they want
done (and which route), and nothing else. A trivial ask (the law's definition) ends after the
answer or the one-line edit.

## The ledger

Three items, in order, one open at a time, none silently dropped: `1 Plan`, `2 Implement`,
`3 Verify & Deploy`. Load the task tools once (`TaskCreate`, `TaskList`, `TaskUpdate`, `TaskGet`) and
print the ledger at the start, at every phase boundary and after each task's commit:

```
## 0. Phase ledger  (2 of 3, Implement)
- [x] 1 Plan  (<one-line reflection, or: skipped, <what covers it>>)
- [>] 2 Implement
- [ ] 3 Verify & Deploy
```

The first print adds one line: `Helpers: on | unavailable. Advisor: yes | no.` A tick
carries a one-line reflection (what changed, did it pass, what is next) and lands in the work-doc
before the chat re-print; a deferred write is no tick. After each re-print, one `PushNotification`
line under 200 characters. At each boundary, restate the goal in one line and run the drift check.
After context loss, re-read the law, the code rules, this skill and the in-flight work-doc before
the next step; nothing from before is proof.

## Skip what is done or fully known

A phase ticks as `skipped` with one line naming what covers it, only in these cases:

- **Resume.** An in-flight `docs/work/*.md` (not `done/`) matches this goal (two could: ask). It
  still holds when its `base` commit exists, every commit its Log names is an ancestor of `HEAD`,
  and `git status` shows nothing it does not explain. Plan is skipped (the doc is the plan) and
  Implement resumes at `next`; a task whose commit is gone is reopened. A doc at the live path with
  `status: done`, or one under `done/` with an open box, is a session that died mid-close: finish
  the step it died in.
- **Fully known.** The user's own message gives the goal, the done-when checks and the steps: Plan
  takes the work-doc from their words, with no exploration and no question but the logic gate, and
  the advisor still checks it unless every task is their words verbatim.
- **The logic gate never skips.** A skipped Plan still shows the logic and waits for the yes,
  unless the work-doc's `Logic confirmed:` line holds the user's yes to this same logic.
- **Verify & Deploy never skips a check;** only a review of an unchanged diff (`git rev-parse HEAD`
  equal to the reviewed commit, a clean `git status`) is reused.

## 1 Plan

1. Record the base (`git rev-parse HEAD`) and the branch. Read the project's `CLAUDE.md`, `AGENTS.md`
   and layout. Run the resume check above.
2. Restate the goal in one line: who it is for, what changes, what is left out. When the ask reads
   two ways, the first question confirms which; otherwise no confirmation is asked.
3. Read what the goal touches, whole: the files, their tests, the closest existing example, the
   triad's commands. A wide sweep of an unfamiliar tree goes to one `er-reader`. UI-bearing work
   reads 15.1 first. A bug fix runs 10.1's root-cause investigation (D1) by reading only, before
   any task is drafted; its reproduction and boundary logging wait for the logic gate's yes.
4. **Coverage, one line:** each aspect the task touches (value, actors, entry points, inputs, happy
   path, states, data, failures, integrations, security, volume, observability, rollout, surfaces,
   tests, operations) and what settles it: the ask, a `file:line`, or a question. None left open. A
   task touching the lane's risk list (step 7) walks 6.15's full map per deliverable before step 5.
5. **Questions:** one `AskUserQuestion` batch, only for forks the code and the ask cannot settle;
   an unfamiliar domain borrows its bank from 6.3 to 6.11.
6. Draft the Done-when checks and Plan tasks, each with `→ verify: <command>` and the files it may
   touch. Each thing that must not change is a Done-when check too; one no command can check
   names the file to read and what to confirm.
7. **Lane:** `bash ~/.claude/engineering-rules/scripts/lane.sh --test "<the test command>" <every
   file the tasks name>`, and one plan line: touches no money, auth, state machine, migration,
   concurrency or data-loss code, and does not deploy. `lane: fast` with that line honestly true
   and at most three checks and three tasks is the fast lane (one Goal line, the review done here);
   anything else, or a work-doc with no `Lane:` line, is the careful lane. Then
   the advisor checks the plan.
8. **Logic gate (law 1.4):** show the logic with the `explain` skill and ask through
   `AskUserQuestion`; nothing is written or changed before the yes. Then, on the default branch,
   make a task branch (`<type>/<slug>`) and say so (a worktree inside the project only in a folder
   `git check-ignore` confirms is ignored), and write the work-doc (below), the user's answer in
   its `Logic confirmed:` line. **Exit:** the work-doc with Goal, Done when and Plan, said in chat
   in two lines.

**The work-doc**, `docs/work/<YYYY-MM-DD>-<slug>.md`, written once after the yes, then only edited
(ticks, one Log line per task, `status`, `next`); it holds project-relative paths, never a secret,
token, credential or customer data:

```
---
status: plan | implement | verify | done
base: <sha>
branch: <branch>
next: <the step to take next>
---
# <the goal in a few words>
## Goal
<one line: who it is for, what changes, what is left out>
Lane: <the line lane.sh printed>. Logic confirmed: <the user's answer>
## Done when
- [ ] <observable check> → verify: `<command>`
## Plan
- [ ] 1. <task> (files: <paths>) → verify: `<command>`
## Log
- <task>: <what changed, the check's result line, commit>
## Evidence
- <check>: `<command>` → <its result line>
## Follow-ups
- `<file:line>` <what is wrong> (<present at base | seen on the way>)
```

## 2 Implement

For each task, in order:

1. Read 2.3 only before creating a source or test file or a folder (the work-doc's place is fixed).
2. The reuse search (the code rules), pasted; reuse or extend what exists.
3. Where the project has tests, write the test first and watch it fail for the right reason; that
   red run is the planted instance, and no other control is built.
4. Make the smallest change that meets the task, with its edges handled: empty, one, many, absent,
   malformed, duplicate, unauthorized, the error path.
5. Run the task's verify command fresh, then `bash ~/.claude/engineering-rules/scripts/scout.sh <base>`
   (it reads the working tree, committed or not; its `self-check:` line is its own planted
   instance). Every `introduced` row is fixed now, or dismissed with a one-line reason tied to
   that row's guard (a perf row is a candidate, not a verdict); a Critical perf or design row, a
   secret or a row you doubt is never dismissed here: it goes to the Evidence as `staged`, for the
   review to judge (9.4, 9.5, 15.29); every `present at base` row goes to Follow-ups as the scout
   summarises it; its `not run:` lines go to the review.
6. Sweep your own leftovers (debug lines, commented-out code, orphans, scratch files).
7. Tick the task with its proof line, one Log line, commit, update `next`.

**Stuck twice on one symptom:** stop editing; read 10.1, then 10.2. Write the hypotheses, test
the cheapest first, confirm the root cause from evidence (10.1), then a regression test, then the
fix. **Exit:** every Plan box ticked with a fresh proof line, the scout clean or every row
disposed, every task committed.

## 3 Verify & Deploy

1. **Prove it, fresh, on the exact commit** (the committed tree with a clean `git status`; a clean
   export only when deploying): the triad (a test run that ran zero tests is a fail); every
   Done-when check; the ship gate (rows `ship.build`, `ship.boot`, `ship.smoke`, each run or
   carrying its skip reason: a diff of only tests, docs, comments, CI config (pipeline files only;
   env, build and startup config always read 11.3) or editor settings skips all three without
   reading 11.3; otherwise read 11.3 when the manifest has a build or start script or the task
   deploys); on UI-bearing work the design pre-flight (15.30). One Evidence line each,
   `command → result line`, and one line on what the checks did not reach; no probe or control
   the plan did not name.
2. **Review,** for every diff that changes behaviour or carries a `staged` scout row: careful lane,
   one `er-reviewer` over `git diff <base>..HEAD`, handed the Evidence lines and the scout's
   `not run:` lines; fast lane or helpers unavailable, the same review here, from
   `~/.claude/agents/er-reviewer.md`. A broken must-not-change check is Critical.
3. **Challenge, then decide:** a finding stands unless a `file:line` refutes it (doubt is not a
   refutation; a Critical one needs both reproduction and authority to fail, 12.8). Consult the
   advisor, then decide each: accept, push back with the citation, defer with the user's say, or
   needs restatement. A Critical finding is never deferred or pushed back on your own judgment.
4. **One fix pass:** accepted `introduced` findings reopen Implement (`- [>] 2 Implement  reopened:
   <finding>`), are fixed there and re-verified fresh. One review, one fix pass: the fix gets the
   triad and the checks it touches, not a second review.
5. **Cleanup sweep** over your own changes, one line each with its count, zero included: debug
   output; commented-out code and `removed:` markers; ownerless TODOs; dead code both ways; unused
   imports, dependencies and env vars; scratch files and empty dirs; placeholders and stubs;
   changes outside the plan's files; stale references to what you renamed or removed; leaked
   processes and ports; branches you made; focused or skipped tests (13.2). Anything that was
   already there is a follow-up.
6. **Land** (13.2's rules): commit; when there is a choice (merge, a pull request, keep the
   branch), ask through `AskUserQuestion`. **Deploy** only when the task deploys (law 1.11).
7. **Close:** print the self-audit below; any `no` reopens the phase that owns it. Print the
   release notes in plain words (what changed and why, the proof behind every claim, the
   follow-ups, how to undo it). Write `status: done`, then at once `git mv` the work-doc into
   `docs/work/done/`; tick the ledger.

```
Law self-audit (yes / no each)
1. Phases ticked with their exit, skips reasoned, the logic confirmed first, questions only through AskUserQuestion?
2. A fresh Evidence row per task and per Done-when check; ship-gate rows present?
3. The scout run after every task, every row disposed?
4. Review: a row per touched path, every finding challenged and decided, Critical fixed?
5. Zero banned tokens, cap breaks or inline types in the touched scope; files per 2.2?
6. Nothing found on the way fixed; every follow-up filed with its file:line?
7. Own leftovers swept, reuse searches shown, files read whole, numbers counted?
8. No git command that discards work; explicit staging; no AI attribution?
9. Helper results re-run before their ticks; the advisor at plan, review, direction, done?
10. Where anything deployed, the six proofs and the live check pasted?
```

## Helpers, and what never leaves this session

Three custom agents, each with its own model and turn cap, and nothing else is sent (no fork, no
built-in type): `er-reader` (read-only, a wide sweep), `er-builder` (one per task when two or more
are independent, all sent in one message, each brief at most fifteen lines: the task, its files,
its verify command, the base, the confirmed logic) and `er-reviewer` (read-only, the review). A
brief never carries a secret, token, credential or customer data. Where the agent tool is missing,
their work runs here, from the same files. This session keeps the ledger and every tick, question,
verification, fix decision, commit, gate, self-audit and claim.

**Loop-back:** a red in Verify, an accepted Critical or Important finding, or a task you cannot finish
reopens Implement; run forward again with fresh evidence. **Waivers** are the law's; a blocking
ship-gate leg and the review are never waived either.

## Routes

| Route | Command | Right when | Section |
|---|---|---|---|
| **Brainstorm** | `/engineering-rules:brainstorm` | The idea is not a task yet. | 16.1 |
| **Codebase audit** | `/engineering-rules:audit` | A whole codebase against its rules, not one diff. | 16.3 |
| **Review triage** | `/engineering-rules:triage` | A batch of review findings to decide. | 16.2 |
| **Design spec** | `/engineering-rules:design-spec` | Authoring, extracting or refreshing the design spec. | 15.19 |
| **Release notes** | `/engineering-rules:release-notes` | The plain summary of the task in flight. | 16.13 |

