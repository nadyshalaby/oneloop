---
name: update-rules
description: >-
  Changes and ships the oneloop harness (the engineering law, the code rules, the command
  skills, the reference pages, the hooks, the loop config, the plugin manifests) from its dev
  checkout at ~/Code/oneloop. Use it whenever the user asks to add, change, remove, loosen or
  tighten an engineering rule, law, step of the loop, guard, command, hook or check, or to update
  the rules. Ends tested, released, installed and pushed.
---

# Updating the rules

The rules are a harness every session runs inside, so a change to them is a change to a live
system: the installed plugin is what every new session loads, and the dev checkout at
`~/Code/oneloop` is where a change is made and proven first. Work on a copy, prove it, then
release it in one step, the same way the law's 1.11 ships anything else.

## Where a rule lives, and what it costs

| The rule | Its file | Who pays for it |
|---|---|---|
| Binds every task in every session | `law/engineering-law.md`, handed to every session by `hooks/session-start.sh` as it starts, in two parts (Claude Code keeps only a preview of a hook context over 10,000 characters), and again after a compaction | every session, from its first turn; capped at 90 lines and 12,750 characters |
| Binds every line of code written | `law/engineering-code.md`, handed to a session by `hooks/code-rules.sh` with the first code file it reads or edits (its `paths:` globs say which files count) | every session that touches code, once; capped at 60 lines and 8,600 characters |
| The reasons and procedures behind an always-on rule | `references/01-always-on-law/1.x-*.md`, the long forms | only when read |
| The loop's defaults: the four checks, the discovery budget, the two regexes | `settings/loop.json`, read by the hooks and named by the law | nothing per turn |
| A command the user types | `skills/<command>/SKILL.md`, served as `/oneloop:<command>` | its description in every session's skill list; the body when called |
| The one helper, the read-only reader | `agents/er-reader.md`, served as `oneloop:er-reader` | its description in every session's agent list; the body when sent |
| Detail one step or command reads | `references/<nn>-*/<n.n>-*.md` | only when read |
| Enforced by a machine at the tool boundary | `hooks/<name>.sh`, wired in `hooks/hooks.json` under `${CLAUDE_PLUGIN_ROOT}` | a process on every matching event |
| How the rules reach Claude Code | `.claude-plugin/plugin.json` (the plugin, its version), `.claude-plugin/marketplace.json` (this repository as its own marketplace), `hooks/hooks.json`; `bin/setup-statusline.sh` for the status line, the one thing a plugin cannot set | nothing per turn |

Put a rule on the cheapest layer that still binds when it must: the core only for what every
task needs, the code rules for what only writing code needs (the core keeps a one-line summary
of the caps and bans), a command's skill for what only that command needs, a reference for the
detail. A new code language or file type goes into the code rules' `paths:` globs.
A hook is for what a machine can judge without a model; a judgment call stays in the text. A
hook points and Claude fixes; no hook asks or blocks (the law, Guards).

## The ethics, none of them waivable

- **The user's words are the specification.** Quote the instruction; meet every detail in it
  exactly (a name, a number, a place, an order), and add nothing they did not ask for.
- **Never loosen a rule quietly.** A change that relaxes a ban, widens a cap, drops a check,
  waives a proof or lowers an evidence bar happens only on the user's explicit words. Say in one
  line what protection it removes, and write that line into the changelog entry.
- **Never lose power by accident.** Before rewording or moving a rule, list what it enforces;
  after, show each item is still enforced somewhere, in the pins (`tests/fixtures/short-law-pins.txt`
  for the core, `tests/fixtures/code-rules-pins.txt` for the code rules) or a test. A compaction that drops a check is a loosening, and the first bullet applies.
- **Tokens are paid by every session.** Prefer tightening an existing line to adding one; a new
  always-on sentence must buy behaviour. Print both law files' sizes before and after
  (`wc -lc law/engineering-law.md law/engineering-code.md`) and report them.
- **One source of truth.** The short law wins over its long form, and a long form that differs is
  a defect, so both change in the same commit. Search the whole repository for the old wording
  (`grep -rn -F '<old phrase>' "$ER" --exclude-dir=.git`) and change every place that still says it.
- **Do not chase (1.9).** A problem found while making the change is written down as a
  follow-up and reported, not fixed inside this change unless it blocks it.
- **A hook must never be the outage.** A hook that cannot judge exits 0 with one log line; it
  warns only about what the law bans, and only about what the edit adds, never what was
  already there; the risk-zone and scope hooks point, like every hook, and never block.
- **Evidence, safety and questions as the law says.** Every claim in the report has output run
  this session behind it (1.5); git safety holds throughout (1.7); a fork only the user can
  decide (which layer, whether a loosening is wanted, a name) goes through `AskUserQuestion`
  with the most effective option first (1.4).

## The steps

