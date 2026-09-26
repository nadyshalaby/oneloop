#!/bin/bash
# Fixture tests for edit-guard.sh, the code-rules hook. Run: bash hooks/tests/edit-guard.test.sh
# Each case feeds the guard one edit against a scratch git repo that ignores `.env`, and reads
# what it did: `warn` when it put its warning beside the tool result, `allow` when it printed
# nothing. It never returns a permission decision (10.0.0, the user's words: "WARN in the tool
# result, never block. Hard blocks caused silent edit-retry loops"). EDIT_GUARD_SH points the
# test at another copy of the script, for a watched failure; the copy needs hook-input.sh,
# progress-log.sh and path-kind.sh beside it, and finds 9.5 through ONELOOP_HOME or
# its own ../references tree.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${EDIT_GUARD_SH:-$here/../edit-guard.sh}"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
P="$WORK/p"
KEY='sk_live_FIXTUREnotArealKey1'

build_fixture() {
  mkdir -p "$P/src/users" "$P/tests" "$P/src/gen" || return 1
  git init -q "$P" && printf '.env\n' > "$P/.gitignore" && git -C "$P" add .gitignore \
    && git -C "$P" -c user.name=t -c user.email=t@example.com commit -q -m base || return 1
  printf '// eslint-disable-next-line x\nconst a = 1\n' > "$P/src/existing.ts"
}

