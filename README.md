# engineering-rules

The engineering law and working method for Claude Code, as a folder that plugs into
`~/.claude` with no plugin. One short law binds every session through the user-global
`CLAUDE.md`; the code rules join it the first time a session reads a code file; five hooks
enforce the parts of the law a machine can see; and `install.sh` wires it all in, checks it,
and takes it back out. Clone it on any machine, run the installer, and every project gets the
same rules.

It grew out of the engineering-rules plugin (2.21.0 and before, in the history below), whose
whole law loaded on any task that touched code. Here the core law is 10,932 characters and the
code rules 7,598, and everything else stays on disk until a rule sends Claude to it.

## One loop, for everything

A plain request runs the loop. It is the only workflow: no modes, no lanes, no tiers, and a
typo runs the same four steps as a new module.

1. **Scope.** Read the project's `CLAUDE.md`, the map. Files named in the request need no
   discovery; otherwise grep the symbol, open its file, then its direct callers and imports, and
   stop, within a budget of 10 tool calls (at the budget with the scope still unclear, a
   pick-list of files). One line `scope: <files>` and a note of at most 3 lines, then the yes;
   the word "go" in the request is the yes given in advance.
2. **Edit.** One grep for something to reuse; the smallest diff; an existing test file for the
   area is extended in the same edit, otherwise there is no test ritual. The scope ratchet stops
   the work when the change needs a file outside the scope line, more than double the files
   stated, or a risk-zone file: the scope is restated in at most 3 lines and the yes asked
   again. Stuck twice on the same error: stop, state the root cause, ask.
3. **Check.** Lint on the changed files, typecheck, the test command, then `ui_check` when a
   changed file is under a UI path, all taken from the map (`settings/loop.json` holds the
   defaults); then one read of `git diff`. No separate reviewer.
4. **Commit.** The changed files staged by name, one commit, a one-line message, on the current
   branch. The final reply is the files changed, the check results and the side finds.

Deploy is a command, not a step: on the word "deploy", the checks, the deploy, the live check.
Plan mode is yours to enter for architectural work; the law never enters it for you or adds a
planning layer of its own, and in it Scope is the plan.

Always on, whatever the task: the risk-zone guard (the first edit to a path matching the risk
regex becomes a permission prompt, even after "go"), the code-rules warning (a banned token an
edit adds is named beside the tool result, never blocked), the proof rule (nothing is done
without a check run this session), git safety (nothing discarded, no force push, files staged
by name) and side finds (written down for the end list, never chased; a serious one reported
at once). No helpers by default: the one exception is `er-reader`, a read-only Sonnet search,
sent only after grep has failed twice on an unfamiliar codebase.

## What loads when

| What | File | When, and what it costs |
|---|---|---|
| The core law: definitions, the loop, the guards, the map rule, the helpers rule, 1.2, 1.4, 1.5, 1.7, 1.9, 1.10 | `law/engineering-law.md` | every session and every helper that loads `CLAUDE.md`, from the first prompt; 85 lines and 10,932 characters, capped at 90 and 11,200 by `tests/short-law.test.sh` |
| The code rules: 1.1, 1.3 and 1.6 in full | `law/engineering-code.md`, copied to `~/.claude/rules/` | the first time a session or a helper reads a file its `paths:` globs match (the common code extensions); 50 lines and 7,598 characters, capped at 60 and 7,600 |
| The loop's defaults: the four checks, the discovery budget, the risk regex, the UI path regex | `settings/loop.json` | read by the risk-zone hook; the law states the same defaults, and `tests/loop-config.test.sh` keeps the two equal |
| The one helper, `er-reader` | `agents/er-reader.md`, linked into `~/.claude/agents/` | its one-line description in every session's agent list; its body only when it is sent |
| The commands | `skills/<command>/SKILL.md` | only when you type one; the model cannot invoke them |
| `explain`, `update-engineering-rules`, `status-report` | `skills/<name>/SKILL.md` | the description is always listed; the body loads when it triggers or you type it |
| 72 reference pages, the long forms included | `references/**` | only when a rule names one; `tests/references.test.sh` fails on a cited section with no page and on a page nothing reaches |
| Hooks | `settings/hooks.json`, `hooks/*.sh` | a short process on each matching event; the reminder adds one line of 81 bytes to every prompt |

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

1. links each skill into `~/.claude/skills/` under its command name, so `/engineering-rules:brainstorm`
   and the rest answer to their `/engineering-rules:` names, and the helper agent into
   `~/.claude/agents/`, removing links of its own that no longer point at a skill or an agent;
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

## Configuring the loop

`settings/loop.json` holds the defaults the law states: the four check commands (`lint`,
`typecheck`, `test`, `ui_check`, empty until a project sets them), `discovery_budget` (10),
`risk_regex` and `ui_path_regex`. A project sets its own checks in its `CLAUDE.md`, the map, as
four lines, the way this repository's own `CLAUDE.md` does:

```
- lint: <command>
- typecheck: <command, or none>
- test: <command>
- ui_check: <command, or none>
```

