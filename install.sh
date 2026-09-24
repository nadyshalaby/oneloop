#!/bin/bash
# engineering-rules installer. Wires this repository into Claude Code with no plugin:
#   ~/.claude/engineering-rules   a link to this repository, unless it IS this repository
#   ~/.claude/skills/<name>       one link per skill, named by its `name:` line, so every
#                                 /engineering-rules:<route> command keeps its name
#   ~/.claude/CLAUDE.md           one managed block that imports law/engineering-law.md
#   ~/.claude/rules/engineering-code.md
#                                 a copy of law/engineering-code.md, never a link, because
#                                 Claude Code skips a linked rules file; it loads the first
#                                 time a code file is read
#   ~/.claude/settings.json       the hooks and the status line of settings/hooks.json, and the
#                                 old engineering-rules plugin switched off
# Nothing changes until every check passes. Each file it changes is first copied to
# ~/.claude/backups/engineering-rules/<time>/, then replaced in one rename that keeps its
# permissions and any link leading to it. Running it twice changes nothing. --uninstall puts
# back what the first install replaced: CLAUDE.md byte for byte, settings.json as the same
# JSON (byte for byte when it was in the two-space layout Claude Code writes). --check changes
# nothing and exits 1 when a piece is missing. Needs bash 3.2+ and jq. CLAUDE_CONFIG_DIR, when
# set, replaces ~/.claude.
# Usage: bash install.sh [--check | --uninstall]
set -u
umask 077

REPO=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ER_HOME="$CFG/engineering-rules"
SKILLS_DIR="$CFG/skills"
CLAUDE_MD="$CFG/CLAUDE.md"
RULES_DIR="$CFG/rules"
RULES_FILE="$RULES_DIR/engineering-code.md"
RULES_SRC="$REPO/law/engineering-code.md"
RULES_MARK='managed-by: engineering-rules'
SETTINGS="$CFG/settings.json"
BACKUPS="$CFG/backups/engineering-rules"
STATE="$BACKUPS/state.json"
PLUGIN_KEY="engineering-rules@engineering-rules-marketplace"
BEGIN_MARK='<!-- engineering-rules:begin'
END_MARK='<!-- engineering-rules:end -->'
HOOK_MARK='/engineering-rules/hooks/'
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/engineering-rules-install.XXXXXX") || exit 1
trap 'rm -rf "$SCRATCH"' EXIT

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

# home_ref <tilde|shell>: the home as CLAUDE.md imports it or a settings command expands it; an
# absolute path when CLAUDE_CONFIG_DIR moved the config away from ~/.claude.
home_ref() {
  if [ "$CFG" != "$HOME/.claude" ]; then printf '%s' "$ER_HOME"; return; fi
  case "$1" in
    tilde) printf '%s/.claude/engineering-rules' "~" ;;
    *) printf '%s/.claude/engineering-rules' "\$HOME" ;;
  esac
}

# skill_name <SKILL.md>: the `name:` value of its frontmatter, which is the command it answers to.
skill_name() { sed -n '2,/^---$/p' "$1" | sed -n -E 's/^name: *//p' | head -n 1; }

# leads_here <path>: the path resolves to this repository.
leads_here() { [ "$(cd -P "$1" 2>/dev/null && pwd)" = "$REPO" ]; }

# ours <path>: the path is a link whose target lies inside this setup.
ours() {
  [ -L "$1" ] || return 1
  case "$(readlink "$1")" in "$ER_HOME"/*|"$REPO"/*) return 0 ;; *) return 1 ;; esac
}

# managed_rules <file>: a plain file carrying the marker this installer writes into its copy.
managed_rules() { [ -f "$1" ] && [ ! -L "$1" ] && grep -qF "$RULES_MARK" "$1"; }

# resolve <file>: where a chain of links ends, so a write replaces the target, never the link.
resolve() {
  file=$1
  while [ -L "$file" ]; do
    to=$(readlink "$file")
    case "$to" in /*) file=$to ;; *) file="${file%/*}/$to" ;; esac
  done
  printf '%s' "$file"
}

# replace_file <file> <content>: the content takes the file's place in one rename, keeping the
# file's permissions and any link that leads to it.
replace_file() {
  target=$(resolve "$1")
  tmp="$target.er-tmp"
  if [ -e "$target" ]; then cp -p "$target" "$tmp"; else : > "$tmp"; fi
  cat "$2" > "$tmp" && mv "$tmp" "$target"
}

# block_intact <file>: the file has no managed block, or exactly one whose end marker follows.
block_intact() {
  [ -f "$1" ] || return 0
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) == 1 { begins++; if (open) bad = 1; open = 1 }
    index($0, e) == 1 { if (open) open = 0; else bad = 1 }
    END { exit !(bad == 0 && open == 0 && begins <= 1) }' "$1"
}

# conflicts: every path the install would overwrite that is not already this setup's.
conflicts() {
  if { [ -e "$ER_HOME" ] || [ -L "$ER_HOME" ]; } && ! leads_here "$ER_HOME"; then
    printf '%s (leads somewhere other than %s)\n' "$ER_HOME" "$REPO"
  fi
  for skill in "$REPO"/skills/*/SKILL.md; do
    link="$SKILLS_DIR/$(skill_name "$skill")"
    if { [ -e "$link" ] || [ -L "$link" ]; } && ! ours "$link"; then printf '%s\n' "$link"; fi
  done
  if { [ -e "$RULES_FILE" ] || [ -L "$RULES_FILE" ]; } && ! ours "$RULES_FILE" && ! managed_rules "$RULES_FILE"; then
    printf '%s (not a copy this installer wrote)\n' "$RULES_FILE"
  fi
}

