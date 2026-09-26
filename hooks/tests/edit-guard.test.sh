#!/bin/bash
# Fixture tests for edit-guard.sh, the edit guard (the code-rules hook). Run: bash hooks/tests/edit-guard.test.sh
# Each case feeds the guard one edit against a scratch git repo that ignores `.env`, and reads
# what it did: `ask` when it turned the edit into a permission prompt (12.0.0, the user's words:
# "i want to enforce every single law … claude models can't ignore them unless the target
# technology will break if it used them"; their pick, a prompt on everything), `allow` when it
# printed nothing. EDIT_GUARD_SH points the test at another copy of the script, for a watched
# failure; the copy needs hook-input.sh, progress-log.sh and path-kind.sh beside it, and finds
# 9.5 through ONELOOP_HOME or its own ../references tree.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../tests/harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../tests/harness.sh"
here=$(dirname "${BASH_SOURCE[0]}")
SCRIPT="${EDIT_GUARD_SH:-$here/../edit-guard.sh}"
LAW="$(cd "$here/../.." && pwd)/references/09-implement/9.5-the-law-scout.md"
export CLAUDE_CONFIG_DIR="$WORK/config"
LOG="$WORK/config/progress.log"
P="$WORK/p"
KEY='sk_live_FIXTUREnotArealKey1'

build_fixture() {
  mkdir -p "$P/src/users" "$P/tests" "$P/src/gen" "$P/lib" || return 1
  git init -q "$P" && printf '.env\n' > "$P/.gitignore" && git -C "$P" add .gitignore \
    && git -C "$P" -c user.name=t -c user.email=t@example.com commit -q -m base || return 1
  printf '// eslint-disable-next-line x\nconst a = 1\n' > "$P/src/existing.ts"
  printf 'export const a = 1\n' > "$P/src/legacyName.ts"
  printf 'export const ok = 1\n' > "$P/lib/old.ts"
}

