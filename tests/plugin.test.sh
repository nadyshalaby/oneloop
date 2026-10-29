#!/bin/bash
# Guard: the plugin manifests are what Claude Code installs. .claude-plugin/plugin.json names
# the plugin oneloop, with a semantic version equal to the top CHANGELOG entry's and to the
# marketplace entry's; .claude-plugin/marketplace.json names the marketplace and its owner and
# lists this repository (source ".") as its one plugin; hooks/hooks.json parses; every skill
# folder carries a SKILL.md named after its folder; package.json, the OpenCode package, is named
# oneloop at the manifest's version with an entry that exists; and the installer era's files are gone
# (install.sh, settings/hooks.json, settings/claude-md-block.md, hooks/re-anchor.sh, a rules
# folder). Run: bash tests/plugin.test.sh
# PLUGIN_ROOT points the test at another tree, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT="${PLUGIN_ROOT:-$(repo_root)}" || exit 1
MANIFEST="$ROOT/.claude-plugin/plugin.json"
MARKET="$ROOT/.claude-plugin/marketplace.json"
PACKAGE="$ROOT/package.json"
GONE="install.sh settings/hooks.json settings/claude-md-block.md hooks/re-anchor.sh rules tests/install.test.sh"

# parses <file>: yes when the file is JSON.
parses() { if jq -e . "$1" > /dev/null 2>&1; then echo yes; else echo no; fi; }

# top_version <root>: the version of the changelog's top entry.
top_version() { sed -n -E 's/^- \*\*([0-9]+\.[0-9]+\.[0-9]+)\*\*.*/\1/p' "$1/CHANGELOG.md" | head -n 1; }

# semantic <version>: yes when it is three numbers.
semantic() { if printf '%s' "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then echo yes; else echo no; fi; }

# skill_name <SKILL.md>: its frontmatter name.
skill_name() { sed -n '2,/^---$/p' "$1" | sed -n -E 's/^name: *//p' | head -n 1; }

# left_over <root>: every installer-era path still present.
left_over() { for p in $GONE; do [ -e "$1/$p" ] && printf '%s\n' "$p"; done; return 0; }

test_the_plugin_manifest() {
  assert_eq "plugin.json parses" yes "$(parses "$MANIFEST")"
  assert_eq "the plugin is named oneloop" oneloop "$(jq -r .name "$MANIFEST")"
  version=$(jq -r .version "$MANIFEST")
  assert_eq "its version is semantic" yes "$(semantic "$version")"
  assert_eq "and equal to the changelog's top entry" "$(top_version "$ROOT")" "$version"
  assert_contains "it says what it is" "One loop for every task" "$(jq -r .description "$MANIFEST")"
}

test_the_marketplace_manifest() {
  assert_eq "marketplace.json parses" yes "$(parses "$MARKET")"
  assert_eq "the marketplace is named oneloop" oneloop "$(jq -r .name "$MARKET")"
  assert_eq "it has an owner" yes "$(jq -r 'if (.owner.name // "") != "" then "yes" else "no" end' "$MARKET")"
  assert_eq "it lists one plugin" 1 "$(jq '.plugins | length' "$MARKET")"
  assert_eq "the plugin is oneloop at the repository root" "oneloop ." "$(jq -r '.plugins[0] | "\(.name) \(.source)"' "$MARKET")"
  assert_eq "with the manifest's version" "$(jq -r .version "$MANIFEST")" "$(jq -r '.plugins[0].version' "$MARKET")"
}

test_hooks_and_skills() {
  assert_eq "hooks/hooks.json parses" yes "$(parses "$ROOT/hooks/hooks.json")"
  for dir in "$ROOT"/skills/*/; do
    name=${dir%/}; name=${name##*/}
    assert_eq "skills/$name names itself" "$name" "$(skill_name "$dir/SKILL.md")"
  done
}

test_the_installer_era_is_gone() {
  assert_eq "no installer-era file is left" "" "$(left_over "$ROOT")"
}

# The OpenCode package: package.json at the root is what `opencode plugin add` installs.
test_the_opencode_package() {
  assert_eq "package.json parses" yes "$(parses "$PACKAGE")"
  assert_eq "the package is named oneloop" oneloop "$(jq -r .name "$PACKAGE")"
  assert_eq "with the manifest's version" "$(jq -r .version "$MANIFEST")" "$(jq -r .version "$PACKAGE")"
  entry=$(jq -r '.exports["."] // empty' "$PACKAGE")
  assert_eq "its entry exists" yes "$([ -n "$entry" ] && [ -f "$ROOT/$entry" ] && echo yes || echo no)"
}

# The checks can fail: a version behind the changelog, a marketplace pointing elsewhere, a
# leftover installer and a skill named after something else are each named.
test_planted_breaches_are_named() {
  tree="$WORK/tree"
  mkdir -p "$tree/.claude-plugin" "$tree/skills/audit"
  printf '{"name": "oneloop", "version": "1.2.3"}\n' > "$tree/.claude-plugin/plugin.json"
  printf -- '- **1.2.4**: the next one\n- **1.2.3**: this one\n' > "$tree/CHANGELOG.md"
  assert_eq "the changelog's top version is read" "1.2.4" "$(top_version "$tree")"
  assert_eq "a manifest behind it differs" no "$([ "$(top_version "$tree")" = "$(jq -r .version "$tree/.claude-plugin/plugin.json")" ] && echo yes || echo no)"
  printf '{"name": "oneloop", "owner": {"name": "x"}, "plugins": [{"name": "oneloop", "source": "./plugins/oneloop"}]}\n' > "$tree/.claude-plugin/marketplace.json"
  assert_eq "a marketplace pointing elsewhere is named" "oneloop ./plugins/oneloop" "$(jq -r '.plugins[0] | "\(.name) \(.source)"' "$tree/.claude-plugin/marketplace.json")"
  : > "$tree/install.sh"
  assert_eq "a leftover installer is named" "install.sh" "$(left_over "$tree")"
  printf -- '---\nname: engineering-rules:audit\n---\n' > "$tree/skills/audit/SKILL.md"
  assert_eq "a skill named after something else is named" "engineering-rules:audit" "$(skill_name "$tree/skills/audit/SKILL.md")"
  assert_eq "a non-semantic version is named" no "$(semantic 1.2)"
}

test_the_plugin_manifest
test_the_marketplace_manifest
test_hooks_and_skills
test_the_installer_era_is_gone
test_the_opencode_package
test_planted_breaches_are_named
report
