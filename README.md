# oneloop

The engineering law and working method for Claude Code, as a plugin. One short law is handed to
every session as it starts; the code rules join it with the first code file the session reads or
edits; nine hooks carry the law in and point at what a machine can see; every task is one line in a
`docs/oneloop-todos/TODO.md` checklist; and a handful of typed commands cover what is not a
plain task. Install it once from GitHub, update it with one command, and every project gets the
same rules.

It grew out of the same author's earlier plugin (2.21.0 and before) and the installer-era
harness (3.0.0 to 10.1.1, wired into `~/.claude` by a script; both in the history). Here the core law is
88 lines and 12,730 characters, the code rules 53 lines and 8,540, and everything else stays on
disk until a rule sends Claude to it.

## One loop, for everything

A plain request runs the loop. It is the only workflow: no modes, no lanes, no tiers, and a
typo runs the same four steps as a new module.

1. **Scope.** Read the project's `CLAUDE.md`, the map. Files named in the request need no
   discovery; otherwise grep the symbol, open its file, then its direct callers and imports, and
   stop, within a budget of 10 tool calls (at the budget with the scope still unclear, a
   pick-list of files). One line `scope: <files>`, a note of at most 3 lines, then
   `oneloop:explain` on the change (the problem, the pseudocode as a fenced block, the effect,
   the risks), so you can follow the work, all of it as reply text you see (a plan inside Claude's thinking is not
   printed, and the scope guard points at an edit made before they are visible); then straight
   on. No step waits for a yes: the loop runs on auto-pilot
   and asks only two things, a clarification the code cannot answer, or a change in logic Claude
   judges critical, before it is built. Before each step, one progress line shows the four
   steps, ✅ on the done ones, 🔵 on the current, ⚪ on the rest.
2. **Edit.** One grep for something to reuse; the smallest diff, code first: the working code,
   and a new test only when you ask for one or for money, auth or data-loss code, written once
   the code runs (a test of behaviour changed on purpose is updated with it). The scope ratchet
   restates the scope, in at most 3 lines and on the task line, when the change needs a file
   outside the scope, more than double the files stated, or a risk-zone file, then goes on.
   Stuck twice on the same error: stop, state the root cause, ask.
3. **Check.** Lint on the changed files, typecheck, the test command, then `ui_check` when a
   changed file is under a UI path, all taken from the map (`settings/loop.json` holds the
   defaults); then what changed runs once for real (a command, a request, a call; `ui_check`
   counts for the UI), its output pasted as the proof it works; then one read of `git diff`.
   No separate reviewer.
4. **Commit.** The changed files staged by name, one commit, a one-line message, on the current
   branch. The final reply is the files changed, the check results, what each guard pointed at
   and its fix, and the side finds.

