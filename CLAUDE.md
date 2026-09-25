# engineering-rules

The map for this repository: the checks, where things live, where to start. Read it first.

## The checks

- lint: `shellcheck -x -P SCRIPTDIR -S style install.sh hooks/*.sh hooks/tests/*.sh tests/*.sh`
- typecheck: none
- test: `find . -name '*.test.sh' -not -path './.git/*' | while read -r t; do bash "$t" | tail -n 1; done`
- ui_check: none

## Key directories

- `law/`: the two always-on files, the core law and the code rules; both size-capped by `tests/short-law.test.sh`.
- `skills/`: one folder per command (`brainstorm`, `audit`, `triage`, `design-spec`, `release-notes`, `explain`, `update-engineering-rules`, `status-report`).
- `agents/`: the one helper, the read-only reader.
- `hooks/`: the hook scripts, their shared helpers (`hook-input.sh`, `progress-log.sh`, `path-kind.sh`) and `hooks/tests/`.
- `settings/`: `hooks.json` (what the installer merges into settings.json), `loop.json` (the loop's defaults), `claude-md-block.md`.
- `references/`: the numbered pages the law cites, one file each, grouped by number.
- `tests/`: the repository's own tests and their fixtures (`tests/fixtures/`).

## Entry points

- `law/engineering-law.md`: the loop, the guards, the map rule, the helpers rule; imported into every session.
- `law/engineering-code.md`: the caps, the bans, the principles; copied into `~/.claude/rules/`.
- `settings/loop.json`: lint, typecheck, test, ui_check, discovery_budget, risk_regex, ui_path_regex.
- `hooks/risk-zone.sh`: the first edit to a risk-zone file becomes a permission prompt.
- `hooks/edit-guard.sh`: the code-rules hook, which warns beside the tool result and never blocks.
- `hooks/loop-reminder.sh`: the one-line reminder on every prompt.
- `install.sh`: install, `--check`, `--uninstall`.
- `tests/fixtures/short-law-pins.txt`: what the law must keep saying, one string per line.
- `CHANGELOG.md`: one entry per version, newest first; the version is the top entry's.

## Conventions

- Bash as macOS ships it (3.2): `set -u`, no arrays, no `[[`-only features; every hook exits 0 and never blocks on its own bug.
- A test file ends with `N passed, M failed`; each check is shown failing on a broken copy through the override its header names.
- A rule lives on the cheapest layer that binds: the core, the code rules, a command's skill, a reference page.
- Rule changes ship through `/update-engineering-rules`: worktree, tests, changelog and version, install, fresh-session check.
- Commits: explicit paths, one-line message, no attribution trailer.

risk_regex: install\.sh|settings/|hooks/[^/]*\.sh$