1. **Find the checkout and check it is calm.**
   `ER=$(cd -P ~/Code/oneloop && pwd)`, then `git -C "$ER" status --porcelain` and
   `git -C "$ER" worktree list`. A dirty tree or another change branch in flight is work
   somebody left: stop and tell the user rather than build on it. The checkout is on `main`, and
   `claude plugin list` shows `oneloop@oneloop` enabled at the version of the top `CHANGELOG.md`
   entry; anything else is a release half done, to be told, not built on.
2. **Restate the change in one line and pick its layer** from the table. Ask only what the user
   must decide; everything the repository can answer, look up.
3. **Work in a worktree, never in the checkout.**
   `git -C "$ER" worktree add -b rules/<slug> "$ER.worktrees/<slug>" main`, and every edit,
   test and commit below happens there; sessions keep running the installed plugin until the
   new version is released.
4. **Make the smallest change that does it**, in every file the old wording lives in, the long
   form beside the short law included, and keep both law files under their caps.
5. **Code first on the tests too** (the law's Edit step). The change comes first; the suite
   (step 6) then names what it broke, and each broken check is updated with it. New always-on
   wording gets its pin and wording that must never come back its line in
   `tests/fixtures/short-law-absent.txt`, one line each; a new command is listed in
   `tests/commands.test.sh` (a typed command in `COMMANDS`, a standalone skill in
   `STANDALONE`); a new loop default is checked in `tests/loop-config.test.sh`; a new hook is
   wired in `hooks/hooks.json` and pinned in `tests/hooks-wiring.test.sh`. A new test file only
   for a new or changed hook (`hooks/tests/`), since a hook runs on every event of every
   session, or on the user's word; no new check is watched failing on the old text.
6. **Run everything, on the exact commit you will ship.** Every `*.test.sh` in the worktree
   (`find . -name '*.test.sh' -not -path './.git/*'`, each run, each result line pasted),
   `shellcheck -x -P SCRIPTDIR -S style bin/*.sh hooks/*.sh hooks/tests/*.sh tests/*.sh`, and
   `claude plugin validate --strict .` in the worktree. Every file green, no finding; a red one
   sends you back to step 4.
7. **Write it into the history.** A new top entry in `CHANGELOG.md` with the next version:
   major when a rule or a command is removed, renamed or loosened; minor for a new rule, check,
   hook or command; patch for wording and fixes. It says what changed, why in the user's words,
   what protection a loosening removes, and both law files' sizes before and after. The same
   version goes into `.claude-plugin/plugin.json` and the marketplace entry in
   `.claude-plugin/marketplace.json` (`tests/plugin.test.sh` keeps the three equal); it is what
   `claude plugin update` compares.
8. **Commit in the worktree**, explicit paths only, a message that says what and why, no
   attribution trailer (1.7).
9. **Prove the release before making it.** The law's deploy command (1.11), read for a harness:
   the suite green on this commit (step 6); a new hook points and never asks or blocks, and is
   watched on one real event before it is called done; rule text has no switch, so its rollback
   is the revert below; there are no migrations; nothing else is in flight (step 1); and the
   rollback is named: the `main` commit before this one, undone with
   `git -C "$ER" revert --no-edit <this commit>`, pushed, and `claude plugin update oneloop@oneloop`.
10. **Release it.** `git -C "$ER" merge --ff-only rules/<slug>` in the checkout, then
    `git -C "$ER" push origin main`: the marketplace is the GitHub repository, so the push is
    the publish. Then `claude plugin update oneloop@oneloop`, which fetches the marketplace and
    installs the new version, and `claude plugin list`, which must show `oneloop@oneloop` enabled
    at that version. Running sessions keep the old version until they restart (or run
    `/reload-plugins`); new sessions get the new one.
11. **Verify it live.** A fresh session that could only answer from the new rules:
    `env -i HOME="$HOME" PATH="$PATH" USER="$USER" TERM=xterm-256color LANG=en_US.UTF-8 SHELL=/bin/zsh TMPDIR="$TMPDIR" claude -p "<a question only the changed rule answers>" --no-session-persistence --model sonnet`,
    its answer pasted; a hook change also gets one real event through the installed copy
    (`p=$(jq -r '.plugins["oneloop@oneloop"][0].installPath' ~/.claude/plugins/installed_plugins.json)`,
    then the event piped into `bash "$p/hooks/<hook>.sh"`). If it did not take, roll back
    (step 9) and say so.
12. **Clean up.** `git -C "$ER" worktree remove "$ER.worktrees/<slug>"` on a clean worktree only,
    never `--force`, then `git -C "$ER" branch -d rules/<slug>`.
13. **Report in plain words:** what changed and why, what it costs or saves every session, what
    was run and what it printed, the commit, the push, the installed version, the rollback, and
    any follow-ups found.