Every task is one line in the repository's `docs/oneloop-todos/TODO.md`, a plain checklist and
the only task tracker (a doc or tracking file you point at is read as input, never used to
track; a root `TODO.md` and `TODO.archive.md` from an older version move there with `git mv` at
the next Scope, in that task's commit), appended to its group: under a `## <milestone>` heading
when you name one, else the unheaded group on top. `- [~] <task> (scope: <files>)` is written at
Scope as the scope line is printed (`- [ ]` while it is parked or waits on a question), `- [x]`
at Commit and staged in the same commit, each the moment the status changes; when every line of
a group is ticked, that group moves whole to `TODO.archive.md` beside it under a dated heading
and the other groups stay. Two hooks keep it honest without blocking anything: the scope-check
hook reads the scope from the checklist's `- [~]` lines and points at an edit to a file none of
them covers, or made while none is in flight (a `TODO.md` anywhere else, the root included, is
not the checklist and counts for nothing), telling Claude to put the file on the task line, or
add the line, and go on; the commit hook points at a `git commit` that leaves the checklist out,
telling Claude to tick, stage and commit it right after. Neither asks you anything, in any
permission mode: Claude fixes what they point at, at once.

Deploy is a command, not a step: on the word "deploy", the checks, the deploy, the live check.
Plan mode is yours to enter for architectural work; the law never enters it for you or adds a
planning layer of its own, and in it Scope is the plan.

Always on, whatever the task: the risk-zone guard (the first edit to a path matching the risk
regex is pointed at; Claude says what changes there in at most 5 lines and asks first only a
change it judges critical), the edit guard (an edit that adds a code-rule break, a ban, a name,
a file kind, a cap or a new unlisted top-level folder, is pointed at with rule, line and fix,
and the line is fixed in the next edit; a technical exception stays on the line as
`law-exception: <what the technology needs>`), the proof rule (nothing is done
without a check run this session), git safety (nothing discarded, no force push, files staged
by name) and side finds (written down for the end list, never chased; a serious one reported
at once). No helpers by default: the one exception is `oneloop:er-reader`, a read-only Sonnet
search, sent only after grep has failed twice on an unfamiliar codebase.

## What loads when

| What | File | When, and what it costs |
|---|---|---|
| The core law: definitions, the loop, the guards, the map rule, the helpers rule, 1.2, 1.4, 1.5, 1.7, 1.9, 1.10 | `law/engineering-law.md`, handed to the session by `hooks/session-start.sh` in two parts (Claude Code keeps only a 2KB preview of a hook context over 10,000 characters) | every session, from its first turn, and again after a compaction, a resume or a clear; 88 lines and 12,730 characters, capped at 90 and 12,750 by `tests/short-law.test.sh` |
| The code rules: 1.1, 1.3 and 1.6 in full | `law/engineering-code.md`, handed to the session by `hooks/code-rules.sh` | the first time a session reads or edits a file its `paths:` globs match (the common code extensions), once per session; 53 lines and 8,540 characters, capped at 60 and 8,600 |
| The loop's defaults: the four checks, the discovery budget, the risk regex, the UI path regex | `settings/loop.json` | read by the risk-zone hook; the law states the same defaults, and `tests/loop-config.test.sh` keeps the two equal |
| The one helper, `oneloop:er-reader` | `agents/er-reader.md` | its one-line description in every session's agent list; its body only when it is sent |
| The commands | `skills/<command>/SKILL.md` | only when you type one; the model cannot invoke them |
| `explain`, `update-rules`, `status-report` | `skills/<name>/SKILL.md` | the description is always listed; the body loads when it triggers or you type it |
| 72 reference pages, the long forms included | `references/**` | only when a rule names one; `tests/references.test.sh` fails on a cited section with no page and on a page nothing reaches |
| Hooks | `hooks/hooks.json`, `hooks/*.sh` | a short process on each matching event; the reminder adds one line of 121 bytes to every prompt |

The two law files win over everything under `references/`: each long form in
`references/01-always-on-law/` keeps the reasons and procedures behind a section of theirs, and
if the two ever differ, the long form is the defect. The law's paths (`references/`,
`law/engineering-code.md`, `settings/loop.json`) are relative to the harness root, which the
session-start hook names in the line above each part of the law.

## Install, update, uninstall