# preflight: every reason to stop, checked before anything is changed.
preflight() {
  found=$(conflicts)
  [ -z "$found" ] || die "refusing to overwrite what is not this setup's; nothing changed:
$found"
  if [ -e "$SETTINGS" ] && ! jq -e 'type == "object"' "$SETTINGS" > /dev/null 2>&1; then
    die "$SETTINGS is not a JSON object; nothing changed"
  fi
  block_intact "$CLAUDE_MD" || die "the managed block in $CLAUDE_MD has a missing or doubled marker; fix it by hand; nothing changed"
}

# record_state: what the first install replaces, kept so --uninstall can put it back.
record_state() {
  [ -f "$STATE" ] && return 0
  mkdir -p "$BACKUPS"
  had_md=false had_json=false had_rules=false src=/dev/null
  [ -e "$CLAUDE_MD" ] && had_md=true
  [ -d "$RULES_DIR" ] && had_rules=true
  [ -e "$SETTINGS" ] && { had_json=true; src=$SETTINGS; }
  jq -n --slurpfile s "$src" --arg key "$PLUGIN_KEY" --argjson md "$had_md" --argjson js "$had_json" --argjson rd "$had_rules" '
    ($s[0] // {}) as $o | ($o.enabledPlugins // {}) as $p
    | {statusLine: ($o.statusLine // null), plugin: (if $p | has($key) then $p[$key] else null end),
       hadHooks: ($o | has("hooks")), hadSettings: $js, hadClaudeMd: $md, hadRulesDir: $rd}' > "$STATE"
}

# backup: a copy of every file the run may change, before it changes any, in a folder of its
# own, so two runs in one second never write over each other's copies.
backup() {
  mkdir -p "$BACKUPS"
  dir=$(mktemp -d "$BACKUPS/$(date '+%Y%m%d-%H%M%S').XXXX") || die "could not make a backup folder in $BACKUPS; nothing changed"
  for file in "$CLAUDE_MD" "$SETTINGS" "$RULES_FILE"; do
    if [ -f "$file" ]; then cp -p "$file" "$dir/"; fi
  done
  say "backed up to $dir"
}

link_home() {
  leads_here "$ER_HOME" && return 0
  ln -s "$REPO" "$ER_HOME" && say "linked $ER_HOME -> $REPO"
}

# link_skills: one link per skill, then the links a renamed or removed skill left behind go.
link_skills() {
  mkdir -p "$SKILLS_DIR"
  wanted=""
  for skill in "$REPO"/skills/*/SKILL.md; do
    dir=${skill%/SKILL.md}
    name=$(skill_name "$skill")
    ln -sfn "$ER_HOME/skills/${dir##*/}" "$SKILLS_DIR/$name"
    wanted="$wanted$name
"
  done
  for link in "$SKILLS_DIR"/*; do
    ours "$link" || continue
    printf '%s' "$wanted" | grep -qxF "${link##*/}" || { rm "$link" && say "removed stale link $link"; }
  done
  say "linked $(printf '%s' "$wanted" | grep -c .) skills into $SKILLS_DIR"
}

# copy_rules: the code rules copied into the rules folder, over a link of this setup's that an
# earlier layout left; a copy already the same is left alone.
copy_rules() {
  mkdir -p "$RULES_DIR"
  if [ -L "$RULES_FILE" ]; then rm "$RULES_FILE"; fi
  cmp -s "$RULES_SRC" "$RULES_FILE" && return 0
  replace_file "$RULES_FILE" "$RULES_SRC" && say "copied the code rules to $RULES_FILE"
}