A `risk_regex: <regex>` line in the map replaces the default risk regex for that project; the
risk-zone hook reads it there first. `ui_check` is a command whose result is a screenshot or a
one-line visual outcome, such as the Claude Code Chrome extension or a Playwright script; unset,
the Check step skips it and says so once. The map also holds the key directories, the 5 to 10
entry-point files and the house conventions, under 60 lines: hooks enforce rules, the map only
orients. `tests/claude-md.test.sh` keeps this repository's own map in that shape.

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
| `UserPromptSubmit` | `loop-reminder.sh` | one line into every prompt: `one loop · wait for yes unless "go" · proof required · risk zones need my yes` |
| `PreToolUse` and `PostToolUse` on edits | `risk-zone.sh` | before the first edit in a session to a file whose path matches the risk regex (the map's `risk_regex:` line, else `settings/loop.json`), turns the edit into a permission prompt whose approval is the yes the law requires; after an edit that went through, records it, so the next edit to that file passes and a rejected one asks again |
| `PreToolUse` on edits | `edit-guard.sh` | warns beside the tool result when an edit adds a banned token the scanner (9.5) can judge: suppressions, empty catches, bare `Error` throws in domain files, focused or ownerless skipped tests, debug artifacts, ownerless `TODO`s, removed-code comments, hardcoded secrets; it never blocks, and what was already in the file is never named |
| `SessionStart` after a compaction or resume | `re-anchor.sh` | tells Claude to read the law from disk again, the code rules before writing code, and to resume a task at the loop step it was in, with nothing from before the loss counting as proof |
| `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `Notification` | `progress-notify.sh` | one progress-log line per event, and a desktop notification when a turn ends, waits on you, or dies on an error |
| status line | `statusline.sh` | two rows: folder, branch and model; then context, uptime, plan usage and compactions |

No hook blocks: the risk-zone hook asks, the code-rules hook warns, and a hook that cannot
judge exits 0 and says so in the progress log. None of them stands between you and your work on
its own bug.

## The commands

| Command | What it does |
|---|---|
| a plain request | the loop: scope, edit, check, commit |
| `/engineering-rules:brainstorm <idea>` | one Socratic conversation until the idea is a task, then hands it to the loop's Scope step |
| `/engineering-rules:audit [directory]` | a whole-codebase audit against the law and the catalogs |
| `/engineering-rules:triage <findings>` | a batch of review findings, each accepted, pushed back, deferred or sent back for restatement |
| `/engineering-rules:design-spec [author, extract or refresh]` | the project's design spec |
| `/engineering-rules:release-notes` | the release notes of the task in flight, printed only when you ask |
| `engineering-rules:explain` | how code, a flow or a feature works, or a change before it is built: the problem, pseudocode, the effect, the risks; it triggers on its own when you ask, and the build still runs the loop |
| `/update-engineering-rules` | changes these rules and ships the change |
| `/status-report` | where things stand: Doing, Done (each item tagged Shipped, Pushed not verified or Local, checked against git and the live system) and Todo; it also shapes the ten-minute check-in brief |

## Tests

```
find . -name '*.test.sh' -not -path './.git/*' | while read -r t; do bash "$t" | tail -n 1; done
shellcheck -x -P SCRIPTDIR -S style install.sh hooks/*.sh hooks/tests/*.sh tests/*.sh
```

Every test file ends with a `N passed, M failed` line and exits non-zero on a failure. Each can
be pointed at a broken copy of what it checks through an environment variable named in its
header, which is how every check here was shown to be able to fail. `tests/install.test.sh`
runs the installer in fake homes only, never against the real `~/.claude`.

## Layout

```
law/engineering-law.md          the core law CLAUDE.md imports: the loop, the guards, the map rule, the helpers rule
law/engineering-code.md         the code rules install.sh copies into ~/.claude/rules/
settings/loop.json              the loop's defaults: the four checks, the discovery budget, the two regexes
settings/hooks.json             the hooks and the status line the installer merges into settings.json
settings/claude-md-block.md     the block the installer writes into CLAUDE.md
skills/<command>/               one folder per command, and the three standalone skills
agents/er-reader.md             the one helper, read-only, with its model and turn cap
hooks/                          the five hook scripts, their shared helpers and their tests
references/                     72 pages, one file each, numbered as the law cites them
CLAUDE.md                       this repository's own map, in the shape the law asks of every project
install.sh                      install, --check, --uninstall
tests/                          the repository's own tests and their fixtures
```

`references/17-ready-made-specs/`, twelve ready-made design specs, is droppable: only group 15
points into it, and nothing in the working method depends on it.

## Sharing

The repository is private. Add a friend as a collaborator on GitHub, and they install it the
same way. Their own `CLAUDE.md` lines, settings and rules stay theirs: the installer only adds
its block, its hooks, its links and its copy of the code rules, and the uninstall takes exactly
those back out.

## History

`CHANGELOG.md` has one entry per version, the plugin's included.
