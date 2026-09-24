#!/bin/bash
# Fixture tests for install.sh, each run in a fake home, never the real ~/.claude. A first
# install wires every piece and keeps what the user had; a second changes nothing; --uninstall
# puts CLAUDE.md back byte for byte and settings.json back as the same JSON, byte for byte in
# the two-space layout Claude Code writes; a path that is not this setup's, a damaged block or
# a broken settings file is refused with nothing changed; permissions and a link leading to a
# file survive; the code rules land as a plain copy beside the user's own rules and leave with
# the uninstall; --check fails when a piece is missing or stale. INSTALL_SH points the test at another
# copy of the installer, kept in the repository root, which is how it proves it can fail.
# Run: bash tests/install.test.sh
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SCRIPT="${INSTALL_SH:-$ROOT/install.sh}"
PLUGIN='engineering-rules@engineering-rules-marketplace'
unset CLAUDE_CONFIG_DIR

# fresh_home <name>: an empty fake home with a config dir; its path on stdout.
fresh_home() { mkdir -p "$WORK/$1/.claude" && printf '%s' "$WORK/$1"; }

# run_install <home> [option]: the installer run against that home; its output, then "exit=N".
run_install() {
  out=$(HOME="$1" bash "$SCRIPT" ${2:+"$2"} 2>&1)
  printf '%s\nexit=%s' "$out" "$?"
}

# seed <home>: settings.json in Claude Code's layout with the user's own hook, the plugin on and
# the plugin's status line, and a CLAUDE.md of the user's own rules.
seed() {
  jq -n --arg p "$PLUGIN" '{model: "opus", hooks: {Stop: [{hooks: [{type: "command", command: "bash ~/own-stop.sh"}]}]},
    statusLine: {type: "command", command: "bash ~/.claude/plugins/cache/engineering-rules-marketplace/engineering-rules/2.21.0/hooks/statusline.sh"},
    enabledPlugins: {($p): true, "other@market": true}}' > "$1/.claude/settings.json"
  printf '# My rules\n- keep it casual\n' > "$1/.claude/CLAUDE.md"
}

# setting <config dir> <jq path>: one value of its settings.json, raw.
setting() { jq -r "$2" "$1/settings.json"; }

# our_hooks <config dir>: how many of its settings hooks run a script of this setup.
our_hooks() { jq '[(.hooks // {})[][] | .hooks[] | select((.command // "") | contains("/engineering-rules/hooks/"))] | length' "$1/settings.json"; }

# linked_skills <config dir>: how many skill links lead to a real SKILL.md.
linked_skills() {
  n=0
  for link in "$1"/skills/*; do
    if [ -L "$link" ] && [ -f "$link/SKILL.md" ]; then n=$((n + 1)); fi
  done
  printf '%s' "$n"
}

# linked_agents <config dir>: how many agent links lead to a real file.
linked_agents() {
  n=0
  for link in "$1"/agents/*.md; do
    if [ -L "$link" ] && [ -f "$link" ]; then n=$((n + 1)); fi
  done
  printf '%s' "$n"
}

# agent_total: how many helper agents the repository ships.
agent_total() {
  set -- "$ROOT"/agents/*.md
  printf '%s' "$#"
}

# skill_total: how many skills the repository ships.
skill_total() {
  set -- "$ROOT"/skills/*/SKILL.md
  printf '%s' "$#"
}

# exists <path>: yes or no.
exists() { if [ -e "$1" ] || [ -L "$1" ]; then echo yes; else echo no; fi; }

# file_mode <file>: its permission bits, on GNU or BSD stat.
file_mode() { if stat -c '%a' "$1" > /dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi; }

# plain_copy <file>: yes when it is a plain file, not a link, holding the repository's code rules.
plain_copy() {
  if [ -f "$1" ] && [ ! -L "$1" ] && cmp -s "$ROOT/law/engineering-code.md" "$1"; then echo yes; else echo no; fi
}

# snapshot <config dir>: every file and link the installer owns, as checksums and targets.
snapshot() {
  cksum < "$1/CLAUDE.md"; cksum < "$1/settings.json"; cksum < "$1/backups/engineering-rules/state.json"
  cksum < "$1/rules/engineering-code.md"
  for link in "$1"/skills/* "$1"/agents/*; do printf '%s -> %s\n' "${link##*/}" "$(readlink "$link")"; done
}

