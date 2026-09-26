#!/bin/bash
# oneloop status line, set up once by hand: bash bin/setup-statusline.sh [--check | --remove | --force]
# A plugin cannot set Claude Code's status line, so this writes one `statusLine` entry into
# ~/.claude/settings.json: a command that finds the installed oneloop plugin through
# installed_plugins.json on every render (the install path changes with each version), runs its
# hooks/statusline.sh, and otherwise falls back to ~/.claude/statusline-command.sh, then to
# nothing. It takes the status line over when it is unset, already oneloop's, the old
# engineering-rules one, or the personal fallback script the new command keeps calling; any
# other status line is left alone and printed, unless --force. settings.json is copied to
# ~/.claude/backups/oneloop/<time>/ first and replaced in one rename; running it twice changes
# nothing. --check prints the current entry and exits 1 when it is not oneloop's; --remove takes
# oneloop's entry out. CLAUDE_CONFIG_DIR, when set, replaces ~/.claude; ONELOOP_MARKETPLACE
# names the marketplace the plugin was installed from (default oneloop). Needs jq.
set -u
umask 077

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CFG/settings.json"
BACKUPS="$CFG/backups/oneloop"
PLUGIN_ID="oneloop@${ONELOOP_MARKETPLACE:-oneloop}"
# The command Claude Code runs on every render; its variables belong to that shell, and __ID__
# becomes the plugin id.
read -r -d '' COMMAND <<'SH'
c="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; p=$(jq -r '.plugins["__ID__"][0].installPath // empty' "$c/plugins/installed_plugins.json" 2>/dev/null); [ -n "$p" ] && [ -f "$p/hooks/statusline.sh" ] && exec bash "$p/hooks/statusline.sh"; [ -f "$c/statusline-command.sh" ] && exec sh "$c/statusline-command.sh"; echo
SH
COMMAND=${COMMAND%$'\n'}
COMMAND=${COMMAND/__ID__/$PLUGIN_ID}

say() { printf '%s\n' "$*"; }
die() { printf 'setup-statusline.sh: %s\n' "$*" >&2; exit 1; }

# current: the status line command settings.json holds now, empty when none.
current() { [ -f "$SETTINGS" ] && jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null; }

# ours <command>: the command is oneloop's.
ours() { case "$1" in *"$PLUGIN_ID"*statusline.sh*) return 0 ;; *) return 1 ;; esac; }

# replaceable <command>: unset, ours, the old engineering-rules line, or the personal fallback.
replaceable() {
  [ -z "$1" ] && return 0
  ours "$1" && return 0
  case "$1" in *engineering-rules*|*statusline-command.sh*) return 0 ;; *) return 1 ;; esac
}

# settings_ok: settings.json is a JSON object, made empty when missing.
settings_ok() {
  mkdir -p "$CFG" || die "cannot create $CFG"
  [ -e "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
  jq -e 'type == "object"' "$SETTINGS" > /dev/null 2>&1 || die "$SETTINGS is not a JSON object; nothing changed"
}

# rewrite <set|remove>: settings.json with oneloop's status line set, or with the status line gone.
rewrite() {
  case "$1" in
    set) jq --arg c "$COMMAND" '.statusLine = {type: "command", command: $c}' "$SETTINGS" ;;
    *) jq 'del(.statusLine)' "$SETTINGS" ;;
  esac
}

# write_settings <set|remove>: settings.json replaced by that rewrite, after a backup.
write_settings() {
  mkdir -p "$BACKUPS" || die "could not make $BACKUPS; nothing changed"
  dir=$(mktemp -d "$BACKUPS/$(date '+%Y%m%d-%H%M%S').XXXX") || die "could not make a backup folder in $BACKUPS; nothing changed"
  cp -p "$SETTINGS" "$dir/settings.json" || die "could not back up $SETTINGS; nothing changed"
  tmp="$SETTINGS.oneloop-tmp"
  cp -p "$SETTINGS" "$tmp"
  if ! rewrite "$1" > "$tmp" || ! jq -e 'type == "object"' "$tmp" > /dev/null; then
    rm -f "$tmp"; die "could not rewrite $SETTINGS; it is unchanged"
  fi
  mv "$tmp" "$SETTINGS"
  say "backed up to $dir"
}

setup() {
  settings_ok
  now=$(current)
  if [ "$now" = "$COMMAND" ]; then say "the status line is already oneloop's"; return 0; fi
  if ! replaceable "$now" && [ "${1:-}" != --force ]; then
    say "the status line is not oneloop's and was left alone (use --force to replace it):"
    say "  $now"
    return 1
  fi
  write_settings set
  say "the status line now runs oneloop's statusline.sh (the personal script stays the fallback); it shows in new sessions"
}

check() {
  now=$(current)
  if ours "$now"; then say "the status line is oneloop's"; return 0; fi
  say "the status line is not oneloop's: ${now:-<unset>}"
  return 1
}

remove() {
  settings_ok
  now=$(current)
  ours "$now" || { say "the status line is not oneloop's, nothing removed: ${now:-<unset>}"; return 1; }
  write_settings remove
  say "removed oneloop's status line"
}

main() {
  command -v jq > /dev/null 2>&1 || die "jq is required"
  case "${1:-}" in
    --check) check ;;
    --remove) remove ;;
    --force|'') setup "${1:-}" ;;
    *) die "unknown option: $1 (use --check, --remove or --force)" ;;
  esac
}

main "$@"
