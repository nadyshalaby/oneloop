# engineering-rules

The engineering law and working method for Claude Code, as a folder that plugs into
`~/.claude` with no plugin. A short core law binds every session through the user-global
`CLAUDE.md`, and the code rules join it the first time a session reads a code file; the phase workflow and its routes are skills that load only when you call them;
hooks enforce the parts of the law a machine can see; and `install.sh` wires it all in, checks
it, and takes it back out. Clone it on any machine, run the installer, and every project gets
the same rules.

It grew out of the engineering-rules plugin (2.21.0 and before, in the history below). The
plugin cost a session little until its skill loaded, and then its whole law, about 19,800
tokens by Claude Code's own estimate, which its description asked for on any task that touched
code. Here the core costs 3,144 tokens a message and the code rules about 2,414 more once code
is read; everything else stays on disk until a rule sends Claude to it. (Measured on
2026-09-24 with `claude -p "Reply with exactly: OK" --model sonnet --strict-mcp-config`, three
runs each, all equal: 27,602 input tokens with neither file, 30,746 with the core, 30,015 with
the code rules. The first short law, one file, measured 6,756.)

## What loads when

| What | File | When, and what it costs |
|---|---|---|
| The core law: definitions, precedence, the caps and bans in one line, 1.2, 1.4, 1.5, 1.7 to 1.11 | `law/engineering-law.md` | every session and every helper that loads `CLAUDE.md`, from the first prompt; capped at 90 lines and 10,000 characters by `tests/short-law.test.sh` |
| The code rules: 1.1, 1.3 and 1.6 in full | `law/engineering-code.md`, copied to `~/.claude/rules/` | the first time a session or a helper reads a file its `paths:` globs match (the common code extensions); capped at 60 lines and 7,500 characters |
| The phase workflow | `skills/engineering-rules/SKILL.md` | only when you call it by name or through a route |
| The routes and the switch | `skills/<route>/SKILL.md` | only when you type one; the model cannot invoke them |
| `demystify`, `update-engineering-rules` | `skills/<name>/SKILL.md` | the description is always listed; the body loads when it triggers or you type it |
| 127 reference sections, the long forms included | `references/**` | only when a rule or a phase names one |
| Hooks | `settings/hooks.json`, `hooks/*.sh` | a short process on each matching event; the advisor cue adds one short block per prompt, the advisor rule and the logic-first gate |

The two law files win over everything under `references/`: each long form in
`references/01-always-on-law/` keeps the reasons and procedures behind a section of theirs, and
if the two ever differ, the long form is the defect.

## Install, check, uninstall

Needs bash 3.2 or later, `jq` and `git`.

```
git clone git@github.com:nadyshalaby/claude-engineering-rules.git ~/.claude/engineering-rules
bash ~/.claude/engineering-rules/install.sh
```

The clone can live anywhere; the installer links `~/.claude/engineering-rules` to it. It then:

1. links each skill into `~/.claude/skills/` under its command name, so `/engineering-rules:quick`
   and the rest keep the names they had in the plugin;
2. appends one managed block to `~/.claude/CLAUDE.md` that imports the core law, below your
   own lines, which it never touches;
3. copies the code rules to `~/.claude/rules/engineering-code.md`, a copy and not a link because
   Claude Code skips a linked rules file, and refuses to overwrite a file there it did not
   write; your own rules in that folder stay yours;
4. merges the hooks and the status line into `~/.claude/settings.json`, taking the status line
   over only when it is unset or already an engineering-rules one;
5. switches the engineering-rules plugin off when it is installed.

It checks everything before it changes anything, copies each file it changes to
`~/.claude/backups/engineering-rules/<time>/` first, keeps each file's permissions and any link
that leads to it, and changes nothing on a second run. Start a new session to load it.

```
bash ~/.claude/engineering-rules/install.sh --check      # every piece in place, or exit 1 naming what is missing
bash ~/.claude/engineering-rules/install.sh --uninstall  # put back what the first install replaced
```

The uninstall puts `CLAUDE.md` back byte for byte and `settings.json` back as the same JSON
(byte for byte when it was in the two-space layout Claude Code writes), restores the status
line and the plugin setting it replaced, removes the links and the code rules copy (and the
rules folder, when the install made it and nothing else is in it), and leaves the clone alone. A
project whose own `.claude/settings.json` turns the plugin on keeps it on there; switch it off
in that file, or remove the plugin with
`claude plugin uninstall engineering-rules@engineering-rules-marketplace`.

`CLAUDE_CONFIG_DIR`, when set, replaces `~/.claude` everywhere above.

## Changing the rules

