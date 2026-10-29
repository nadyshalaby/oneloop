# oneloop

The map for this repository: the checks, where things live, where to start. Read it first.

## The checks

- lint: `shellcheck -x -P SCRIPTDIR -S style bin/*.sh hooks/*.sh hooks/tests/*.sh tests/*.sh`
- typecheck: none
- test: `find . -name '*.test.sh' -not -path './.git/*' | while read -r t; do bash "$t" | tail -n 1; done`
- ui_check: none

## Key directories

- `.claude-plugin/`: `plugin.json` (the plugin and its version) and `marketplace.json` (this repository as its own marketplace).
- `law/`: the two always-on files, the core law and the code rules; both size-capped by `tests/short-law.test.sh`.
- `skills/`: one folder per command (`start`, `brainstorm`, `audit`, `triage`, `design-spec`, `release-notes`, `explain`, `update-rules`, `status-report`, `browser`), typed as `/oneloop:<name>`; the browser skill's scripts are in `skills/browser/scripts/`.
- `agents/`: the one helper, the read-only reader, `oneloop:er-reader`.
- `hooks/`: `hooks.json` (the wiring), the hook scripts, their shared helpers (`hook-input.sh`, `progress-log.sh`, `path-kind.sh`) and `hooks/tests/`.
- `opencode/`: `plugin.js`, the OpenCode 2.x entry that `package.json` exports for `opencode plugin add`: it hands OpenCode the law, the skills and the guards' pointers through the same hook scripts.
- `settings/`: `loop.json`, the loop's defaults.
- `bin/`: `setup-statusline.sh`, the one-time status line setup, the one thing a plugin cannot wire.
- `references/`: the numbered pages the law cites, one file each, grouped by number.
- `tests/`: the repository's own tests and their fixtures (`tests/fixtures/`).
- `docs/`: `oneloop-todos/`, this repository's own checklist, `TODO.md` and `TODO.archive.md`, at the place the law gives every project's.

## Entry points

- `law/engineering-law.md`: the loop, the guards, the map rule, the helpers rule; handed to every session as it starts.
- `law/engineering-code.md`: the caps, the bans, the principles; handed to a session with its first code file.
- `hooks/hooks.json`: which script runs on which event, every path under the plugin root.
- `hooks/session-start.sh`: carries the law into the session in two parts (Claude Code keeps only a preview of a hook context over 10,000 characters), and the re-anchor after a compaction or a resume.
- `hooks/code-rules.sh`: carries the code rules in with the first code file read or edited.
- `hooks/risk-zone.sh`: the first edit to a risk-zone file is pointed at: say what changes in 5 lines, ask first only what you judge critical.
- `hooks/scope-check.sh`: an edit outside the scope of the `- [~]` lines in `docs/oneloop-todos/TODO.md`, or while none is in flight, or before the scope line and the explanation are visible in the turn, is pointed at: fix the task line or print what is missing, and go on.
- `hooks/commit-check.sh`: a `git commit` that leaves `docs/oneloop-todos/TODO.md` out is pointed at: tick, stage and commit it right after.
- `hooks/edit-guard.sh`: an edit that adds a code-rule break (a ban, a name, a file kind, a cap, a new unlisted top-level folder) is pointed at with rule, line and fix; the line is fixed in the next edit, a technical exception stays on it as `law-exception:`.
- `CHANGELOG.md`: one entry per version, newest first; the version is the top entry's, and the manifests carry the same one.

## Conventions

- Bash as macOS ships it (3.2): `set -u`, no arrays, no `[[`-only features; every hook exits 0 and never blocks on its own bug.
- A test file ends with `N passed, M failed`, and its header names the override that points it at another copy; code first: a rule change runs the suite and updates what it breaks, and only a hook change gets a new test file.
- A rule lives on the cheapest layer that binds: the core, the code rules, a command's skill, a reference page.
- Rule changes ship through `/oneloop:update-rules`: worktree, tests, changelog and version, push, `claude plugin update`, fresh-session check.
- Commits: explicit paths, one-line message, no attribution trailer.

risk_regex: \.claude-plugin/|settings/|bin/|hooks/[^/]*\.(sh|json)$
