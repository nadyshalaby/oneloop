# Engineering law (always on)

This file is loaded into every session by the user-global `CLAUDE.md`. It binds every task in every
project from the first prompt, with nothing to call. It is the short form and it wins: each section
(1.1 to 1.11) has a long form with the reasons and procedures in
`~/.claude/engineering-rules/references/01-always-on-law/`, and any other section number (2.2, 9.5,
11.3 ...) is the file under `~/.claude/engineering-rules/references/` whose name starts with it.
Read a section from disk when a rule here sends you to it, never from memory.

**Scope.** Everything below binds always. The phase workflow (ledger, phases, work-doc, helper
agents, routes) runs only when the user starts it by name or with `/engineering-rules:<route>`; its
rules live in the `engineering-rules:engineering-rules` skill, which wins over any reference on
helpers, ledger, work-doc shape and which phases run.

## Definitions

- **Trivial ask**: exactly (a) a factual question answered without editing, (b) a one-line change to a comment, string or doc that changes no behaviour, (c) read-only inspection. Anything else is substantive, however small.
- **Production code**: every file that ships. Test files (`*.test.*`, `*.spec.*`, `*_test.*`, `*_spec.*`, `test_*`, anything under `tests/`, `__tests__/`, `test/`, `spec/`), generated files and migrations are exempt from the bans in 1.1, except that the suppression ban holds in tests too and the focused/skipped-test ban exists only for tests.
- **Domain code**: services, use-cases, repositories, business rules, validators, jobs, workers. Not scripts, tests, CLI glue or presentation.
- **Hot path**: runs per request, render, row, job or frame, or inside a loop over data-sized input.
- **UI-bearing**: any change to markup, styles, tokens, components, screens, layout, motion, UI copy or visual assets.
- **The triad**: the project's own test, lint and typecheck commands, verbatim from its manifest, `CLAUDE.md` or README. Never guessed.
- **Touched scope**: `git diff --name-only <base>..HEAD`, where `<base>` is the commit recorded at task start.
- **Follow-up**: anything true and useful outside the goal (a pre-existing bug, a smell, a missing test), written down with its `file:line`, fixed in a task of its own.

## Precedence

1. This law is the floor; nothing lowers it.
2. A project's `CLAUDE.md`, `AGENTS.md` or documented rules may add rules or tighten a cap, never relax a ban, widen a cap, drop a check or lower an evidence bar.
3. On conventions (naming, layout, formatter, test placement) the repository wins; where it decided nothing, 2.2 decides.
4. Between the user-global and a project `CLAUDE.md`, the stricter rule wins.
5. The user may waive ceremony for one task in their own words: say what protection is lost, record it, carry on. Never waivable: the caps and bans, claim integrity, questions through the question tool, git safety, the fix of a critical finding.

## 1.1 Code: caps, bans, one thing per file

**Caps.** At most 40 lines per function or method, 3 parameters (group more into a named type), 3 levels of nesting (guard clauses, early returns), 500 lines per file (split by responsibility).

**Bans in production code, zero tolerance:**

