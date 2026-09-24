---
name: update-engineering-rules
description: >-
  Changes the user's engineering rules setup safely and ships it: the always-on law, the
  workflow and route skills, the references, the hooks, the settings fragment or the installer,
  in the engineering-rules repo at ~/.claude/engineering-rules. Use it whenever the user asks
  to add, change, remove, loosen or tighten an engineering rule, law, phase, route, hook or
  check, or to update the engineering rules. Ends tested, installed, committed and pushed.
---

# Updating the engineering rules

The rules are a harness every session runs inside, so a change to them is a change to a live
system: the checkout at `~/.claude/engineering-rules` is what every new session loads, and its
hooks run in every open session the moment a file changes. Work on a copy, prove it, then
release it in one step, the same way the law's 1.11 ships anything else.

## Where a rule lives, and what it costs

| The rule | Its file | Who pays for it |
|---|---|---|
| Binds every task in every session | `law/engineering-law.md`, the short law the `CLAUDE.md` block imports | every session and every helper, on every turn; capped at 200 lines and 20,000 characters |
| The reasons and procedures behind an always-on rule | `references/01-always-on-law/1.x-*.md`, the long forms | only when read |
| Binds only while the phase workflow runs | `skills/engineering-rules/SKILL.md` | only when the workflow is called |
| A command the user types | `skills/<route>/SKILL.md` | its description in every session's skill list; the body when called |
| Detail one phase or route reads | `references/<nn>-*/<n.n>-*.md` | only when read |
| Enforced by a machine at the tool boundary | `hooks/<name>.sh`, wired in `settings/hooks.json` | a process on every matching event |
| How the rules reach Claude Code | `settings/claude-md-block.md`, `settings/hooks.json`, `install.sh` | nothing per turn |

Put a rule on the cheapest layer that still binds when it must: the short law only for what
every task needs, the workflow skill for what only the phases need, a reference for the detail.
A hook is for what a machine can judge without a model; a judgment call stays in the text.

## The ethics, none of them waivable

- **The user's words are the specification.** Quote the instruction; meet every detail in it
  exactly (a name, a number, a place, an order), and add nothing they did not ask for.
- **Never loosen a rule quietly.** A change that relaxes a ban, widens a cap, drops a check,
  waives a proof or lowers an evidence bar happens only on the user's explicit words. Say in one
  line what protection it removes, and write that line into the changelog entry.
- **Never lose power by accident.** Before rewording or moving a rule, list what it enforces;
  after, show each item is still enforced somewhere, in the pins (`tests/fixtures/short-law-pins.txt`)
  or a test. A compaction that drops a check is a loosening, and the first bullet applies.
- **Tokens are paid by every session.** Prefer tightening an existing line to adding one; a new
  always-on sentence must buy behaviour. Print the short law's size before and after
  (`wc -lc law/engineering-law.md`) and report both.
- **One source of truth.** The short law wins over its long form, and a long form that differs is
  a defect, so both change in the same commit. Search the whole repository for the old wording
  (`grep -rn -F '<old phrase>' "$ER" --exclude-dir=.git`) and change every place that still says it.
- **Do not chase (1.9).** A problem found while making the change is written down as a
  follow-up and reported, not fixed inside this change unless it blocks it.
- **A hook must never be the outage.** A hook that cannot judge exits 0 with one log line; it
  refuses only what the law refuses, and only what the edit adds, never what was already there.
- **Evidence, safety and questions as the law says.** Every claim in the report has output run
  this session behind it (1.5); git safety holds throughout (1.7); a fork only the user can
  decide (which layer, whether a loosening is wanted, a name) goes through `AskUserQuestion`
  with the most effective option first (1.4), and the advisor is consulted before the change is
  settled and before it is called done.

## The steps

1. **Find the repository and check it is calm.**
   `ER=$(cd -P ~/.claude/engineering-rules && pwd)`, then `git -C "$ER" status --porcelain`
   and `git -C "$ER" worktree list`. A dirty tree or another change branch in flight is work
   somebody left: stop and tell the user rather than build on it. The live checkout is on `main`.
