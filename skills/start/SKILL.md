---
name: start
description: >-
  Runs one task through the loop, start to commit: /oneloop:start <task>. Use it yourself the
  moment the user asks to start, do, build, implement, fix, change, add, rename or remove
  something in a codebase and no loop step has happened yet for that ask (no scope line, no
  TODO.md task line). Not for questions, explanations or reviews.
argument-hint: '<task>; the word "go" inside it pre-approves the scope'
---

# /oneloop:start

The task: $ARGUMENTS

An empty task means the user's last message. Run the loop on it, every step in order, nothing
in between. The law in your session context is the law; if you cannot quote its first line,
read `${CLAUDE_PLUGIN_ROOT}/law/engineering-law.md` before anything else.

1. **Scope.** The project's `CLAUDE.md` is the map. Files named in the task: no discovery;
   otherwise the symbol, its file, its direct callers, ten tool calls at most. Then, in this
   order: the line `scope: <files>`; a note of at most 3 lines (what changes, which files, what
   could go wrong); the line `- [ ] <task> (scope: <files>)` appended to `TODO.md` at the
   repository root; then wait for the yes through `AskUserQuestion`. The word "go" in the task
   is the yes; a risk-zone file still asks first.
2. **Edit.** `- [~]` on the task line. One grep for something to reuse, then the smallest diff
   inside the scoped files; an existing test file for the area is extended in the same edit. A
   file outside the scope, more than double the files, or a risk-zone file: stop, restate the
   scope on the task line, wait. Stuck twice on the same error: stop, state the root cause, ask.
3. **Check.** Lint on the changed files, typecheck, the test command, `ui_check` when a UI path
   changed, in that order, from the map or `settings/loop.json`; none configured, say so once.
   Then one read of `git diff`, and the obvious fixed.
4. **Commit.** The changed files staged by name, `TODO.md` ticked `- [x]` among them (a group
   with every line ticked moves whole to `TODO.archive.md` in the same commit); one commit, one
   line, on the current branch. The reply: the files changed, the check results, the side finds.
   Nothing else.

No summary of the law, no narration of the steps, no echo of file contents: the scope line, the
note and the final reply are the only status output.