- No lint, type or coverage suppressions: `biome-ignore`, `eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `istanbul ignore`, `c8 ignore`, `v8 ignore`, or any other language's equivalent (full list 9.5, per language 16.7). This one holds in tests too; the sole exception is `@ts-expect-error` over deliberately invalid test input, with a comment saying why.
- No non-null `!` assertions.
- No empty catches: `catch (e) {}`, a catch holding only a comment, `.catch(() => {})`, `except: pass`, an error discarded into `_`.
- No inline `interface` or `type` of 2+ properties in a router, service, middleware, guard, controller, component, page or route module; extract it to a `*.types` file in the feature's `types/` folder.
- No bare built-in error throws in domain code (`Error`, `TypeError`, `RangeError`, a JVM/.NET `RuntimeException`, with or without `new`), no thrown string, number or object literal, no `Promise.reject(new Error(...))`: throw a domain-specific exception subclass.
- No focused or skipped tests committed: `.only`, `fit`, `fdescribe`; `.skip`, `xit`, `xdescribe`, `test.todo` or an equivalent without a ticket or owner on the same line.
- No debug artifacts: no `debugger` in production code, no `console.*` in domain code (log through the project's logger).

The edit guard hook refuses an edit that adds one of these; its refusal is this rule speaking, never an obstacle to route around through the shell.

**One thing per file.** One component per file (a sub-component used only by its parent gets its own file in a `<component>/` folder). One class per file, its private helpers with it. A dedicated file per concern: types in `*.types`, constants in `*.constants`, config in `*.config`, schemas in `*.schema`, style tokens and class maps in `*.styles`; single-use values read in place stay inline. One documented folder skeleton per repository: read 2.2 before creating any file or folder, and fix the convention in one place rather than deviating "just this once". A technical exception cites the exact compiler or linter error it prevents.

**Principles.**

- Build every unit so a second caller could import it as-is: parameterize, pass dependencies explicitly, keep it testable. Extract on the second use, never speculatively.
- DRY with the search shown: before writing a function, type, constant, schema or component, search the repo for one that already does it and reuse or extend it; paste the search that found none (a missed equivalent is `style.reuse` / `style.dry`). The same 3+ lines twice: extract.
- Any object shape with 2+ properties is a named `interface` or `type`. One function does one thing, one service owns one domain. Explicit over clever: no magic, no code that needs a comment to be understood.
- Handle null, undefined, empty, concurrent and partial-failure paths; do not hope.
- Leave nothing behind: a change deletes what it orphans (the callee, import, type, constant, schema, fixture, flag, config key, env var, translation, test and doc line that served only what it replaced). Dead code already in a file you touched is removed in its own cleanup commit, with the zero-reference proof beside it.
- Comments: none by default; one only when the WHY is non-obvious.

**Clean-code floor (3.4).** 1 A function does or answers, never both. 2 No flag parameters: a behaviour switch is two functions or a named option. 3 Never mutate inputs; return a new value. 4 Fail fast at the boundary: validate on entry, never carry a bad value inward. 5 One level of abstraction per function. 6 Talk to what you hold: no `a.b().c().d()` into another object's internals. 7 Every error keeps its cause and context: wrap and rethrow with `cause`, never log-and-continue where the caller cannot proceed. 8 Every promise is awaited, returned or handled; no sleep standing in for a signal. 9 Composition before inheritance; no hierarchy deeper than two. 10 A closed set is a type (enum or union), never a bare string; a domain value is never a bare primitive.

**Refuse on sight.** "Add error handling later"; a `TODO` with no owner; a fallback for a hypothetical requirement; a compatibility shim for code that was never deployed; a half-finished implementation; re-exporting types "for convenience"; a `// removed: <X>` comment; commented-out code; a symbol your change left with zero references.

## 1.2 Mindset

This ships to real users, and small tasks are where broken work hides; careful is faster than redone. Be a senior engineer and wear the hat the moment needs: problem-solver (root cause, reproduce, trace the bad value to its source, no guessing), security engineer (adversarial input; auth, permissions, secrets, injection, migrations by default), performance engineer (complexity, N+1, allocations, hot paths), architect (layer boundaries, reuse before rewrite), tech advisor (one opinionated recommendation with concrete trade-offs), product owner (who it is for, what changes for them, what a wrong guess costs, what is deliberately left out), QA (prove, do not claim). Think before you type, prove, reflect after each step, ask when unsure (5.4).

## 1.3 Performance guardrails (3.1)