# write_block: the managed block replaced where it is, or appended after one blank line. A file
# that did not end in a newline gets one.
write_block() {
  sed "s#__ER_HOME__#$(home_ref tilde)#" "$REPO/settings/claude-md-block.md" > "$SCRATCH/block"
  if [ -f "$CLAUDE_MD" ] && grep -qF "$BEGIN_MARK" "$CLAUDE_MD"; then
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" -v blk="$SCRATCH/block" '
      index($0, b) == 1 { while ((getline l < blk) > 0) print l; skip = 1; next }
      skip { if (index($0, e) == 1) skip = 0; next }
      { print }' "$CLAUDE_MD" > "$SCRATCH/claude-md"
  else
    {
      if [ -s "$CLAUDE_MD" ]; then
        cat "$CLAUDE_MD"
        [ -z "$(tail -c 1 "$CLAUDE_MD")" ] || printf '\n'
        printf '\n'
      fi
      cat "$SCRATCH/block"
    } > "$SCRATCH/claude-md"
  fi
  replace_file "$CLAUDE_MD" "$SCRATCH/claude-md" && say "wrote the managed block in $CLAUDE_MD"
}

# drop_block: the managed block and the one blank line the install put before it, removed.
drop_block() {
  [ -f "$CLAUDE_MD" ] && grep -qF "$BEGIN_MARK" "$CLAUDE_MD" || return 0
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) == 1 { held = 0; skip = 1; next }
    skip { if (index($0, e) == 1) skip = 0; next }
    { if (held) print ""; held = 0; if ($0 == "") { held = 1; next } print }
    END { if (held) print "" }' "$CLAUDE_MD" > "$SCRATCH/claude-md"
  replace_file "$CLAUDE_MD" "$SCRATCH/claude-md" && say "removed the managed block from $CLAUDE_MD"
}

# fragment: settings/hooks.json with its home rewritten for this machine's config dir.
fragment() {
  jq --arg home "$(home_ref shell)" '(.. | strings) |= gsub("\\$HOME/\\.claude/engineering-rules"; $home)' "$REPO/settings/hooks.json"
}