Ask Claude to change a rule, or type `/update-engineering-rules`. The skill carries the ethics
(your words are the specification, nothing is loosened quietly or lost by accident, both law
files' sizes are reported before and after, one source of truth) and the release: the change is
made and tested in a git worktree while your sessions keep running the old rules, then merged
into the live checkout, installed (which re-copies the code rules, so a change to them binds
nobody until then), verified in a fresh session, committed and pushed. Each
change gets a `CHANGELOG.md` entry and a version: major when a rule or command is removed,
renamed or loosened, minor for a new rule, check, hook or command, patch for wording and fixes.

## The hooks

| Event | Script | What it does |
|---|---|---|
| `PreToolUse` on edits | `edit-guard.sh` | refuses an edit that adds a banned token the law scout (9.5) can judge: suppressions, empty catches, bare `Error` throws in domain files, focused or ownerless skipped tests, debug artifacts, ownerless `TODO`s, removed-code comments, hardcoded secrets; what was already in the file never blocks |
| `PostToolUse` on edits | `file-cap.sh` | a file this change pushed over 500 lines gets a note to split it; one already over at the last commit gets a follow-up note instead, once per session |
| `UserPromptSubmit` | `advisor-cue.sh` | puts the advisor rule and the logic-first gate (1.4) into every prompt |
| `SessionStart` after a compaction or resume | `re-anchor.sh` | tells Claude to read the law from disk again, and the code rules before writing code, with the last ledger position Claude printed in a reply, if any |
| `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `Notification` | `progress-notify.sh` | one progress-log line per event, and a desktop notification when a turn ends on a ledger re-print, waits on you, or dies on an error |
| status line | `statusline.sh` | two rows: folder, branch, model and ledger position; then context, uptime, plan usage and compactions |

A hook that cannot judge exits 0 and says so in the progress log; none of them stands between
you and your work on its own bug.

## The commands

| Command | What it does |
|---|---|
| `/engineering-rules:engineering-rules <request>` | the phase workflow; bare, it walks you through the routes |
| `/engineering-rules:full`, `:quick` | full mode (every check, a written plan, a spec review, a work-doc) or quick mode (every check, less ceremony) |
| `/engineering-rules:shape`, `:explore-feature`, `:audit`, `:triage`, `:skill`, `:design`, `:log` | shaping an idea, tracing one feature onto a page, a whole-codebase audit, review triage, skill authoring, a design spec, the update log |
| `/engineering-rules:agents` | switches the phase agents off for the conversation, and back on |
| `/engineering-rules:demystify` | explains logic short and plain (the problem, pseudocode, the effect, the risks): before a new task, as the law's logic-first gate, or when you ask how code works |
| `/update-engineering-rules` | changes these rules and ships the change |

## Tests

```
find . -name '*.test.sh' -not -path './.git/*' | while read -r t; do bash "$t" | tail -n 1; done
shellcheck -x -P SCRIPTDIR -S style install.sh hooks/*.sh hooks/tests/*.sh tests/*.sh \
  skills/*/scripts/*.sh skills/*/scripts/tests/*.sh skills/*/scripts/tests/fixtures/*.sh \
  skills/*/capture/tests/*.sh
```

Every test file ends with a `N passed, M failed` line and exits non-zero on a failure. Each can
be pointed at a broken copy of what it checks through an environment variable named in its
header, which is how every check here was shown to be able to fail. `tests/install.test.sh`
runs the installer in fake homes only, never against the real `~/.claude`.
`skills/explore-feature/capture/tests/rewrite.test.sh` needs `typescript@5` in bun's cache.

## Layout

```
law/engineering-law.md          the core law CLAUDE.md imports
law/engineering-code.md         the code rules install.sh copies into ~/.claude/rules/
skills/engineering-rules/       the phase workflow
skills/<route>/                 one command per route, the agents switch, the standalone skills
references/                     127 sections, one file each, numbered as the workflow's map numbers them
hooks/                          the hook scripts, their shared helpers and their tests
settings/hooks.json             the hooks and the status line the installer merges into settings.json
settings/claude-md-block.md     the block the installer writes into CLAUDE.md
install.sh                      install, --check, --uninstall
tests/                          the repository's own tests and their fixtures
```

`references/17-ready-made-specs/`, twelve ready-made design specs, is droppable: only group 15
and the map in `0.1` point into it, and nothing in the working method depends on it.

## Sharing

The repository is private. Add a friend as a collaborator on GitHub, and they install it the
same way. Their own `CLAUDE.md` lines, settings and rules stay theirs: the installer only adds
its block, its hooks, its links and its copy of the code rules, and the uninstall takes exactly
those back out.

## History

`CHANGELOG.md` has one entry per version, the plugin's included.
