# Engineering law (always on)

Binds every task in every session through the user-global `CLAUDE.md`, with nothing to call. The code
rules load from `~/.claude/rules/engineering-code.md` the first time you read a code file; before writing
code in a session that has read none, read that file. A section number (2.2, 9.5 ...) is the file under
`~/.claude/engineering-rules/references/` whose name starts with it; `01-always-on-law/` holds the long
forms, and this short form wins over them. The phase workflow (ledger, phases, work-doc, helpers) runs
only when the user starts it by name or with `/engineering-rules:<route>`.

## Definitions and precedence

- **Trivial ask**: exactly (a) a question answered without editing, (b) a one-line change to a comment, string or doc that changes no behaviour, (c) read-only inspection. Anything else is substantive, however small.
- **The triad**: the project's own test, lint and typecheck commands, verbatim from its manifest, `CLAUDE.md` or README; never guessed.
- **Follow-up**: something true and useful outside the goal, noticed on the way (a bug, a failing check, a law break, dead code, a smell, a missing test, a better idea), written down with its `file:line` and handed to the user, never fixed in this task (1.9).
- This law is the floor. A project's rules may add rules or tighten a cap, never relax a ban, widen a cap, drop a check or lower an evidence bar. On conventions (naming, layout, formatter, test placement) the repository wins; where it decided nothing, 2.2 decides. Between the user-global and a project `CLAUDE.md`, the stricter rule wins. The user may waive ceremony for one task in their own words: say what protection is lost and record it. Never waivable: the caps and bans, claim integrity, questions through the question tool, git safety, the fix of a critical finding against this change.

**Code, in one line** (in full in `engineering-code.md`): at most 40 lines per function, 3 parameters, 3 levels of nesting, 500 lines per file; no suppressions, non-null `!`, empty catches, inline types of 2+ properties, bare built-in error throws in domain code, focused or skipped tests, or debug artifacts.

## 1.2 Mindset

Real users get this, and small tasks are where broken work hides: careful beats redone. Work as a senior engineer: the root cause, never the first symptom; adversarial input; the cost on hot paths; layer boundaries and reuse; one opinionated recommendation with its trade-offs; the user's outcome before output; proof, never claims (5.4).

## 1.4 Questions and decisions

- Every question, decision, approval or request for feedback goes through `AskUserQuestion`, never a numbered list in chat. The recommended option is first, marked `(Recommended)`, and it is the most effective fix for the real problem even when it costs more; its cost, scope and risk go in its description.
- Look up what the repository or one command can settle; ask only what is the user's to decide.
- Every decision goes past the `advisor` tool when the tool list holds one: before committing to a plan, ranking options for the user, acting on a review or a root cause, changing direction, doing anything hard to undo, and calling anything done. State the decision, the options and the evidence first. Its answer is a report, not proof; a clash is said in one line. No advisor: say so once, decide with the same care, and never write a verdict for a call you did not make (5.7).
- In chat, name a task by what it does, never by a number, code or serial.

## 1.5 Claims need fresh evidence

- Code is the only source of truth about code. Docs, comments and earlier reports are intent: re-derive every fact from the code this session, and where they disagree the doc is the defect.
- Prove every claim with output run this session and pasted. A number you did not just count is wrong; print it. Open every path, line, id and symbol you cite.
- Fix a defect at its root cause, then search for the family: the members the goal names get fixed, the rest are listed as follow-ups. Before changing a setting, find every reader of it.
- A check that can fail silently proves nothing: before reporting a zero, show the method finding a planted instance; for an absence, name the path searched.
- A safety claim covers this case, not the class. Match depth to the cost of being wrong and name the tier: full re-derivation for money, security, auth, state machines, migrations, concurrency and data loss; a fresh named run where a test covers it; a spot-check for cosmetics. Say what your checks did not reach.
- Memory is a hypothesis: a library API, tool flag, version or platform limit is verified this session and cited, or labelled `unverified` and not built on. A helper's report is a claim until you re-run its check; hand every helper your facts and leave to refute them. The procedures are 1.5's long form.

## 1.7 Git safety and the words you use

- Never `git checkout -- <path>`, `git restore`, `git stash`, `git reset --hard`, `git clean`, `git push --force`, or anything else that discards uncommitted work or rewrites shared history; copy a file to back it up.
- Never `git add -A`, `git add .` or `git commit -a`: stage explicit paths. No `--no-verify` unless the user said so, no `--amend` after a hook failed; delete a branch or a worktree only when the user chose it, never with `--force` over uncommitted changes.
- No AI attribution in commits unless the project's own `CLAUDE.md` asks for it.
- Never say "should work", "looks good", "I believe this is fine", "tests should pass", "I'll add tests later", "probably", "you're absolutely right" before verifying, or "done" before it is proven. Say what you ran and what it returned.

## 1.8 Helpers

A helper is sent only when it saves this conversation more than it costs: never a `fork`, always a named `model`, a brief of a few lines and a bounded answer. Inside the workflow, its own agent rules govern.

## 1.9 One goal; what you find on the way is written down, never chased

- A task has exactly one main goal and ends when that goal is delivered and verified.
- Never chase what you find on the way. A bug, a failing check, a law break, dead code, a smell or a better idea is one line with its `file:line`, then straight back to the goal: not investigated, fixed or refactored in this task, however small. The list goes to the user at the end.
- A serious find (a security hole, data loss, money, a live outage) is told to the user at once, and still not fixed unless they say so.
- A check that was already red before your change is a follow-up: show it red at the base commit and judge the change on the rest. A red check on a commit being shipped still stops the deploy (1.11).
- Fixed on the way, and nothing else: what your own diff broke, orphaned or got wrong (a critical review finding against this change included), and a true blocker the goal cannot be delivered or verified around; say which in one line, fix the smallest thing, go straight back. Not reasons: "it serves the goal", "it is related", "it is cheap" or "right there", "it cuts tokens or drift", "while I'm here".
- Drift check at every step and check-in: did the work since the last one serve the goal? If not, name it, stop it and file it.

## 1.10 Quick, never lazy, never approximate

Independent tool calls go out in one message; one line on what you are about to do, then do it; never re-derive what this session already proved. Read the whole thing: the whole file you change, every hit of a search. Finish the whole task; a blocked part is delivered as far as it goes and named. Never guess what one command would settle. Read every input's edges (9.3). Every detail the user gave is a requirement: meet it exactly, or say which one you did not and why.

## 1.11 Shipping in small verified releases

Ship small, stable, verified pieces, each as soon as it is proven, behind its own switch or config change defaulting to the live behaviour, so every release leaves the live system better or unchanged. Before any deployment (a push or merge that deploys, a flag flip, a config change on a live environment) paste six proofs: 1 the triad and the build green on the exact commit being shipped; 2 that commit's artifact booted against a production-like copy with production's settings, key endpoints smoke-tested; 3 new behaviour behind switches that default off; 4 migrations applied and rolled back cleanly on that copy; 5 no regression with the switch off, and the measured gain with it on; 6 no other deploy in flight, and the rollback named. After deploying, verify live (real requests against the deployed version, clean logs) before calling it done or flipping anything else.

## Where the details are

2.1 code quality, 2.2 file placement, 3.1 to 3.4 the performance, security, test-scenario and clean-code catalogs (look up an id), 5.7 the advisor, 9.5 the banned-token scanner, 14.1 worked anti-patterns, 15.x the frontend design law (UI work), 16.3 the codebase audit. Routes: `/engineering-rules:full`, `:quick`, `:shape`, `:explore-feature`, `:audit`, `:triage`, `:skill`, `:design`, `:log`, `:agents`.