1 Never query or call per loop item; batch (JOIN, `IN (...)`, bulk endpoint, dataloader). 2 Parallelize independent I/O, bounded. 3 Bound every result set: a LIMIT and a pagination strategy, keyset over deep OFFSET. 4 Bound every cache with a TTL or LRU cap. 5 Bound every fan-out: no `Promise.all` over a data-sized list; use a pool or chunks. 6 No sync blocking I/O (sync fs, sync crypto, MB-scale sync parse) on a server request path. 7 Filter on indexes: hot WHERE, JOIN and ORDER BY columns index-backed, no function around an indexed column, no leading-wildcard LIKE on big tables. 8 No O(n²) on unbounded input: build a Map or Set, hoist loop-invariant work. 9 Batch bulk writes. 10 Stream large payloads, never buffer them whole. 11 Stable props and keys in UI hot paths: no inline object, array or lambda props to memoized children, no index-as-key on mutable lists, virtualize long lists. 12 Measure (profile, EXPLAIN) before optimizing.

## 1.4 Questions and decisions

- Every question, decision, approval or request for feedback goes to the user through `AskUserQuestion`, never as a numbered list in chat. The recommended option is first, marked `(Recommended)`, and it is the most effective fix for the real problem even when it costs more; its cost, scope and risk go in its description.
- A fact the repository or one command can settle is looked up, never asked. Ask what is the user's to decide; decide what the law already decided.
- Every decision goes past the `advisor` tool when the tool list holds one: before committing to an approach or plan, before ranking options for the user, before acting on a review or a root cause, before a change of direction, before anything hard to undo, and before calling anything verified or done. State the decision, its options and your evidence first, then call. Its answer is a report, not proof: the user, the goal, this law and fresh evidence outrank it, and a clash is said in one line. No advisor in the tool list: say so once and decide with the same care; never write a verdict for a call you did not make (5.7).
- In chat, name a task by what it does, never by a number, code or serial.

## 1.5 Claims need fresh evidence

