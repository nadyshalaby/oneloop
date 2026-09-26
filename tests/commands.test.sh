#!/bin/bash
# Guard: the skills directory holds exactly the commands the law names and the three standalone
# skills, and nothing else, so a removed skill (the workflow, quick, full, an agents switch)
# cannot linger; each command keeps its shape (a name equal to its directory, which the plugin
# serves as `/oneloop:<name>`; user-only invocation; no argument list; under the cap); a
# standalone skill names itself, carries the description it triggers on, keeps model invocation
# on and stays under the cap; and the law names every one of them as `:<name>`, since the law
# is where a session learns what it can type. A plain request is the loop, which no skill
# carries. Run: bash tests/commands.test.sh
# SKILLS_DIR and LAW_MD point the test at other copies, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
SKILLS="${SKILLS_DIR:-$ROOT/skills}"
LAW="${LAW_MD:-$ROOT/law/engineering-law.md}"
# The commands the user types, each `/oneloop:<name>`, space-separated.
COMMANDS="audit brainstorm design-spec release-notes triage"
# Skills that ship beside the law and trigger on their own description.
STANDALONE="explain update-rules status-report"
LINE_CAP=500
TICK=$(printf '\140')

# skill_dirs <skills dir>: every skill directory, sorted.
skill_dirs() { find "$1" -mindepth 1 -maxdepth 1 -type d | sed 's#.*/##' | sort; }

# listed: every command and standalone name, one per line, sorted.
listed() { tr ' ' '\n' <<< "$COMMANDS $STANDALONE" | sort; }

# front_value <SKILL.md> <key>: the frontmatter value of the key, empty when absent.
front_value() { sed -n '2,/^---$/p' "$1" | sed -n -E "s/^$2: *//p" | head -n 1; }

# over_cap <name> <SKILL.md>: one line when the skill is over the line cap.
over_cap() {
  lines=$(wc -l < "$2" | tr -d ' ')
  [ "$lines" -le "$LINE_CAP" ] || printf '%s: %s lines\n' "$1" "$lines"
}

# command_defects <skills dir>: one line per departure from a command's shape.
command_defects() {
  for name in $(tr ' ' '\n' <<< "$COMMANDS"); do
    file="$1/$name/SKILL.md"
    [ -f "$file" ] || { printf '%s: no skill directory\n' "$name"; continue; }
    [ "$(front_value "$file" name)" = "$name" ] || printf '%s: name is not %s\n' "$name" "$name"
    [ "$(front_value "$file" disable-model-invocation)" = true ] || printf '%s: model invocation is not disabled\n' "$name"
    [ -z "$(front_value "$file" arguments)" ] || printf '%s: takes an argument list\n' "$name"
    over_cap "$name" "$file"
  done
}

# standalone_defects <skills dir>: one line per departure from a standalone skill's shape.
standalone_defects() {
  for name in $(tr ' ' '\n' <<< "$STANDALONE"); do
    file="$1/$name/SKILL.md"
    [ -f "$file" ] || { printf '%s: no skill directory\n' "$name"; continue; }
    [ "$(front_value "$file" name)" = "$name" ] || printf '%s: name is not %s\n' "$name" "$name"
    [ -n "$(front_value "$file" description)" ] || printf '%s: no description\n' "$name"
    [ "$(front_value "$file" disable-model-invocation)" != true ] || printf '%s: model invocation is disabled\n' "$name"
    over_cap "$name" "$file"
  done
}

# stray_dirs <skills dir>: every skill directory that is neither a command nor a standalone.
stray_dirs() { comm -23 <(skill_dirs "$1") <(listed); }

# unnamed_in_law <law>: every command or standalone skill the law does not name as `:<name>`.
unnamed_in_law() {
  for name in $(listed); do grep -qF -- ":$name\`" "$1" || printf '%s\n' "$name"; done
}

test_every_skill_directory_is_listed() {
  assert_eq "every skill directory is a command or a standalone skill" "" "$(stray_dirs "$SKILLS")"
}

test_every_command_has_the_shape() {
  assert_eq "every command keeps its shape ($COMMANDS)" "" "$(command_defects "$SKILLS")"
}

test_every_standalone_has_the_shape() {
  assert_eq "every standalone skill has its shape ($STANDALONE)" "" "$(standalone_defects "$SKILLS")"
}

test_the_law_names_every_one() {
  assert_eq "the law names every command and standalone skill" "" "$(unnamed_in_law "$LAW")"
}

# The checks have to be able to fail: a leftover workflow, quick or agents directory, a command
# that takes an argument list, is open to the model or still carries the old prefixed name, a
# missing command, a standalone skill without its name or with model invocation off, one over
# the cap, and a law that names only some of them are all named.
test_planted_breaches_are_named() {
  mkdir -p "$WORK/skills/workflow" "$WORK/skills/quick" "$WORK/skills/agents" "$WORK/skills/brainstorm" "$WORK/skills/audit" "$WORK/skills/explain" "$WORK/skills/status-report"
  printf -- '---\nname: brainstorm\narguments: [mode]\ndisable-model-invocation: true\n---\nbody\n' > "$WORK/skills/brainstorm/SKILL.md"
  printf -- '---\nname: engineering-rules:audit\n---\nbody\n' > "$WORK/skills/audit/SKILL.md"
  printf -- '---\nname: explain\ndescription: "a planted standalone"\ndisable-model-invocation: true\n---\n' > "$WORK/skills/explain/SKILL.md"
  { printf -- '---\nname: status-report\ndescription: d\n---\n'; awk 'BEGIN { for (i = 0; i < 501; i++) print "filler" }'; } > "$WORK/skills/status-report/SKILL.md"
  stray=$(stray_dirs "$WORK/skills")
  assert_contains "a leftover workflow directory is named" "workflow" "$stray"
  assert_contains "and a leftover quick" "quick" "$stray"
  assert_contains "and a leftover agents switch" "agents" "$stray"
  assert_missing "a listed command is not" "brainstorm" "$stray"
  defects=$(command_defects "$WORK/skills")
  assert_contains "a command that takes an argument list is named" "brainstorm: takes an argument list" "$defects"
  assert_contains "a command with the old prefixed name is named" "audit: name is not audit" "$defects"
  assert_contains "a command open to the model is named" "audit: model invocation is not disabled" "$defects"
  assert_contains "a missing command is named" "triage: no skill directory" "$defects"
  defects=$(standalone_defects "$WORK/skills")
  assert_contains "a standalone skill with model invocation off is named" "explain: model invocation is disabled" "$defects"
  assert_contains "a skill over the cap is named" "status-report: 505 lines" "$defects"
  printf '%s\n' "Typed commands: ${TICK}/oneloop:brainstorm${TICK}, ${TICK}:audit${TICK}, ${TICK}:status-report${TICK}." > "$WORK/law.md"
  assert_eq "the commands a law does not name are named" "design-spec explain release-notes triage update-rules " "$(unnamed_in_law "$WORK/law.md" | tr '\n' ' ')"
}

test_every_skill_directory_is_listed
test_every_command_has_the_shape
test_every_standalone_has_the_shape
test_the_law_names_every_one
test_planted_breaches_are_named
report