2. **Restate the change in one line and pick its layer** from the table. Ask only what the user
   must decide; everything the repository can answer, look up.
3. **Work in a worktree, never in the live checkout.**
   `git -C "$ER" worktree add -b rules/<slug> "$ER.worktrees/<slug>" main`, and every edit,
   test and commit below happens there, so open sessions keep running the old rules until the
   new ones are proven.
4. **Make the smallest change that does it**, in every file the old wording lives in, the long
   form beside the short law included, and keep the short law under its caps.
5. **Change the tests with it.** New always-on wording gets pins; wording that must never come
   back goes into `tests/fixtures/short-law-absent.txt`; a hook change gets a test beside it
   (`hooks/tests/`); a new command is listed in `tests/sub-commands.test.sh` (a route through the workflow's route table, a standalone skill in `STANDALONE`). Watch each new
   check fail on the old text: point the test's override (`LAW_MD`, `WORKFLOW_MD`,
   `FILE_CAP_SH` and the like) at `git -C "$ER" show main:<path>` saved to a scratch file.
6. **Run everything, on the exact commit you will ship.** Every `*.test.sh` in the worktree
   (`find . -name '*.test.sh' -not -path './.git/*'`, each run, each result line pasted), and
   `shellcheck -x -P SCRIPTDIR -S style install.sh hooks/*.sh hooks/tests/*.sh tests/*.sh skills/*/scripts/*.sh skills/*/scripts/tests/*.sh skills/*/scripts/tests/fixtures/*.sh skills/*/capture/tests/*.sh`.
   Every file green, no finding; a red one sends you back to step 4.
7. **Write it into the history.** A new top entry in `CHANGELOG.md` with the next version:
   major when a rule or a command is removed, renamed or loosened; minor for a new rule, check,
   hook or command; patch for wording and fixes. It says what changed, why in the user's words,
   what protection a loosening removes, and the short law's size before and after.
8. **Commit in the worktree**, explicit paths only, a message that says what and why, no
   attribution trailer (1.7).
9. **Prove the release before making it.** The law's six proofs (1.11), read for a harness:
   the suite green on this commit (step 6); a new refusal in a hook ships behind an environment
   switch that defaults off when it could block real work, and is turned on only after it ran
   clean; rule text has no switch, so its rollback is the revert below; there are no migrations;
   nothing else is in flight (step 1); and the rollback is named: the `main` commit before this
   one, undone with `git -C "$ER" revert --no-edit <this commit>` and a re-run of the installer.
10. **Release it.** `git -C "$ER" merge --ff-only rules/<slug>` in the live checkout, then
    `bash "$ER/install.sh"`, which re-links renamed skills and re-merges changed hooks and
    changes nothing else, and `bash "$ER/install.sh" --check`, which must print
    `engineering-rules: installed and wired`.
11. **Verify it live.** A fresh session that could only answer from the new rules:
    `env -i HOME="$HOME" PATH="$PATH" USER="$USER" TERM=xterm-256color LANG=en_US.UTF-8 SHELL=/bin/zsh TMPDIR="$TMPDIR" claude -p "<a question only the changed rule answers>" --no-session-persistence --model haiku`,
    its answer pasted; a hook change also gets one real event through the installed hook. If
    it did not take, revert (step 9) and say so.
12. **Push it.** `git -C "$ER" push origin main`. No remote, or a refused push, is said plainly
    with its error; never force.
13. **Clean up.** `git -C "$ER" worktree remove "$ER.worktrees/<slug>"` on a clean worktree only,
    never `--force`, then `git -C "$ER" branch -d rules/<slug>`.
14. **Report in plain words:** what changed and why, what it costs or saves every session, what
    was run and what it printed, the commit, the push, the rollback, and any follow-ups found.