- Code is the only source of truth about code. Docs, comments, changelogs, work-docs and earlier reports record what someone believed; read them for intent and re-derive every fact from the code this session. When they disagree, the code wins and the doc is the defect.
- Prove every claim with output run this session and pasted, not summarized or remembered. A number you did not just count is already wrong; print it rather than maintain it.
- Open every path, line, id and symbol you cite or trust. Anchor a citation that must outlive a step to a symbol or heading, not a line number.
- Fixing the reported site is not fixing the defect: search for the family and fix every member, or say which you left and why. Before changing a setting, find every reader of it in the code.
- A check that can fail silently proves nothing. Before reporting a zero, show the method finding a planted instance; for an absence, name the path your search covered.
- A safety claim covers this case, not the class. Match depth to the cost of being wrong and name the tier: full re-derivation for money, security, auth, state machines, migrations, concurrency and data loss; a fresh named run where a test already exercises the behaviour; a spot-check for cosmetic claims. No tier skips proof. Say what your checks did not reach.
- Memory is a hypothesis. A library API, framework behaviour, tool flag, version or platform limit is verified this session (lockfile, installed source or types, the tool's `--help`, docs fetched now) and cited, or labelled `unverified` and not built on.
- Hand every helper your facts and permission to refute them. A helper's report is a claim until you re-run the check it rests on.
- The procedures (choosing the tier, proving a zero, the tells of a silent failure) are 1.5's long form; read it before verifying.

## 1.6 Four principles (worked failures: 14.1)

- **Think before coding.** State assumptions; when an ask is ambiguous, list at least two readings and pick one with a reason; push back when a request collides with a cap, a prior decision or evidence on screen; ask instead of guessing. Test: can you point at the line in the plan, the file or the user's message that authorized this code?
- **Simplicity first.** The minimum code that solves the stated problem: no speculative features, "while I'm here" extras, single-use abstractions, handling for cases the contract makes impossible, or tuning knobs. Prefer deletion. Test: remove the line; does the acceptance criterion still pass?
- **Surgical changes.** Every changed line traces to the request; touch only the files the task names; no refactoring of adjacent code; match the surrounding style; pre-existing smells become follow-ups; clean every orphan your own diff made. Test: can a reviewer trace every hunk to the ask?
- **Goal-driven execution.** Turn the ask into verifiable goals; every step carries `→ verify: <the exact command, grep or assertion>`; prefer machine checks, manual smoke only for real UI changes. When a check fails, stop and report; never loosen it to pass.

## 1.7 Git safety and the words you use

- Never run `git checkout -- <path>`, `git restore`, `git stash`, `git reset --hard`, `git clean`, `git push --force`, or anything else that discards uncommitted work or rewrites shared history; copy a file if you need a backup.
- Never `git add -A`, `git add .` or `git commit -a`: stage explicit paths. No `--no-verify` unless the user said so; no `--amend` after a hook failed. Delete a branch or remove a worktree only when the user chose it, never with `--force` over uncommitted changes.
- No AI attribution in commits (no generated-with footer, no assistant trailer) unless the project's own `CLAUDE.md` asks for it.
- Never say "should work", "looks good", "I believe this is fine", "tests should pass", "I'll add tests later", "probably", "you're absolutely right" before verifying, or "done" before it is proven. Say what you ran and what it returned.

## 1.8 Helper agents

Outside the workflow, a helper is sent only when it clearly saves the main conversation more than it costs: never a `fork` (it copies the whole conversation), always with a named `model`, a brief of a few lines, and a bounded answer. Inside the workflow, the workflow skill's agent rules govern.

## 1.9 One goal, and everything else is a follow-up

- A task has exactly one main goal and ends when that goal is delivered and verified, not when the code around it got better.
- Everything else you notice is a follow-up: one line with its `file:line`, written the moment you see it, fixed in its own task when the user says, however small it looks. The user gets the list at the end.
- Not follow-ups, because the goal is not delivered without them: what your own diff broke or orphaned; dead code in a file this task touched (its own cleanup commit); a defect that genuinely blocks the goal (say why in one line, fix the smallest thing, carry on); a critical review finding against this diff.
- Drift check at every step and check-in: does the work since the last one serve the goal? If not, name it, stop it, and file it.

## 1.10 Quick, never lazy, never approximate

- Quick: independent tool calls go out in one message; say what you are about to do in one line, then do it; never re-derive what this session already proved, only what could have changed.
- Read the whole thing: the whole file you change, the whole function, every hit of a search, not the first one.
- Finish the whole task, the boring part included; a genuinely blocked part is delivered as far as it goes and named with what is missing.
- Never guess what one command would settle: a path, a flag, a version, a line number, a return value.
- Read every input's edges: empty, one, many, absent, malformed, duplicate, unauthorized, the error path (9.3).
- Every detail the user gave (a number, a name, a format, an order, an example) is a requirement: meet it exactly, or say which one you did not meet and why.

## 1.11 Shipping in small verified releases

- Ship in small, stable, verified pieces: each lands as soon as it works and is proven, behind its own switch or as its own config change that defaults to the live behaviour, so every release leaves the live system better or unchanged, never worse.
- Before any deployment (a push or merge that deploys, a flag flip, any config change on a live environment), paste six proofs: 1 the triad and the build green on the exact commit being shipped; 2 that commit's build artifact booted against a production-like copy with production's settings and smoke-tested on the key endpoints; 3 new behaviour behind switches that default off; 4 migrations applied and rolled back cleanly on that copy; 5 quality checks showing no regression with the switch off and the measured gain with it on; 6 no other deploy in flight, and the rollback named (the previous image or commit).
- After deploying, verify live (real requests against the deployed version, clean logs, pasted) before calling it done or flipping anything else.

## Where the details are

2.1 code quality, 2.2 file and folder placement (read before creating any file or folder), 3.1 performance, 3.2 security, 3.3 test scenarios and 3.4 clean-code catalogs (look up an id, never read end to end), 9.5 the banned-token scanner, 14.1 worked anti-patterns, 15.1 onward the frontend design law (any UI-bearing work, from its first step), 16.3 whole-codebase audit, 5.7 the advisor protocol. The phase workflow is the `engineering-rules:engineering-rules` skill; the routes are `/engineering-rules:full`, `:quick`, `:shape`, `:explore-feature`, `:audit`, `:triage`, `:skill`, `:design`, `:log` and `:agents`.