# JQ_DEFS: which hook entries are this setup's, and the hooks object with them taken out. Only a
# matcher group or an event this setup emptied is dropped; one the user left empty stays.
JQ_DEFS=$(cat <<'JQ'
def ours: ((.command // "") | contains($mark)) or ((.args // []) | map(tostring) | any(contains($mark)));
def has_ours: any((.hooks // [])[]; ours);
def without_ours: to_entries | map(if any(.value[]; has_ours)
  then (.value |= [.[] | if has_ours then (.hooks |= map(select(ours | not))) | select((.hooks | length) > 0) else . end])
    | select((.value | length) > 0)
  else . end) | from_entries;
def ours_status: (.statusLine.command // "") | contains($mark + "statusline.sh");
JQ
)

# merged: settings.json with this setup's hooks replaced by the fragment's, the status line
# taken over when it is unset or an engineering-rules one already, and the old plugin off.
merged() {
  jq --argjson frag "$(fragment)" --arg mark "$HOOK_MARK" --arg key "$PLUGIN_KEY" "$JQ_DEFS"'
    .hooks = reduce ($frag.hooks | to_entries[]) as $e ((.hooks // {}) | without_ours; .[$e.key] = ((.[$e.key] // []) + $e.value))
    | if (.statusLine == null) or ((.statusLine.command // "") | contains("engineering-rules")) then .statusLine = $frag.statusLine else . end
    | if (.enabledPlugins // {}) | has($key) then .enabledPlugins[$key] = false else . end' "$SETTINGS"
}

# unmerged: settings.json with this setup's hooks gone and what the first install replaced back.
unmerged() {
  jq --slurpfile st "$STATE" --arg mark "$HOOK_MARK" --arg key "$PLUGIN_KEY" "$JQ_DEFS"'
    $st[0] as $s
    | .hooks = ((.hooks // {}) | without_ours)
    | if .hooks == {} and ($s.hadHooks | not) then del(.hooks) else . end
    | if ours_status then (if $s.statusLine == null then del(.statusLine) else .statusLine = $s.statusLine end) else . end
    | if $s.plugin != null and ((.enabledPlugins // {}) | has($key)) then .enabledPlugins[$key] = $s.plugin else . end' "$SETTINGS"
}

# write_json <function>: the function's output replaces settings.json, only when it parses.
write_json() {
  if ! "$1" > "$SCRATCH/settings" || ! jq -e 'type == "object"' "$SCRATCH/settings" > /dev/null; then
    die "could not rewrite $SETTINGS; it is unchanged"
  fi
  replace_file "$SETTINGS" "$SCRATCH/settings"
}

install() {
  mkdir -p "$CFG"
  preflight
  record_state
  backup
  [ -e "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
  link_home
  link_skills
  write_block
  copy_rules
  write_json merged && say "merged the hooks and the status line into $SETTINGS; the plugin is off"
  say "start a new Claude Code session to load it"
  check
}

# forget_created: a file or folder the first install created and the uninstall left empty goes
# again. A record from before the rules folder existed says nothing of it, so it stays.
forget_created() {
  if [ "$(jq -r '.hadClaudeMd' "$STATE")" = false ] && [ -f "$CLAUDE_MD" ] && [ ! -s "$CLAUDE_MD" ]; then rm -f "$CLAUDE_MD"; fi
  if [ "$(jq -r '.hadSettings' "$STATE")" = false ] && [ "$(jq -c . "$SETTINGS" 2>/dev/null)" = '{}' ]; then rm -f "$SETTINGS"; fi
  if [ "$(jq -r 'if has("hadRulesDir") then .hadRulesDir else true end' "$STATE")" = false ] && [ -d "$RULES_DIR" ] && [ -z "$(find "$RULES_DIR" -mindepth 1 -maxdepth 1)" ]; then rmdir "$RULES_DIR"; fi
}

uninstall() {
  [ -f "$STATE" ] || die "no install record at $STATE; nothing to undo"
  jq -e 'type == "object"' "$SETTINGS" > /dev/null 2>&1 || die "$SETTINGS is missing or not a JSON object; nothing changed"
  block_intact "$CLAUDE_MD" || die "the managed block in $CLAUDE_MD has a missing or doubled marker; fix it by hand; nothing changed"
  backup
  drop_block
  write_json unmerged && say "took the hooks out of $SETTINGS and put back what the install replaced"
  if managed_rules "$RULES_FILE"; then rm "$RULES_FILE" && say "removed $RULES_FILE"; fi
  forget_created
  for link in "$SKILLS_DIR"/*; do
    if ours "$link"; then rm "$link"; fi
  done
  if [ -L "$ER_HOME" ] && leads_here "$ER_HOME"; then rm "$ER_HOME" && say "removed the link $ER_HOME"; fi
  rm -f "$STATE"
  say "uninstalled; the repository itself is untouched"
}

# rules_problem: why the installed code rules are not a plain copy of the repository's, or nothing.
rules_problem() {
  if [ ! -f "$RULES_FILE" ]; then printf 'missing: the code rules at %s' "$RULES_FILE"
  elif [ -L "$RULES_FILE" ]; then printf 'wrong: %s is a link, which Claude Code does not load' "$RULES_FILE"
  elif ! cmp -s "$RULES_SRC" "$RULES_FILE"; then printf 'stale: %s differs from %s; run install.sh again' "$RULES_FILE" "$RULES_SRC"
  fi
}

# check: every piece in place, one line per missing piece, exit 1 when any is.
check() {
  missing=0
  leads_here "$ER_HOME" || { say "missing: $ER_HOME does not lead to $REPO"; missing=1; }
  grep -qF "$BEGIN_MARK" "$CLAUDE_MD" 2>/dev/null || { say "missing: the managed block in $CLAUDE_MD"; missing=1; }
  problem=$(rules_problem)
  [ -z "$problem" ] || { say "$problem"; missing=1; }
  for skill in "$REPO"/skills/*/SKILL.md; do
    link="$SKILLS_DIR/$(skill_name "$skill")"
    ours "$link" && [ -f "$link/SKILL.md" ] || { say "missing: the skill link $link"; missing=1; }
  done
  want=$(jq '[.hooks[][] | .hooks[]] | length' "$REPO/settings/hooks.json")
  have=$(jq --arg mark "$HOOK_MARK" '[(.hooks // {})[][] | .hooks[]? | select((.command // "") | contains($mark))] | length' "$SETTINGS" 2>/dev/null)
  [ "${have:-0}" = "$want" ] || { say "missing: $want hooks in $SETTINGS, found ${have:-0}"; missing=1; }
  plugin=$(jq -r --arg key "$PLUGIN_KEY" '(.enabledPlugins // {})[$key] | tostring' "$SETTINGS" 2>/dev/null)
  [ "$plugin" != true ] || { say "still on: the $PLUGIN_KEY plugin"; missing=1; }
  [ "$missing" = 0 ] && say "engineering-rules: installed and wired"
  return "$missing"
}

main() {
  command -v jq > /dev/null 2>&1 || die "jq is required"
  case "${1:-}" in
    --check) check ;;
    --uninstall) uninstall ;;
    '') install ;;
    *) die "unknown option: $1 (use --check or --uninstall)" ;;
  esac
}

main "$@"