test_first_install_wires_every_piece() {
  home=$(fresh_home first); seed "$home"; cfg="$home/.claude"
  cp "$cfg/settings.json" "$WORK/first.settings"; cp "$cfg/CLAUDE.md" "$WORK/first.md"
  out=$(run_install "$home")
  assert_contains "the install exits 0" "exit=0" "$out"
  assert_contains "and checks itself wired" "engineering-rules: installed and wired" "$out"
  assert_eq "the home leads to the repository" "$ROOT" "$(cd -P "$cfg/engineering-rules" && pwd)"
  assert_eq "every skill is linked under its name" "$(skill_total)" "$(linked_skills "$cfg")"
  assert_eq "every helper agent is linked under its file name" "$(agent_total)" "$(linked_agents "$cfg")"
  assert_contains "CLAUDE.md imports the short law" "@~/.claude/engineering-rules/law/engineering-law.md" "$(cat "$cfg/CLAUDE.md")"
  assert_eq "below the user's own lines" "# My rules" "$(head -n 1 "$cfg/CLAUDE.md")"
  assert_eq "the code rules are a plain copy in the rules folder" "yes" "$(plain_copy "$cfg/rules/engineering-code.md")"
  assert_eq "every hook of the fragment is in settings.json" "$(jq '[.hooks[][] | .hooks[]] | length' "$ROOT/settings/hooks.json")" "$(our_hooks "$cfg")"
  assert_eq "the user's own hook stays" "bash ~/own-stop.sh" "$(setting "$cfg" '.hooks.Stop[0].hooks[0].command')"
  assert_contains "the plugin's status line is taken over" "/engineering-rules/hooks/statusline.sh" "$(setting "$cfg" '.statusLine.command')"
  assert_eq "the plugin is off" "false" "$(setting "$cfg" ".enabledPlugins[\"$PLUGIN\"]")"
  assert_eq "another plugin and the model are untouched" "true opus" "$(setting "$cfg" '.enabledPlugins["other@market"]') $(setting "$cfg" '.model')"
  assert_eq "the backup holds settings.json as it was" "$(cksum < "$WORK/first.settings")" "$(cksum < "$(ls "$cfg"/backups/engineering-rules/*/settings.json)")"
  assert_contains "--check passes" "exit=0" "$(run_install "$home" --check)"
}

test_a_second_install_changes_nothing() {
  cfg="$WORK/first/.claude"
  before=$(snapshot "$cfg")
  assert_contains "a second install exits 0" "exit=0" "$(run_install "$WORK/first")"
  assert_eq "and changes nothing" "$before" "$(snapshot "$cfg")"
}

test_uninstall_puts_back_what_it_replaced() {
  cfg="$WORK/first/.claude"
  assert_contains "the uninstall exits 0" "exit=0" "$(run_install "$WORK/first" --uninstall)"
  assert_eq "CLAUDE.md is back byte for byte" "$(cksum < "$WORK/first.md")" "$(cksum < "$cfg/CLAUDE.md")"
  assert_eq "settings.json is back byte for byte" "$(cksum < "$WORK/first.settings")" "$(cksum < "$cfg/settings.json")"
  assert_eq "no skill link is left" "0" "$(linked_skills "$cfg")"
  assert_eq "no agent link, and not the agents folder the install made" "0 no" "$(linked_agents "$cfg") $(exists "$cfg/agents")"
  assert_eq "the home link is gone" "no" "$(exists "$cfg/engineering-rules")"
  assert_eq "the code rules and the rules folder the install made are gone" "no" "$(exists "$cfg/rules")"
  assert_eq "the backups stay" "yes" "$(exists "$cfg/backups/engineering-rules")"
  out=$(run_install "$WORK/first" --check)
  assert_contains "--check now fails" "exit=1" "$out"
  assert_contains "and names what is missing" "missing: the managed block in $cfg/CLAUDE.md" "$out"
}

test_compact_json_comes_back_as_the_same_json() {
  home=$(fresh_home compact); seed "$home"; cfg="$home/.claude"
  jq -c . "$cfg/settings.json" > "$WORK/compact.json"; cp "$WORK/compact.json" "$cfg/settings.json"
  run_install "$home" > /dev/null; run_install "$home" --uninstall > /dev/null
  assert_eq "compact settings come back as the same JSON" "$(jq -S . "$WORK/compact.json")" "$(jq -S . "$cfg/settings.json")"
  assert_eq "in jq's layout, as the contract says" "differ" "$(cmp -s "$WORK/compact.json" "$cfg/settings.json" && echo same || echo differ)"
}

test_what_is_not_ours_is_refused_with_nothing_changed() {
  home=$(fresh_home conflict); seed "$home"; cfg="$home/.claude"
  mkdir -p "$cfg/skills/engineering-rules:build"
  before="$(cksum < "$cfg/settings.json")$(cksum < "$cfg/CLAUDE.md")"
  out=$(run_install "$home")
  assert_contains "a skill folder that is not ours is refused" "exit=1" "$out"
  assert_contains "and named" "skills/engineering-rules:build" "$out"
  assert_eq "settings.json and CLAUDE.md are untouched" "$before" "$(cksum < "$cfg/settings.json")$(cksum < "$cfg/CLAUDE.md")"
  assert_eq "nothing is linked and no record written" "no no" "$(exists "$cfg/engineering-rules") $(exists "$cfg/backups/engineering-rules/state.json")"
  rmdir "$cfg/skills/engineering-rules:build"
  mkdir -p "$cfg/agents"; rm -f "$cfg/agents/er-reviewer.md"; printf 'mine\n' > "$cfg/agents/er-reviewer.md"
  out=$(run_install "$home")
  assert_contains "an agent file that is not ours is refused" "exit=1" "$out"
  assert_contains "and named" "agents/er-reviewer.md" "$out"
  rm -r "$cfg/agents"
  printf '<!-- engineering-rules:begin (half)\nno end marker\n' >> "$cfg/CLAUDE.md"
  assert_contains "a block missing its end marker is refused" "missing or doubled marker" "$(run_install "$home")"
  seed "$home"; printf '{ broken' > "$cfg/settings.json"
  assert_contains "a settings file that is not JSON is refused" "is not a JSON object; nothing changed" "$(run_install "$home")"
  assert_eq "and left as it was" "{ broken" "$(cat "$cfg/settings.json")"
}

test_permissions_and_links_survive() {
  home=$(fresh_home modes); seed "$home"; cfg="$home/.claude"; dot="$WORK/dotfiles/settings.json"
  mkdir -p "$WORK/dotfiles"; mv "$cfg/settings.json" "$dot"; ln -s "$dot" "$cfg/settings.json"
  chmod 600 "$dot"; chmod 640 "$cfg/CLAUDE.md"
  run_install "$home" > /dev/null
  assert_eq "a linked settings.json stays a link" "yes" "$([ -L "$cfg/settings.json" ] && echo yes || echo no)"
  assert_eq "and the install lands in its target" "false" "$(jq -r ".enabledPlugins[\"$PLUGIN\"]" "$dot")"
  assert_eq "each file keeps its permissions" "600 640" "$(file_mode "$dot") $(file_mode "$cfg/CLAUDE.md")"
  run_install "$home" --uninstall > /dev/null
  assert_eq "through the uninstall too" "600 640" "$(file_mode "$dot") $(file_mode "$cfg/CLAUDE.md")"
}

test_a_fresh_machine_is_left_as_it_was() {
  home=$(fresh_home fresh); cfg="$home/.claude"
  assert_contains "an install with no settings or CLAUDE.md exits 0" "exit=0" "$(run_install "$home")"
  run_install "$home" --uninstall > /dev/null
  assert_eq "the uninstall removes the files the install created" "no no" "$(exists "$cfg/CLAUDE.md") $(exists "$cfg/settings.json")"
}

test_an_own_status_line_is_kept() {
  home=$(fresh_home ownline); seed "$home"; cfg="$home/.claude"
  jq '.statusLine = {type: "command", command: "sh ~/my-line.sh"}' "$cfg/settings.json" > "$WORK/own.json"
  cp "$WORK/own.json" "$cfg/settings.json"
  run_install "$home" > /dev/null
  assert_eq "a status line of the user's own is kept" "sh ~/my-line.sh" "$(setting "$cfg" '.statusLine.command')"
  run_install "$home" --uninstall > /dev/null
  assert_eq "and is still there after the uninstall" "sh ~/my-line.sh" "$(setting "$cfg" '.statusLine.command')"
}

test_stale_links_go_and_check_names_a_missing_one() {
  home=$(fresh_home check); seed "$home"; cfg="$home/.claude"
  mkdir -p "$cfg/skills"; ln -s "$cfg/engineering-rules/skills/gone" "$cfg/skills/engineering-rules:gone"
  run_install "$home" > /dev/null
  assert_eq "a link a removed skill left behind is cleared" "no" "$(exists "$cfg/skills/engineering-rules:gone")"
  rm "$cfg/skills/engineering-rules:build"
  out=$(run_install "$home" --check)
  assert_contains "--check fails on a missing skill link" "exit=1" "$out"
  assert_contains "and names it" "missing: the skill link $cfg/skills/engineering-rules:build" "$out"
  rm "$cfg/agents/er-reader.md"
  assert_contains "--check names a missing agent link" "missing: the agent link $cfg/agents/er-reader.md" "$(run_install "$home" --check)"
}

# The rules folder may hold the user's own rules: they stay through the install and the
# uninstall, a file of theirs where the copy goes is refused, a link an earlier layout left is
# made a plain copy (a link would not load), and a copy edited by hand is named stale.
test_the_code_rules_live_beside_the_users_own() {
  home=$(fresh_home rules); seed "$home"; cfg="$home/.claude"
  mkdir -p "$cfg/rules"; printf '# mine\n' > "$cfg/rules/mine.md"
  printf '# my own code rules\n' > "$cfg/rules/engineering-code.md"
  before=$(cksum < "$cfg/settings.json")
  out=$(run_install "$home")
  assert_contains "a code rules file the user wrote is refused" "exit=1" "$out"
  assert_contains "and named" "$cfg/rules/engineering-code.md (not a copy this installer wrote)" "$out"
  assert_eq "and left as it was, with settings.json" "# my own code rules $before" "$(cat "$cfg/rules/engineering-code.md") $(cksum < "$cfg/settings.json")"
  rm "$cfg/rules/engineering-code.md"; ln -s "$ROOT/law/engineering-code.md" "$cfg/rules/engineering-code.md"
  assert_contains "a link of this setup's is taken over" "exit=0" "$(run_install "$home")"
  assert_eq "by a plain copy" "yes" "$(plain_copy "$cfg/rules/engineering-code.md")"
  if [ ! -L "$cfg/rules/engineering-code.md" ]; then printf 'edited by hand\n' >> "$cfg/rules/engineering-code.md"; fi
  out=$(run_install "$home" --check)
  assert_contains "--check fails on a copy edited by hand" "exit=1" "$out"
  assert_contains "and names it stale" "stale: $cfg/rules/engineering-code.md" "$out"
  run_install "$home" > /dev/null
  assert_eq "a second install puts the copy right" "yes" "$(plain_copy "$cfg/rules/engineering-code.md")"
  run_install "$home" --uninstall > /dev/null
  assert_eq "the uninstall takes the copy away" "no" "$(exists "$cfg/rules/engineering-code.md")"
  assert_eq "and keeps the user's own rules and their folder" "# mine" "$(cat "$cfg/rules/mine.md")"
}

test_a_moved_config_dir_gets_full_paths() {
  cfg="$WORK/elsewhere"; mkdir -p "$cfg"
  HOME="$WORK/nohome" CLAUDE_CONFIG_DIR="$cfg" bash "$SCRIPT" > /dev/null 2>&1
  assert_contains "the import names the moved home in full" "@$cfg/engineering-rules/law/engineering-law.md" "$(cat "$cfg/CLAUDE.md")"
  assert_contains "and so do the hooks" "bash \"$cfg/engineering-rules/hooks/" "$(jq -r '[.hooks[][] | .hooks[] | .command][0]' "$cfg/settings.json")"
}

test_first_install_wires_every_piece
test_a_second_install_changes_nothing
test_uninstall_puts_back_what_it_replaced
test_compact_json_comes_back_as_the_same_json
test_what_is_not_ours_is_refused_with_nothing_changed
test_permissions_and_links_survive
test_a_fresh_machine_is_left_as_it_was
test_an_own_status_line_is_kept
test_stale_links_go_and_check_names_a_missing_one
test_the_code_rules_live_beside_the_users_own
test_a_moved_config_dir_gets_full_paths
report
