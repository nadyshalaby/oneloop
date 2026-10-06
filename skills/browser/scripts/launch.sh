#!/bin/bash
# Start the real Google Chrome with the skill's own saved profile and a local control port, or
# reuse the one already answering on the port and open the URL in it. Usage: launch.sh [url]
set -u
PORT="${BROWSER_PORT:-9334}"
PROFILE="${BROWSER_PROFILE:-$HOME/.local/share/oneloop-browser/profile}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
URL="${1:-about:blank}"
CDP="http://127.0.0.1:$PORT"

# is_up: yes when a Chrome answers on the port.
is_up() { curl -s --max-time 2 "$CDP/json/version" > /dev/null; }

# focus_window: bring this Chrome to the front, by the process that listens on the port (never a
# helper process, never the user's everyday Chrome).
focus_window() {
  pid=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2> /dev/null | head -n 1)
  [ -n "$pid" ] || return 0
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" > /dev/null 2>&1 || true
  printf 'pid %s  port %s\n' "$pid" "$PORT"
}

if is_up; then
  [ "$URL" = about:blank ] || curl -s -X PUT "$CDP/json/new?$URL" > /dev/null
  printf 'already running on port %s\n' "$PORT"
  focus_window
  exit 0
fi
[ -x "$CHROME" ] || { printf 'Google Chrome is not installed at %s\n' "$CHROME" >&2; exit 1; }
mkdir -p "$PROFILE"
nohup "$CHROME" --user-data-dir="$PROFILE" --remote-debugging-port="$PORT" \
  --no-first-run --no-default-browser-check --window-size=1280,900 "$URL" > /dev/null 2>&1 &
tries=0
until is_up || [ "$tries" -ge 20 ]; do
  sleep 0.5
  tries=$((tries + 1))
done
is_up || { printf 'Chrome did not answer on port %s\n' "$PORT" >&2; exit 1; }
curl -s "$CDP/json/version" | grep '"Browser"'
focus_window
printf 'profile %s\n' "$PROFILE"