Needs Claude Code 2.1 or later, bash 3.2 or later, `jq` and `git` with access to the repository
(it is private: a collaborator's git credentials do).

```
claude plugin marketplace add nadyshalaby/oneloop
claude plugin install oneloop@oneloop
bash "$(jq -r '.plugins["oneloop@oneloop"][0].installPath' ~/.claude/plugins/installed_plugins.json)/bin/setup-statusline.sh"
```

The repository is the plugin and its own marketplace, so the first line registers it and the
second installs it, at user scope, into Claude Code's plugin cache. New sessions load it; a
running session picks it up on `/reload-plugins` or a restart. The third line is the one thing a
plugin cannot wire, the status line: it writes one `statusLine` entry into `~/.claude/settings.json`
that finds the installed version on every render and runs its `hooks/statusline.sh`, falling
back to `~/.claude/statusline-command.sh` when you have one; it takes the status line over only
when it is unset, already oneloop's, the old install's or that personal script, backs the file
up first, and changes nothing on a second run (`--check` reads it, `--remove` undoes it,
`--force` replaces any other status line).

```
claude plugin update oneloop@oneloop      # the newest version from GitHub; restart or /reload-plugins to apply
claude plugin uninstall oneloop@oneloop   # then bin/setup-statusline.sh --remove, if you set the status line
```

Coming from the installer-era harness: unwire it first with `bash <old checkout>/install.sh --uninstall`,
which puts your `CLAUDE.md` and `settings.json` back and removes its links and its copy of the
code rules; then install the plugin as above. `CLAUDE_CONFIG_DIR`, when set, replaces `~/.claude`
for the status line setup.

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

Ask Claude to change a rule, or type `/oneloop:update-rules`. The skill carries the ethics (your
words are the specification, nothing is loosened quietly or lost by accident, both law files'
sizes are reported before and after, one source of truth) and the release: the change is made
and tested in a git worktree of the dev checkout (`~/Code/oneloop`), code first (the change,
then the suite, and a new test file only for a hook), while your sessions keep
running the installed version, then merged, pushed (the marketplace is the GitHub repository, so
the push is the publish), installed with `claude plugin update`, and verified in a fresh session.
Each change gets a `CHANGELOG.md` entry and a version, written into `.claude-plugin/plugin.json`
and the marketplace entry too (`tests/plugin.test.sh` keeps the three equal): major when a rule
or command is removed, renamed or loosened, minor for a new rule, check, hook or command, patch
for wording and fixes.

## The hooks

Wired in `hooks/hooks.json`, every command under `${CLAUDE_PLUGIN_ROOT}/hooks/`.

| Event | Script | What it does |
|---|---|---|
| `SessionStart` (startup, resume, clear, compact, fork) | `session-start.sh`, run twice, `1` and `2` | hands the core law to the session in two parts, each under the 10,000 characters Claude Code shows whole (a larger hook context arrives as a 2KB preview and a file path), split at the heading nearest the middle, each headed by the part and its lines, the plugin version and the harness root; after a compaction or a resume part 2 adds the re-anchor: the law is the law, a task in flight resumes at its loop step, nothing from before the loss counts as proof |
| `UserPromptSubmit` | `loop-reminder.sh` | one line into every prompt: `one loop · auto-pilot: a guard points, you fix · proof required · ask only a clarification or a critical logic change` |
| `PreToolUse` on reads and edits | `code-rules.sh` | the first time a session reads or edits a file the code rules' `paths:` globs name, hands it the code rules beside the tool result, once per session |
| `PreToolUse` and `PostToolUse` on edits | `risk-zone.sh` | before the first edit in a session to a file whose path matches the risk regex (the map's `risk_regex:` line, else `settings/loop.json`), points at it beside the tool result: the matched word, the 5-line say-what-changes rule and the ask-first-only-if-critical rule, no decision, so nothing blocks; after an edit that went through, records it, so the next edit to that file in the session is not pointed at again |
| `PreToolUse` on edits | `scope-check.sh` | reads the `scope:` of every `- [~]` line of `docs/oneloop-todos/TODO.md`, the checklist (a `- [ ]` line is parked and counts for nothing), and points at an edit to a file none covers, by name or by a folder it is under, or an edit while no line is in flight, telling Claude the fix (put the file on the task line; add or flip a line; while a root `TODO.md` still exists and the checklist does not, move it and its archive there with `git mv` first) and to go on; once the scope passes it reads this turn's reply text from the session transcript (the assistant text after your last message, typed or queued; injected text, compaction summaries and tool results are not you) and points when that stored text carries no scope line, or no explanation, telling Claude to print what is missing (a turn with no stored reply text is not judged, since some sessions' transcripts keep none of the text sent along with a tool call, and neither is a turn where the transcript kept a message reworded, a thinking block with text in place of what was printed, since that text can't be read back; a missing or unreadable transcript skips the check too; a big one is read from its last 2 MB); no decision, so nothing blocks; a `TODO.md` anywhere else is not the checklist; edits to the checklist and its archive themselves and files outside the repository are not judged |
| `PreToolUse` on the shell | `commit-check.sh` | points at a `git commit` that neither stages nor names `docs/oneloop-todos/TODO.md` (a root `TODO.md` does not count): tick the task's line, stage it and commit it right after; no decision, so nothing blocks; the repository is the one `git -C` names, else the session's folder |
| `PreToolUse` on edits | `edit-guard.sh` | points at an edit that adds a code-rule break the scanner (9.5) can judge: the bans (suppressions, empty catches, bare `Error` throws in domain files, non-null `!`, inline types, focused or ownerless skipped tests, debug artifacts, ownerless `TODO`s, removed-code comments, hardcoded secrets), the names (case, refused words, the `I` prefix, boolean prefixes, a default export that disagrees with its file), the file kinds (a second class or component, a type, constant, schema or class map outside its home, a file or folder in the wrong case or named for nothing), the caps (a fourth parameter, a flag parameter) and a new file under a top-level folder the map does not list; every rule the edit adds is named with its line and fix, to be fixed in the next edit (no decision, so nothing blocks); a technical exception stays on the line as `law-exception: <what the technology needs>`, and what was already in the file is never named |
| `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `Notification` | `progress-notify.sh` | one progress-log line per event, and a desktop notification when a turn ends, waits on you, or dies on an error |
| status line (set by `bin/setup-statusline.sh`) | `statusline.sh` | two rows: folder, branch and model; then context, uptime, plan usage and compactions |

No hook asks or blocks, in any permission mode: the risk-zone, scope, commit and edit-guard
hooks point (context beside the tool result and one line in the progress log,
`~/.claude/progress.log`), Claude fixes what they point at, and a hook that cannot judge exits 0
and says so in that log. None of them stands between you and your work. One limit: a subagent gets no law, because no
hook can inject context into one; the law allows only the read-only reader anyway.

## The commands

| Command | What it does |
|---|---|
| a plain request | the loop: scope, edit, check, commit |
| `/oneloop:start [task]` | the same loop, restated as a checklist of what each step owes, start to commit. A task that names an open checklist line resumes it at its step (nothing changed yet: Edit; uncommitted changes: Check; then Commit) with no question; no task resumes the one open line, or lists several, in flight first, then parked, as one pick-list, the only question this command asks; anything else is a new task. It also fires on its own when you ask to build, fix, change, add, resume or finish something and no loop step has begun, the case where a plain request slipped past the loop |
| `/oneloop:brainstorm <idea>` | one Socratic conversation until the idea is a task, then hands it to the loop's Scope step |
| `/oneloop:audit [directory]` | a whole-codebase audit against the law and the catalogs |
| `/oneloop:triage <findings>` | a batch of review findings, each accepted, pushed back, deferred or sent back for restatement |
| `/oneloop:design-spec [author, extract or refresh]` | the project's design spec |
| `/oneloop:release-notes` | the release notes of the task in flight, printed only when you ask |
| `oneloop:explain` | how code, a flow or a feature works, or a change before it is built: the problem, pseudocode as a fenced block, the effect, the risks; it triggers on its own when you ask, and the loop's Scope step runs it on every change, after the scope line and the note, so you can follow the work |
| `/oneloop:update-rules` | changes these rules and ships the change |
| `/oneloop:status-report` | where things stand: Doing, Done (each item tagged Shipped, Pushed not verified or Local, checked against git and the live system) and Todo; it also shapes the ten-minute check-in brief |

## Tests

```
find . -name '*.test.sh' -not -path './.git/*' | while read -r t; do bash "$t" | tail -n 1; done
shellcheck -x -P SCRIPTDIR -S style bin/*.sh hooks/*.sh hooks/tests/*.sh tests/*.sh
claude plugin validate --strict .
```

Every test file ends with a `N passed, M failed` line and exits non-zero on a failure. Each can
be pointed at a broken copy of what it checks through an environment variable named in its
header. `tests/setup-statusline.test.sh`
runs the status line setup in fake config folders only, never against the real `~/.claude`.

## Layout

```
.claude-plugin/plugin.json      the plugin: name, version, description
.claude-plugin/marketplace.json this repository as its own marketplace, listing the plugin at "."
law/engineering-law.md          the core law the session-start hook hands to every session, in two parts
law/engineering-code.md         the code rules the code-rules hook hands in with the first code file
settings/loop.json              the loop's defaults: the four checks, the discovery budget, the two regexes
skills/<command>/               one folder per command, and the three standalone skills; typed as /oneloop:<name>
agents/er-reader.md             the one helper, read-only, with its model and turn cap; sent as oneloop:er-reader
hooks/hooks.json                the wiring: which script runs on which event
hooks/                          the nine hook scripts, their shared helpers and their tests
bin/setup-statusline.sh         the one-time status line setup, the one thing a plugin cannot wire
docs/oneloop-todos/             this repository's own checklist: TODO.md, one line per task, and TODO.archive.md, the ticked ones
references/                     72 pages, one file each, numbered as the law cites them
CLAUDE.md                       this repository's own map, in the shape the law asks of every project
tests/                          the repository's own tests and their fixtures
```

`references/17-ready-made-specs/`, twelve ready-made design specs, is droppable: only group 15
points into it, and nothing in the working method depends on it.

## Sharing

The repository is private. Add a friend as a collaborator on GitHub, and they install it the
same way. Their own `CLAUDE.md`, settings and rules stay theirs: the plugin adds its hooks, its
skills and its agent, the status line setup adds one settings entry, and the uninstall takes
exactly those back out.

## History

`CHANGELOG.md` has one entry per version, the installer era's and the old plugin's included.
