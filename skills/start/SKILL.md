---
name: start
description: >-
  Starts, resumes or picks up one task and runs it through the loop to its commit.
  /oneloop:start <task> starts it, or resumes the open line of docs/oneloop-todos/TODO.md it
  names; /oneloop:start alone lists the open lines (in flight first, then parked) as one
  pick-list. Use it yourself the moment the user asks to start, do, build, implement, fix,
  change, add, rename, remove, resume, continue or finish something in a codebase and no loop
  step has happened yet for that ask (no scope line, no task line). Not for questions,
  explanations or reviews.
argument-hint: '[<task>]; empty lists the open lines; the word "go" in a new task pre-approves its scope'
---

# /oneloop:start

The task: $ARGUMENTS

The law in your session context is the law; if you cannot quote its first line, read
`${CLAUDE_PLUGIN_ROOT}/law/engineering-law.md` before anything else. The checklist is
`docs/oneloop-todos/TODO.md` (an older root `TODO.md` and `TODO.archive.md` are moved there
first, with `git mv`, and go into this task's commit). Read its open lines, `- [~]` in flight
and `- [ ]` parked, then take the one path that fits:

- **The task names an open line** (the line's text holds the typed words, case aside; an empty
  task means the user's last message): resume it, below. Several lines match: the pick-list
  below, among them.
- **No task, open lines**: the pick-list, below.
- **No task, no open line**: one line, `nothing open; /oneloop:start <task> starts one`, stop.
- **Anything else**: a new task, below.

## The pick-list

One `AskUserQuestion`. Its options are the open lines, `- [~]` first, then `- [ ]`; the first
is marked `(Recommended)`. Each option's label is the task in a few words and its description
starts with `scope: <files>` (the line's scope; a file the work needs that it does not name is
added, and the line restated) followed, after `. `, by where it stopped, read from
`git status --short -- <files>`: nothing changed, `not started, from Edit`; uncommitted changes,
`edited, from Check`. The pick is the yes: the scope-check hook reads the scope from the option
the user chose, so no second question and no prompt on the first edit. Then resume the picked
line at its step.

## Resume

Always one question, even with "go" in the task: a match without the pick-list asks it with the
line as the one option, `(Recommended)`, its description as above, and `Start it as a new task`
as the other, with no scope. The scope has to be seen in this session before an edit; the pick
is the yes. Then `- [~]` on the line (a parked `- [ ]` flips; a restated scope is written on it)
and the loop from where it stopped: nothing changed under the scope, **Edit**; uncommitted
changes, **Check**; then **Commit**, below. No discovery, no second note: the scope line and
one line on where it stopped are the status output.

## A new task

1. **Scope.** The project's `CLAUDE.md` is the map. Files named in the task: no discovery;
   otherwise the symbol, its file, its direct callers, ten tool calls at most. Then, in this
   order: the line `scope: <files>`; a note of at most 3 lines (what changes, which files, what
   could go wrong); the line `- [ ] <task> (scope: <files>)` appended to the checklist; then
   wait for the yes through `AskUserQuestion`, its first option's description starting with the
   same `scope: <files>`. The word "go" in the task is the yes; a risk-zone file still asks
   first.
2. **Edit.** `- [~]` on the task line. One grep for something to reuse, then the smallest diff
   inside the scoped files; an existing test file for the area is extended in the same edit. A
   file outside the scope, more than double the files, or a risk-zone file: stop, restate the
   scope on the task line, wait. Stuck twice on the same error: stop, state the root cause, ask.
3. **Check.** Lint on the changed files, typecheck, the test command, `ui_check` when a UI path
   changed, in that order, from the map or `settings/loop.json`; none configured, say so once.
   Then one read of `git diff`, and the obvious fixed.
4. **Commit.** The changed files staged by name, the checklist ticked `- [x]` among them (a
   group with every line ticked moves whole to `docs/oneloop-todos/TODO.archive.md` in the same
   commit); one commit, one line, on the current branch. The reply: the files changed, the
   check results, the side finds. Nothing else.

No summary of the law, no narration of the steps, no echo of file contents: the scope line, the
note and the final reply are the only status output.
