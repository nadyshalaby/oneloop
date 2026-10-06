---
name: start
description: >-
  Starts, resumes or picks up one task and runs it through the loop to its commit.
  /oneloop:start <task> starts it, or resumes the open line of docs/oneloop-todos/TODO.md it
  names; /oneloop:start alone resumes the one open line, or lists several as one pick-list. Use
  it yourself the moment the user asks to start, do, build, implement, fix, change, add, rename,
  remove, resume, continue or finish something in a codebase and no loop step has happened yet
  for that ask (no scope line, no task line). Not for questions, explanations or reviews.
argument-hint: '[<task>]; empty resumes the one open line, or lists several'
---

# /oneloop:start

The task: $ARGUMENTS

The law in your session context is the law; if you cannot quote its first line, read
`${CLAUDE_PLUGIN_ROOT}/law/engineering-law.md` before anything else. Before each step, the
progress line (the law): the four steps in order, ✅ on the done ones, 🔵 on the current, ⚪ on
the rest, nothing else on it. Auto-pilot: no yes is waited for at any step, and a guard that points at something (the scope, a code rule, the
checklist) is fixed in your next move, never routed around; the only questions are a
clarification the code cannot answer and a change in logic you judge critical, asked before it
is built. The checklist is `docs/oneloop-todos/TODO.md` (an older root `TODO.md` and
`TODO.archive.md` are moved there first, with `git mv`, and go into this task's commit). Read
its open lines, `- [~]` in flight and `- [ ]` parked, then take the one path that fits:

- **The task names an open line** (the line's text holds the typed words, case aside; an empty
  task means the user's last message): resume it, below. Several lines match: the pick-list
  below, among them.
- **No task, one open line**: resume it, below.
- **No task, several open lines**: the pick-list, below.
- **No task, no open line**: one line, `nothing open; /oneloop:start <task> starts one`, stop.
- **Anything else**: a new task, below.

## The pick-list

The one question this command asks, and only when nothing names the line: one
`AskUserQuestion` whose options are the open lines, `- [~]` first, then `- [ ]`; the first is
marked `(Recommended)`. Each option's label is the task in a few words and its description
starts with `scope: <files>` (the line's scope; a file the work needs that it does not name is
added, and the line restated) followed, after `. `, by where it stopped, read from
`git status --short -- <files>`: nothing changed, `not started, from Edit`; uncommitted changes,
`edited, from Check`. Then resume the picked line at its step.

## Resume

No question. `- [~]` on the line (a parked `- [ ]` flips; a restated scope is written on it)
before the first edit, since the scope-check hook reads the scope from the checklist's `- [~]`
lines; one line on where it stopped; then the loop from there: nothing changed under the scope,
**Edit**; uncommitted changes, **Check**; then **Commit**, below. No discovery, no second note:
the scope line and that one line are the status output.

## A new task

1. **Scope.** The project's `CLAUDE.md` is the map. Files named in the task: no discovery;
   otherwise the symbol, its file, its direct callers, ten tool calls at most. Then, in this
   order: the line `scope: <files>`; a note of at most 3 lines (what changes, which files, what
   could go wrong); the line `- [~] <task> (scope: <files>)` appended to the checklist; then
   `oneloop:explain` on the change (the problem, the pseudocode as a fenced block, the effect,
   the risks), so the user can follow the work. All of it is reply text the user sees, in the message that carries
   the progress line or right after it, before the first edit: your thinking is invisible, and
   the scope guard points at an edit made before they are visible. Then straight on to Edit. A risk-zone file in the scope: say what changes there in at most 5
   lines in the final reply, and ask first only a change you judge critical.
2. **Edit.** One grep for something to reuse, then the smallest diff inside the scoped files,
   code first: the working code, and a new test only when the user asks or for money, auth or
   data-loss code, written once the code runs; a test of behaviour changed on purpose is
   updated with it. A file outside the scope, more than double the files, or a risk-zone file:
   restate the scope on the task line and in one line, then go on. Stuck twice on the same
   error: stop, state the root cause, ask.
3. **Check.** Lint on the changed files, typecheck, the test command, `ui_check` when a UI path
   changed, in that order, from the map or `settings/loop.json`; none configured, say so once.
   Then what changed runs once for real (a command, a request, a call, a page through
   `oneloop:browser`; `ui_check` counts for the UI), its output pasted, and one read of
   `git diff`, the obvious fixed.
4. **Commit.** The changed files staged by name, the checklist ticked `- [x]` among them (a
   group with every line ticked moves whole to `docs/oneloop-todos/TODO.archive.md` in the same
   commit); one commit, one line, on the current branch. The reply: the files changed, the
   check results, each guard's point and its fix, the side finds. Nothing else.

No summary of the law, no narration of the steps, no echo of file contents: the scope line, the
note, the explanation, the progress lines and the final reply are the only status output.