# decide <json>: `warn` when the guard added its warning beside the result, `allow` when it
# printed nothing; a permission decision, which it must never return, is printed as
# `decision:<value>`. The whole output is kept in last.json for the field readers below.
decide() {
  out=$(printf '%s' "$1" | bash "$SCRIPT")
  printf '%s' "$out" > "$WORK/last.json"
  if [ -z "$out" ]; then printf 'allow'; return; fi
  printf '%s' "$out" | jq -r 'if .hookSpecificOutput.permissionDecision then "decision:" + .hookSpecificOutput.permissionDecision
    elif ((.hookSpecificOutput.additionalContext // "") | contains("warning, not a block")) then "warn" else "unreadable" end'
}

# last_context: the warning the last decision put beside the tool result.
last_context() { jq -r '.hookSpecificOutput.additionalContext // empty' "$WORK/last.json"; }

edit_json()     { jq -cn --arg p "$1" --arg n "$2" --arg o "${3:-}" '{hook_event_name:"PreToolUse",tool_name:"Edit",cwd:"/tmp/proj",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
write_json()    { jq -cn --arg p "$1" --arg n "$2" '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:"/tmp/proj",tool_input:{file_path:$p,content:$n}}'; }
notebook_json() { jq -cn --arg p "$1" --arg n "$2" '{hook_event_name:"PreToolUse",tool_name:"NotebookEdit",cwd:"/tmp/proj",tool_input:{notebook_path:$p,new_source:$n,cell_id:"c1"}}'; }
multi_json()    { jq -cn --arg p "$1" --arg n "$2" --arg o "$3" '{hook_event_name:"PreToolUse",tool_name:"MultiEdit",cwd:"/tmp/proj",tool_input:{file_path:$p,edits:[{old_string:$o,new_string:$n},{old_string:"q",new_string:"r"}]}}'; }

# expect_edit <warn|allow> <label> <path> <new> [old]
expect_edit()  { assert_eq "$1: $2" "$1" "$(decide "$(edit_json "$3" "$4" "${5:-}")")"; }
# expect_write <warn|allow> <label> <path> <content>
expect_write() { assert_eq "$1: $2" "$1" "$(decide "$(write_json "$3" "$4")")"; }

test_new_tokens_warn_and_old_ones_pass() {
  expect_edit  warn  'adding eslint-disable to code'          "$P/src/a.ts" $'// eslint-disable-next-line x\nconst a = 1' 'const a = 1'
  expect_edit  allow 'keeping an existing token'              "$P/src/existing.ts" $'// eslint-disable-next-line x\nconst a = 2' $'// eslint-disable-next-line x\nconst a = 1'
  expect_edit  allow 'moving a token, same count'             "$P/src/existing.ts" $'const a = 2\n// eslint-disable-next-line x' $'// eslint-disable-next-line x\nconst a = 1'
  expect_write allow 'writing over a file that holds one'     "$P/src/existing.ts" $'// eslint-disable-next-line x\nconst a = 3'
  expect_write warn  'writing a second one into it'           "$P/src/existing.ts" $'// eslint-disable-next-line x\n// eslint-disable-next-line y\nconst a = 3'
  assert_eq "multiedit adding a token" warn "$(decide "$(multi_json "$P/src/m.ts" '/* istanbul ignore next */' 'x')")"
  assert_eq "a noqa in a notebook cell" warn "$(decide "$(notebook_json "$P/nb.ipynb" 'x = 1  # noqa')")"
}

test_every_hook_rule_fires_once() {
  expect_edit  warn  'bare Error in a service file'           "$P/src/users/users.service.ts" 'throw new Error("boom")'
  expect_edit  warn  'console in a service file'              "$P/src/users/users.service.ts" 'console.log(user)'
  expect_write warn  'debugger in a new file'                 "$P/src/b.ts" $'debugger;\nexport const x = 1'
  expect_edit  warn  'ownerless TODO'                         "$P/src/c.ts" '// TODO fix later'
  expect_edit  warn  'removed-code marker'                    "$P/src/c.ts" '// removed: old handler'
  expect_edit  warn  'one-line empty catch'                   "$P/src/c.ts" 'try { x() } catch (e) {}'
  expect_edit  warn  'promise catch that swallows'            "$P/src/c.ts" 'load().catch(() => {})'
  expect_write warn  'secret in tracked code'                 "$P/src/cfg.ts" "const key = \"$KEY\""
  expect_write warn  'secret in a tracked .env.example'       "$P/.env.example" "STRIPE_KEY=$KEY"
  expect_edit  warn  'a path with a space'                    "$P/src/my file.ts" '// @ts-ignore'
}

test_the_laws_own_exemptions_hold() {
  expect_edit  allow 'bare Error outside domain code'         "$P/src/a.ts" 'throw new Error("boom")'
  expect_edit  allow 'console outside domain code'            "$P/src/Button.tsx" 'console.log(user)'
  expect_edit  allow 'owned TODO'                             "$P/src/c.ts" '// TODO(nady): fix later'
  expect_edit  allow 'TODO.md named in a comment'             "$P/src/c.ts" '// TODO.md holds the checklist'
  expect_write allow 'secret in an ignored .env'              "$P/.env" "STRIPE_KEY=$KEY"
  expect_write allow 'markdown spelling the tokens'           "$P/README.md" $'Never write eslint-disable or @ts-ignore.\ndebugger;'
  expect_write allow 'a generated file'                       "$P/src/gen/foo.generated.ts" '// eslint-disable'
  expect_edit  allow 'non-null stays with the diff read'      "$P/src/d.ts" 'const n = count!+1'
  expect_edit  allow 'inline type stays with the diff read'   "$P/src/users/users.service.ts" 'interface Args { a: string; b: number }'
}

test_test_files_keep_the_rows_that_bind_them() {
  expect_edit  warn  'focused test in a test file'            "$P/tests/a.test.ts" "describe.only('x', () => {})"
  expect_edit  warn  'unowned skipped test'                   "$P/tests/a.test.ts" "it.skip('flaky', () => {})"
  expect_edit  allow 'skipped test naming a ticket'           "$P/tests/a.test.ts" "it.skip('PROJ-12 flaky', () => {})"
  expect_edit  warn  'eslint-disable in a test file'          "$P/tests/a.test.ts" '// eslint-disable-next-line x'
  expect_edit  allow 'ts-expect-error in a test file'         "$P/tests/a.test.ts" $'// @ts-expect-error invalid input on purpose\nfoo(1)'
  expect_edit  warn  'a secret in a test file'                "$P/tests/a.test.ts" "const k = \"$KEY\""
  expect_write allow 'a secret in an ignored .env under tests' "$P/tests/.env" "STRIPE_KEY=$KEY"
}

# A focused test in code under a directory named like a test file is not a test-file row: the
# guard classifies by the file name, and so does the scanner's block. The token is in two pieces.
test_a_lookalike_directory_is_not_a_test_directory() {
  only=only
  expect_write allow 'a focused call in code under weird.test.dir/' "$P/weird.test.dir/src/plain.ts" "describe.$only('x', () => {})"
  expect_write warn  'the same call in a real test file under it'  "$P/weird.test.dir/tests/real.test.ts" "describe.$only('x', () => {})"
}

# The scanner's test-file globs and path-kind's are two copies of one definition; this pins them.
test_test_globs_match_the_scanner() {
  law="$(cd "$here/../.." && pwd)/references/09-implement/9.5-the-law-scout.md"
  scanner=$(sed -n "s/^in_tests()  { in_paths \(.*\) | xargs.*/\1/p" "$law" | tr -d "'" | tr ' ' '\n' | sort)
  kind=$(sed -n 's/^    \(.*\)) printf test\(; return\)\{0,1\} ;;$/\1/p' "$here/../path-kind.sh" | tr '|' '\n' | sort)
  assert_eq "path-kind's test globs are the scanner's" "$scanner" "$kind"
}

# The guard's domain globs are a copy of the scanner's in_domain list; this pins them together.
test_domain_globs_match_the_scanner() {
  law="$(cd "$here/../.." && pwd)/references/09-implement/9.5-the-law-scout.md"
  scanner=$(sed -n "s/^in_domain() { in_paths \(.*\) | xargs.*/\1/p" "$law" | tr -d "'" | tr ' ' '\n' | sort)
  guard=$(sed -n 's/^    \(\*\.[^)]*\)) printf yes ;;$/\1/p' "$SCRIPT" | tr '|' '\n' | sort)
  assert_eq "the guard's domain globs are the scanner's" "$scanner" "$guard"
}

# A warning is context beside the tool result and nothing else: no permission decision, so the
# edit's own permission flow is untouched and the edit goes through.
test_a_warning_never_carries_a_permission_decision() {
  assert_eq "a banned line warns" warn "$(decide "$(edit_json "$P/src/w.ts" 'debugger;')")"
  assert_missing "and carries no permission decision" "permissionDecision" "$(cat "$WORK/last.json")"
  assert_eq "the JSON is for PreToolUse" PreToolUse "$(jq -r '.hookSpecificOutput.hookEventName' "$WORK/last.json")"
  assert_eq "and is one line" "1" "$(wc -l < "$WORK/last.json" | tr -d ' ' | sed 's/^0$/1/')"
}

# A path that climbs with `..` past the session's cwd never puts the edit text outside the
# guard's own scratch dir, and is still judged.
test_a_climbing_path_stays_inside_the_scratch_dir() {
  mkdir -p "$WORK/tmp"
  json=$(jq -cn --arg p "$WORK/a/b/../../../../escape/x.ts" --arg c "$WORK" '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:$c,tool_input:{file_path:$p,content:"debugger;"}}')
  out=$(printf '%s' "$json" | TMPDIR="$WORK/tmp" bash "$SCRIPT")
  assert_contains "the edit is still judged" 'warning, not a block' "$out"
  if [ -e "$WORK/tmp/escape/x.ts" ]; then where=leaked; else where=contained; fi
  assert_eq "nothing lands outside the scratch dir" contained "$where"
}

# A 9.5 whose block cannot run judges nothing, prints nothing, and says so in the log; the real
# block never writes that line.
test_a_broken_block_is_logged_not_trusted() {
  law=references/09-implement/9.5-the-law-scout.md
  root="$WORK/broken" && mkdir -p "$root/${law%/*}"
  awk '/^### HOW/ { h = 1 } { print } h && /^```bash$/ && !done { print "if true; then"; done = 1 }' "$here/../../$law" > "$root/$law"
  out=$(edit_json "$P/src/q.ts" 'debugger;' | ONELOOP_HOME="$root" bash "$SCRIPT")
  assert_eq "a broken block judges nothing" "" "$out"
  assert_contains "and says so in the log" " proj | guard | edit | skipped | 9.5 block failed on the new text (exit 2)" "$(tail -n 1 "$LOG")"
  before=$(wc -l < "$LOG" | tr -d ' ')
  expect_edit allow 'a clean edit with the real block' "$P/src/clean.ts" 'const ok = 1' 'const ok = 0'
  assert_eq "and the real block never logs a skip" "$before" "$(wc -l < "$LOG" | tr -d ' ')"
}

test_warnings_and_log() {
  decide "$(write_json "$P/src/cfg2.ts" "const key = \"$KEY\"")" >/dev/null
  ctx=$(last_context)
  assert_contains "a warning cites 1.1 and calls itself a warning" "engineering law (1.1) warning, not a block: this edit adds a sec.hardcoded-secret" "$ctx"
  assert_contains "a warning names the line" "sec.hardcoded-secret at line 1 of the new text" "$ctx"
  assert_contains "a warning asks for the fix in the next edit" "The law asks for that line to be fixed in the next edit" "$ctx"
  assert_contains "the secret is redacted in the warning" "[REDACTED]" "$ctx"
  assert_missing "and never shown" "$KEY" "$ctx"
  assert_contains "a warning is logged with rule and path" " proj | guard | edit | warn | sec.hardcoded-secret | $P/src/cfg2.ts | line 1 of the new text" "$(cat "$LOG")"
  assert_missing "the log never carries the secret" "$KEY" "$(cat "$LOG")"
  assert_missing "the log never says deny" "| deny |" "$(cat "$LOG")"
  decide "$(edit_json "$P/src/z.ts" 'debugger;')" >/dev/null
  assert_contains "a debug artifact warning names the rule" "clean.debug-artifact at line 1" "$(last_context)"
}

test_unreadable_input_and_missing_law() {
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints nothing" "hookSpecificOutput" "$out"
  out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:"/tmp/proj",tool_input:{command:"x"}}' | bash "$SCRIPT")
  assert_missing "a Bash event is not judged here" "hookSpecificOutput" "$out"
  out=$(edit_json "$P/src/q.ts" 'debugger;' | ONELOOP_HOME=/nonexistent bash "$SCRIPT")
  assert_missing "a missing 9.5 warns about nothing" "hookSpecificOutput" "$out"
  assert_contains "and says so in the log" " proj | guard | edit | skipped | 9.5 not found at /nonexistent/references" "$(tail -n 1 "$LOG")"
  out=$(edit_json "$P/src/q.ts" 'debugger;' | ONELOOP_HOME="$here/../.." bash "$SCRIPT")
  assert_contains "9.5 is read from ONELOOP_HOME when it is set" 'warning, not a block' "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_new_tokens_warn_and_old_ones_pass
test_every_hook_rule_fires_once
test_the_laws_own_exemptions_hold
test_test_files_keep_the_rows_that_bind_them
test_a_lookalike_directory_is_not_a_test_directory
test_test_globs_match_the_scanner
test_domain_globs_match_the_scanner
test_a_warning_never_carries_a_permission_decision
test_a_climbing_path_stays_inside_the_scratch_dir
test_a_broken_block_is_logged_not_trusted
test_warnings_and_log
test_unreadable_input_and_missing_law
report
