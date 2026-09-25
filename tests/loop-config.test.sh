#!/bin/bash
# Guard: settings/loop.json, the loop's defaults, carries exactly the seven keys the law names
# (the four checks, the discovery budget, the risk regex, the UI path regex), each of the right
# shape, and its defaults are the law's own: the regexes the law prints and the budget it
# states. Run: bash tests/loop-config.test.sh
# LOOP_JSON and LAW_MD point the test at other copies, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
CONFIG="${LOOP_JSON:-$ROOT/settings/loop.json}"
LAW="${LAW_MD:-$ROOT/law/engineering-law.md}"
KEYS="lint typecheck test ui_check discovery_budget risk_regex ui_path_regex"

# sorted <words>: the words sorted, space-separated.
sorted() { tr ' ' '\n' <<< "$1" | sort | tr '\n' ' ' | sed 's/ $//'; }

# config_keys <file>: its top-level keys, sorted, space-separated.
config_keys() { jq -r 'keys[]' "$1" | sort | tr '\n' ' ' | sed 's/ $//'; }

# shape_defects <file>: one line per key of the wrong type.
shape_defects() {
  for k in lint typecheck test ui_check risk_regex ui_path_regex; do
    [ "$(jq -r --arg k "$k" '.[$k] | type' "$1")" = string ] || printf '%s is not a string\n' "$k"
  done
  [ "$(jq -r '.discovery_budget | type' "$1")" = number ] || printf 'discovery_budget is not a number\n'
}

# regex_defects <file>: a regex grep -E refuses (exit 2), named.
regex_defects() {
  for k in risk_regex ui_path_regex; do
    re=$(jq -r --arg k "$k" '.[$k] // ""' "$1")
    printf 'x' | grep -qE -- "$re" 2>/dev/null
    [ $? -ne 2 ] || printf '%s is not a regex grep -E accepts\n' "$k"
  done
}

# law_defects <config> <law>: a default the law does not print verbatim.
law_defects() {
  for k in risk_regex ui_path_regex; do
    re=$(jq -r --arg k "$k" '.[$k] // ""' "$1")
    grep -qF -- "\`$re\`" "$2" || printf 'the law does not carry %s\n' "$k"
  done
  budget=$(jq -r '.discovery_budget' "$1")
  grep -qF -- "the discovery budget is $budget tool calls" "$2" || printf 'the law does not name a %s-call budget\n' "$budget"
}

test_the_config_has_the_seven_keys() {
  assert_eq "the config parses" "object" "$(jq -r 'type' "$CONFIG" 2>/dev/null)"
  assert_eq "and carries exactly the seven keys" "$(sorted "$KEYS")" "$(config_keys "$CONFIG")"
  assert_eq "each of the right shape" "" "$(shape_defects "$CONFIG")"
  assert_eq "and both regexes are regexes" "" "$(regex_defects "$CONFIG")"
}

test_the_defaults_are_the_laws() {
  assert_eq "the law prints the same regexes and names the same budget" "" "$(law_defects "$CONFIG" "$LAW")"
}

# The checks can fail: a missing key, a budget written as a string, a broken regex and a regex
# the law does not print are each named.
test_planted_breaches_are_named() {
  jq 'del(.ui_check)' "$CONFIG" > "$WORK/missing.json"
  assert_missing "a missing key changes the key list" "ui_check" "$(config_keys "$WORK/missing.json")"
  jq '.discovery_budget = "10"' "$CONFIG" > "$WORK/string.json"
  assert_eq "a budget written as a string is named" "discovery_budget is not a number" "$(shape_defects "$WORK/string.json")"
  jq '.risk_regex = "auth|("' "$CONFIG" > "$WORK/broken.json"
  assert_eq "a broken regex is named" "risk_regex is not a regex grep -E accepts" "$(regex_defects "$WORK/broken.json")"
  jq '.risk_regex = "auth|login"' "$CONFIG" > "$WORK/other.json"
  assert_eq "a regex the law does not print is named" "the law does not carry risk_regex" "$(law_defects "$WORK/other.json" "$LAW")"
}

test_the_config_has_the_seven_keys
test_the_defaults_are_the_laws
test_planted_breaches_are_named
report