# decide <json>: `ask` when the guard turned the edit into a permission prompt (the decision, a
# reason for the user and the context for the model), `allow` when it printed nothing, and
# anything else as it is, so a half-built prompt fails loudly. The output is kept in last.json.
decide() {
  out=$(printf '%s' "$1" | bash "$SCRIPT")
  printf '%s' "$out" > "$WORK/last.json"
  if [ -z "$out" ]; then printf 'allow'; return; fi
  printf '%s' "$out" | jq -r '.hookSpecificOutput as $h
    | if $h.permissionDecision == "ask" and (($h.permissionDecisionReason // "") | length) > 0 and (($h.additionalContext // "") | contains("The user is being asked")) then "ask"
      elif $h.permissionDecision then "decision:" + $h.permissionDecision else "unreadable" end'
}

# last_context / last_reason: what the last prompt told the model, and the user.
last_context() { jq -r '.hookSpecificOutput.additionalContext // empty' "$WORK/last.json"; }
last_reason()  { jq -r '.hookSpecificOutput.permissionDecisionReason // empty' "$WORK/last.json"; }

edit_json()     { jq -cn --arg p "$1" --arg n "$2" --arg o "${3:-}" '{hook_event_name:"PreToolUse",tool_name:"Edit",cwd:"/tmp/proj",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
write_json()    { jq -cn --arg p "$1" --arg n "$2" '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:"/tmp/proj",tool_input:{file_path:$p,content:$n}}'; }
notebook_json() { jq -cn --arg p "$1" --arg n "$2" '{hook_event_name:"PreToolUse",tool_name:"NotebookEdit",cwd:"/tmp/proj",tool_input:{notebook_path:$p,new_source:$n,cell_id:"c1"}}'; }
multi_json()    { jq -cn --arg p "$1" --arg n "$2" --arg o "$3" '{hook_event_name:"PreToolUse",tool_name:"MultiEdit",cwd:"/tmp/proj",tool_input:{file_path:$p,edits:[{old_string:$o,new_string:$n},{old_string:"q",new_string:"r"}]}}'; }

# expect_edit <ask|allow> <label> <path> <new> [old]
expect_edit()  { assert_eq "$1: $2" "$1" "$(decide "$(edit_json "$3" "$4" "${5:-}")")"; }
# expect_write <ask|allow> <label> <path> <content>
expect_write() { assert_eq "$1: $2" "$1" "$(decide "$(write_json "$3" "$4")")"; }

test_new_tokens_ask_and_old_ones_pass() {
  expect_edit  ask   'adding eslint-disable to code'          "$P/src/a.ts" $'// eslint-disable-next-line x\nconst a = 1' 'const a = 1'
  expect_edit  allow 'keeping an existing token'              "$P/src/existing.ts" $'// eslint-disable-next-line x\nconst a = 2' $'// eslint-disable-next-line x\nconst a = 1'
  expect_edit  allow 'moving a token, same count'             "$P/src/existing.ts" $'const a = 2\n// eslint-disable-next-line x' $'// eslint-disable-next-line x\nconst a = 1'
  expect_write allow 'writing over a file that holds one'     "$P/src/existing.ts" $'// eslint-disable-next-line x\nconst a = 3'
  expect_write ask   'writing a second one into it'           "$P/src/existing.ts" $'// eslint-disable-next-line x\n// eslint-disable-next-line y\nconst a = 3'
  assert_eq "multiedit adding a token" ask "$(decide "$(multi_json "$P/src/m.ts" '/* istanbul ignore next */' 'x')")"
  assert_eq "a noqa in a notebook cell" ask "$(decide "$(notebook_json "$P/nb.ipynb" 'x = 1  # noqa')")"
}

test_every_ban_row_asks_once() {
  expect_edit  ask 'bare Error in a service file'           "$P/src/users/users.service.ts" 'throw new Error("boom")'
  expect_edit  ask 'console in a service file'              "$P/src/users/users.service.ts" 'console.log(user)'
  expect_write ask 'debugger in a new file'                 "$P/src/b.ts" $'debugger;\nexport const x = 1'
  expect_edit  ask 'ownerless TODO'                         "$P/src/c.ts" '// TODO fix later'
  expect_edit  ask 'removed-code marker'                    "$P/src/c.ts" '// removed: old handler'
  expect_edit  ask 'one-line empty catch'                   "$P/src/c.ts" 'try { x() } catch (e) {}'
  expect_edit  ask 'promise catch that swallows'            "$P/src/c.ts" 'load().catch(() => {})'
  expect_edit  ask 'non-null assertion'                     "$P/src/d.ts" 'const n = count!+1'
  expect_edit  ask 'inline type in a service'               "$P/src/users/users.service.ts" 'interface Args { a: string; b: number }'
  expect_write ask 'secret in tracked code'                 "$P/src/cfg.ts" "const key = \"$KEY\""
  expect_write ask 'secret in a tracked .env.example'       "$P/.env.example" "STRIPE_KEY=$KEY"
  expect_edit  ask 'a path with a space'                    "$P/src/my file.ts" '// @ts-ignore'
}

# The names, the file kinds and the caps (12.0.0): one edit per rule, each asking.
test_every_name_and_file_rule_asks() {
  expect_edit  ask 'snake_case declared in TypeScript'       "$P/src/n.ts" 'const user_id = 1'
  expect_edit  ask 'a lowercase class name'                  "$P/src/n.ts" 'class user_repo {}'
  expect_edit  ask 'an I-prefixed interface'                 "$P/src/n.ts" 'interface IUser { id: string }'
  expect_edit  ask 'a refused variable name'                 "$P/src/n.ts" 'const data = load()'
  expect_edit  ask 'a refused class name'                    "$P/src/n.ts" 'class Manager {}'
  expect_edit  ask 'a refused PHP variable'                  "$P/src/n.php" "\$result = \$q->get();"
  expect_edit  ask 'a boolean without its prefix'            "$P/src/n.ts" 'const enabled = false'
  expect_edit  ask 'a useState boolean without its prefix'   "$P/src/N.tsx" 'const [open, setOpen] = useState(false)'
  expect_edit  ask 'camelCase def in Python'                 "$P/src/n.py" 'def getUser():'
  expect_write ask 'a default export that is not the file name' "$P/src/user-profile.service.ts" 'export default class UserService {}'
  expect_edit  ask 'a typed boolean flag parameter'          "$P/src/n.ts" 'function save(user: User, force: boolean) {}'
  expect_edit  ask 'a defaulted boolean flag parameter'      "$P/src/n.py" 'def save(user, force=False):'
  expect_edit  ask 'a fourth parameter'                      "$P/src/n.ts" 'function f(a: A, b: B, c: C, d: D) {}'
  expect_write ask 'a fourth parameter across lines'         "$P/src/g.ts" $'export function g(\n  a: A,\n  b: B,\n  c: C,\n  d: D,\n) {}'
  expect_write ask 'two classes in a file'                   "$P/src/two.ts" $'class A {}\nclass B {}'
  expect_write ask 'two components in a file'                "$P/src/Two.tsx" $'export default function Two() {}\nfunction Row() {}'
  expect_write ask 'a two-member interface outside .types'   "$P/src/user.repository.ts" $'export interface Repo {\n  find(): void\n  save(): void\n}'
  expect_write ask 'an exported constant outside .constants' "$P/src/limits.ts" 'export const MAX_RETRIES = 3'
  expect_write ask 'a schema outside .schema'                "$P/src/user.routes.ts" 'const body = z.object({ name: z.string() })'
  expect_write ask 'a class map outside .styles'             "$P/src/Chip.tsx" $'const variants = {\n  primary: \'bg-blue-500 text-white\',\n}'
  expect_write ask 'a camelCase file name'                   "$P/src/userService.ts" 'export const ok = 1'
  expect_write ask 'a file named for nothing'                "$P/src/helpers.ts" 'export const ok = 1'
  expect_write ask 'a file under utils/'                     "$P/src/utils/format.ts" 'export const ok = 1'
}

test_the_allowed_homes_and_names_stay_quiet() {
  expect_write allow 'a constant in its constants file'      "$P/src/app.constants.ts" 'export const MAX_RETRIES = 3'
  expect_write allow 'a schema in its schema file'           "$P/src/user.schema.ts" 'const body = z.object({ name: z.string() })'
  expect_write allow 'a class map in its styles file'        "$P/src/chip.styles.ts" $'const variants = {\n  primary: \'bg-blue-500 text-white\',\n}'
  expect_write allow 'a kebab-case file with a role'         "$P/src/user.service.ts" 'export const ok = 1'
  expect_write allow 'a PascalCase component whose export matches' "$P/src/UserCard.tsx" 'export default function UserCard() {}'
  expect_write allow 'a prefixed boolean'                    "$P/src/ok.ts" 'const isOpen = false'
  expect_write allow 'three parameters and self'             "$P/src/ok.py" $'def h(self, a, b, c):\n    return a'
  expect_edit  allow 'an edit to an existing camelCase file' "$P/src/legacyName.ts" 'export const a = 2' 'export const a = 1'
}

test_the_laws_own_exemptions_hold() {
  expect_edit  allow 'bare Error outside domain code'         "$P/src/a.ts" 'throw new Error("boom")'
  expect_edit  allow 'console outside domain code'            "$P/src/Button.tsx" 'console.log(user)'
  expect_edit  allow 'owned TODO'                             "$P/src/c.ts" '// TODO(nady): fix later'
  expect_edit  allow 'TODO.md named in a comment'             "$P/src/c.ts" '// TODO.md holds the checklist'
  expect_write allow 'secret in an ignored .env'              "$P/.env" "STRIPE_KEY=$KEY"
  expect_write allow 'markdown spelling the tokens'           "$P/README.md" $'Never write eslint-disable or @ts-ignore.\ndebugger;'
  expect_write allow 'a generated file'                       "$P/src/gen/foo.generated.ts" '// eslint-disable'
}

test_test_files_keep_the_rows_that_bind_them() {
  expect_edit  ask   'focused test in a test file'            "$P/tests/a.test.ts" "describe.only('x', () => {})"
  expect_edit  ask   'unowned skipped test'                   "$P/tests/a.test.ts" "it.skip('flaky', () => {})"
  expect_edit  allow 'skipped test naming a ticket'           "$P/tests/a.test.ts" "it.skip('PROJ-12 flaky', () => {})"
  expect_edit  ask   'eslint-disable in a test file'          "$P/tests/a.test.ts" '// eslint-disable-next-line x'
  expect_edit  allow 'ts-expect-error in a test file'         "$P/tests/a.test.ts" $'// @ts-expect-error invalid input on purpose\nfoo(1)'
  expect_edit  ask   'a secret in a test file'                "$P/tests/a.test.ts" "const k = \"$KEY\""
  expect_write allow 'a secret in an ignored .env under tests' "$P/tests/.env" "STRIPE_KEY=$KEY"
  expect_edit  allow 'a snake_case name in a test file'       "$P/tests/a.test.ts" 'const user_id = 1'
}

# A focused test in code under a directory named like a test file is not a test-file row: the
# guard classifies by the file name, and so does the scanner's block. The token is in two pieces.
# The code file is edited, not written, since a new file under that oddly named folder would ask
# for the folder's own name.
test_a_lookalike_directory_is_not_a_test_directory() {
  only=only
  expect_edit  allow 'a focused call in code under weird.test.dir/' "$P/weird.test.dir/src/plain.ts" "describe.$only('x', () => {})"
  expect_write ask   'the same call in a real test file under it'  "$P/weird.test.dir/tests/real.test.ts" "describe.$only('x', () => {})"
}

# The scanner's test-file globs and path-kind's are two copies of one definition; this pins them.
test_test_globs_match_the_scanner() {
  scanner=$(sed -n "s/^in_tests()  { in_paths \(.*\) | xargs.*/\1/p" "$LAW" | tr -d "'" | tr ' ' '\n' | sort)
  kind=$(sed -n 's/^    \(.*\)) printf test\(; return\)\{0,1\} ;;$/\1/p' "$here/../path-kind.sh" | tr '|' '\n' | sort)
  assert_eq "path-kind's test globs are the scanner's" "$scanner" "$kind"
}

# The guard's domain globs are a copy of the scanner's in_domain list; this pins them together.
test_domain_globs_match_the_scanner() {
  scanner=$(sed -n "s/^in_domain() { in_paths \(.*\) | xargs.*/\1/p" "$LAW" | tr -d "'" | tr ' ' '\n' | sort)
  guard=$(sed -n 's/^    \(\*\.[^)]*\)) printf yes ;;$/\1/p' "$SCRIPT" | tr '|' '\n' | sort)
  assert_eq "the guard's domain globs are the scanner's" "$scanner" "$guard"
}

# A prompt is the `ask` decision, one line of JSON for PreToolUse, with a reason for the user
# that names the rule, its line and the one way past, and never a deny.
test_a_prompt_is_the_ask_decision_with_its_reason() {
  assert_eq "a banned line asks" ask "$(decide "$(edit_json "$P/src/w.ts" 'debugger;')")"
  assert_eq "the JSON is for PreToolUse" PreToolUse "$(jq -r '.hookSpecificOutput.hookEventName' "$WORK/last.json")"
  assert_eq "and is one line" "1" "$(wc -l < "$WORK/last.json" | tr -d ' ' | sed 's/^0$/1/')"
  assert_contains "the reason names the rule and its line" "clean.debug-artifact at line 1 of the new text: debugger;" "$(last_reason)"
  assert_contains "the reason names the way past" "\`law-exception: <what the technology needs>\`" "$(last_reason)"
  assert_missing "and never says deny" '"deny"' "$(cat "$WORK/last.json")"
}

# A new file has no old text to compare against, so everything in it counts, its name and folder
# included; an edit to an existing file whose name breaks the rule is not this edit's doing. A
# line that states its exception still asks, and the prompt quotes the exception.
test_a_new_file_counts_whole_and_a_stated_exception_still_asks() {
  expect_write ask   'a new file named in camelCase'          "$P/src/newName.ts" 'export const ok = 1'
  assert_contains "the prompt names the file rule" "file.name-case at line 1 of the new text" "$(last_context)"
  expect_edit  allow 'an edit to an existing camelCase file' "$P/src/legacyName.ts" 'export const a = 3' 'export const a = 1'
  expect_edit  ask   'a stated exception still asks'         "$P/src/d.ts" 'const n = count! + 1 // law-exception: the SDK types it nullable'
  assert_contains "and the prompt quotes it" "It states its exception: law-exception: the SDK types it nullable" "$(last_context)"
}

# One prompt per edit with every grown rule in it: the first four in full, the rest counted.
test_the_prompt_lists_every_rule_the_edit_adds() {
  decide "$(edit_json "$P/src/e.ts" $'debugger;\nconst data = 1')" >/dev/null
  assert_contains "the count" "this edit adds 2 code-rule breaks" "$(last_reason)"
  assert_contains "the first rule" "clean.debug-artifact at line 1" "$(last_context)"
  assert_contains "the second rule" "name.refused-word at line 2" "$(last_context)"
  decide "$(edit_json "$P/src/e.ts" $'debugger;\nconst data = 1\nconst user_id = 2\nconst enabled = false\nclass user_repo {}\ninterface IUser { id: string }')" >/dev/null
  assert_contains "six rules, four in full" "this edit adds 6 code-rule breaks" "$(last_reason)"
  assert_contains "the rest counted" "And 2 more rule(s) after these." "$(last_reason)"
}

# Every rule the scanner tags has the law's words in the guard's prompt (`why`), so a new row
# never reaches the user as a bare id; the listing row never prompts and needs none.
test_every_scanner_rule_has_the_laws_words() {
  missing=$(grep -oE '\| tag [a-z]+\.[a-z-]+' "$LAW" | awk '{ print $3 }' | sort -u | grep -v '^note\.' | while IFS= read -r rule; do grep -qF "    $rule) printf" "$SCRIPT" || printf '%s ' "$rule"; done)
  assert_eq "every tagged rule has its words" "" "$missing"
  assert_contains "and so does the guard's own folder rule" "    folder.unlisted) printf" "$(cat "$SCRIPT")"
}

# A path that climbs with `..` past the session's cwd never puts the edit text outside the
# guard's own scratch dir, and is still judged.
test_a_climbing_path_stays_inside_the_scratch_dir() {
  mkdir -p "$WORK/tmp"
  json=$(jq -cn --arg p "$WORK/a/b/../../../../escape/x.ts" --arg c "$WORK" '{hook_event_name:"PreToolUse",tool_name:"Write",cwd:$c,tool_input:{file_path:$p,content:"debugger;"}}')
  out=$(printf '%s' "$json" | TMPDIR="$WORK/tmp" bash "$SCRIPT")
  assert_contains "the edit is still judged" 'The user is being asked' "$out"
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

test_the_prompt_and_the_log() {
  decide "$(write_json "$P/src/cfg2.ts" "const key = \"$KEY\"")" >/dev/null
  ctx=$(last_context)
  assert_contains "the context cites the code rules and says the user is asked" "engineering law (1.1, 2.2, 3.4): this edit adds a code-rule break. sec.hardcoded-secret at line 1 of the new text" "$ctx"
  assert_contains "and names the way past" "recorded on that line as a comment \`law-exception: <what the technology needs>\`" "$ctx"
  assert_contains "and the way back" "A rejection means: fix the line and retry, never route around it" "$ctx"
  assert_contains "the secret is redacted in the prompt" "[REDACTED]" "$ctx"
  assert_missing "and never shown" "$KEY" "$ctx"
  assert_missing "nor in the reason" "$KEY" "$(last_reason)"
  assert_contains "a prompt is logged with rule and path" " proj | guard | edit | ask | sec.hardcoded-secret | $P/src/cfg2.ts | line 1 of the new text" "$(cat "$LOG")"
  assert_missing "the log never carries the secret" "$KEY" "$(cat "$LOG")"
  assert_missing "the log never says warn" "| warn |" "$(cat "$LOG")"
  assert_missing "the log never says deny" "| deny |" "$(cat "$LOG")"
}

test_unreadable_input_and_missing_law() {
  out=$(printf 'nope' | bash "$SCRIPT" 2>&1; printf 'exit=%s' "$?")
  assert_contains "malformed stdin exits 0 with no output" "exit=0" "$out"
  assert_missing "malformed stdin prints nothing" "hookSpecificOutput" "$out"
  out=$(jq -cn '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:"/tmp/proj",tool_input:{command:"x"}}' | bash "$SCRIPT")
  assert_missing "a Bash event is not judged here" "hookSpecificOutput" "$out"
  out=$(edit_json "$P/src/q.ts" 'debugger;' | ONELOOP_HOME=/nonexistent bash "$SCRIPT")
  assert_missing "a missing 9.5 asks about nothing" "hookSpecificOutput" "$out"
  assert_contains "and says so in the log" " proj | guard | edit | skipped | 9.5 not found at /nonexistent/references" "$(tail -n 1 "$LOG")"
  out=$(edit_json "$P/src/q.ts" 'debugger;' | ONELOOP_HOME="$here/../.." bash "$SCRIPT")
  assert_contains "9.5 is read from ONELOOP_HOME when it is set" 'The user is being asked' "$out"
}

# A Write that creates a file under a top-level folder the map's Key directories do not list
# asks (folder.unlisted, the guard's own rule); a listed folder, a root file, an existing file,
# a dotfolder, or a map with no Key directories does not. Runs last, since the map it plants
# would otherwise judge every new file the tests above write.
test_a_new_file_under_an_unlisted_folder_asks() {
  printf "# p\n\n## Key directories\n\n- \`src/\`: the code.\n- \`tests/\`: the tests.\n\n## Entry points\n\n- \`src/index.ts\`\n" > "$P/CLAUDE.md"
  expect_write ask   'a new file under a folder the map does not list' "$P/lib/x.ts" 'export const ok = 1'
  assert_contains "the prompt names the folder and the map" "folder.unlisted at line 1 of the new text: lib/ is not among the Key directories of p/CLAUDE.md (src tests)" "$(last_context)"
  expect_write allow 'a new file under a listed folder'              "$P/src/listed.ts" 'export const ok = 1'
  expect_write allow 'a new file at the root'                        "$P/root-file.ts" 'export const ok = 1'
  expect_write allow 'a write over an existing file under an unlisted folder' "$P/lib/old.ts" 'export const ok = 2'
  expect_write allow 'a new file under a dotfolder'                  "$P/.github/x.ts" 'export const ok = 1'
  rm "$P/CLAUDE.md"
  expect_write allow 'no Key directories, no folder rule'            "$P/lib/y.ts" 'export const ok = 1'
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
test_new_tokens_ask_and_old_ones_pass
test_every_ban_row_asks_once
test_every_name_and_file_rule_asks
test_the_allowed_homes_and_names_stay_quiet
test_the_laws_own_exemptions_hold
test_test_files_keep_the_rows_that_bind_them
test_a_lookalike_directory_is_not_a_test_directory
test_test_globs_match_the_scanner
test_domain_globs_match_the_scanner
test_a_prompt_is_the_ask_decision_with_its_reason
test_a_new_file_counts_whole_and_a_stated_exception_still_asks
test_the_prompt_lists_every_rule_the_edit_adds
test_every_scanner_rule_has_the_laws_words
test_a_climbing_path_stays_inside_the_scratch_dir
test_a_broken_block_is_logged_not_trusted
test_the_prompt_and_the_log
test_unreadable_input_and_missing_law
test_a_new_file_under_an_unlisted_folder_asks
report
