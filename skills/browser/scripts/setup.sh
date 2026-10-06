#!/bin/bash
# Install patchright (Playwright with the automation giveaways patched out) outside any project,
# and move it to its latest release on every run: patchright follows Playwright's version numbers.
# No browser is downloaded: the skill drives the Google Chrome already installed.
set -u
RUNTIME="${BROWSER_RUNTIME:-$HOME/.local/share/oneloop-browser}"
mkdir -p "$RUNTIME"
cd "$RUNTIME" || exit 1
[ -f package.json ] || npm init -y > /dev/null

# installed_version: the patchright version in the runtime, empty when there is none.
installed_version() { node -p "require('$RUNTIME/node_modules/patchright/package.json').version" 2> /dev/null; }

before=$(installed_version)
if npm_output=$(PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i patchright@latest 2>&1); then
  printf 'patchright %s in %s (was %s)\n' "$(installed_version)" "$RUNTIME" "${before:-not installed}"
  exit 0
fi
printf 'npm could not fetch the latest patchright: %s\n' "$(printf '%s\n' "$npm_output" | tail -n 1)" >&2
[ -n "$before" ] || exit 1
printf 'staying on patchright %s\n' "$before"
