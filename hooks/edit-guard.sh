#!/bin/bash
# oneloop edit guard (the code-rules hook).
# Runs on PreToolUse for Edit, Write, MultiEdit and NotebookEdit. The code rules (the law's 1.1,
# its Names and One thing per file, 2.2 and 3.4) bind every line of production code. This hook
# runs the law scout's own shell block (9.5) over the text an edit would write and turns the
# edit into a PERMISSION PROMPT when it ADDS a finding: the bans (a suppression, an empty catch,
# a bare built-in error in a domain-role file, a non-null assertion, an inline type, a focused or
# unowned skipped test, a debug artifact, an ownerless debt marker, a removed-code comment, a
# hardcoded secret), the names (a refused whole name, an `I` prefix, the wrong case for the
# language, a boolean without its prefix, a default export that disagrees with the file name),
# the file kinds (a second class or component, a type, constant, schema or class map outside its
# home file, a file or folder in the wrong case or named for nothing) and the caps (a fourth
# parameter, a flag parameter). One rule is this hook's own, `folder.unlisted`: a Write that
# creates a file under a top-level folder the project map's Key directories do not list, since
# only the hook sees the map.
# 12.0.0, at the user's word ("these laws are my own coding style, i want to enforce every single
# law … claude models can't ignore them unless the target technology will break if it used
# them"; their pick: a prompt on everything). The prompt names every rule the edit adds, its
# line and its fix. The user's approval is the exception, recorded on that line as a comment
# `law-exception: <what the technology needs>`, which the scout lists (`note.law-exception`); a
# line that already states one still prompts, with the exception quoted, so nothing passes on
# its own say-so. A rejection means: fix the line and retry, never route around it.
# What is already in the file never prompts: the block runs over the text being replaced too,
# and only a count that grows counts (a new file has nothing to compare against, so all of it
# counts). 9.5 stays the one source of the patterns; this file holds none of them.
# Exempt, by the law's own definitions: prose, generated files and migrations; test files, except
# for the suppression, test-hygiene and secret rows, which bind there too; the secret rows on a
# path git ignores. Unreadable input, a tool that is not an edit, or a 9.5 that is missing or
# fails to run is nothing to judge: exit 0 with no output, plus one log line in the last two cases.
set -u
umask 077

here=${BASH_SOURCE[0]%/*}
[ "$here" = "${BASH_SOURCE[0]}" ] && here=.
# shellcheck source=./hook-input.sh
. "$here/hook-input.sh"
# shellcheck source=./progress-log.sh
. "$here/progress-log.sh"
# shellcheck source=./path-kind.sh
. "$here/path-kind.sh"

LAW_SCOUT="${ONELOOP_HOME:-$(cd -P "$here/.." && pwd)}/references/09-implement/9.5-the-law-scout.md"
TEST_RULES='ban.suppression|test.focused|test.skipped|sec.hardcoded-secret'
EVIDENCE_CHARS=120
PROMPT_RULES=4

# domain_role <path>: yes when the file name marks domain code, where the bare-error ban applies.
domain_role() {
  case "${1##*/}" in
    *.service.*|*.use-case.*|*.usecase.*|*.repository.*|*.validator.*|*.job.*|*.worker.*) printf yes ;;
    *) printf no ;;
  esac
}

# git_ignored <path>: yes when git ignores the file, so a secret in it never reaches history.
git_ignored() {
  dir=${1%/*}
  [ "$dir" = "$1" ] && dir=.
  if git -C "$dir" check-ignore -q "$1" 2>/dev/null; then printf yes; else printf no; fi
}

# The scout's block, minus the diff line that would rebuild the path list.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$LAW_SCOUT" | grep -v '^git diff -z'
}

# The text the edit writes goes to $W/new.txt, the text it replaces to $W/old.txt. A Write
# replaces the whole file, so its old text is the file; a notebook cell has no old text here.
write_texts() {
  case "$tool" in
    Edit) hook_field '.tool_input.new_string // ""' > "$W/new.txt"; hook_field '.tool_input.old_string // ""' > "$W/old.txt" ;;
    MultiEdit) hook_field '[.tool_input.edits[]?.new_string // ""] | join("\n")' > "$W/new.txt"; hook_field '[.tool_input.edits[]?.old_string // ""] | join("\n")' > "$W/old.txt" ;;
    Write) hook_field '.tool_input.content // ""' > "$W/new.txt"; if [ -f "$path" ]; then cat "$path" > "$W/old.txt"; else : > "$W/old.txt"; fi ;;
    NotebookEdit) hook_field '.tool_input.new_source // ""' > "$W/new.txt"; : > "$W/old.txt" ;;
  esac
}

# keep_applicable: the finding lines the law enforces on this kind of file. The scout's `note.*`
# lines are a listing, never a break.
keep_applicable() {
  case "$kind" in
    test) grep -E "^($TEST_RULES) " | grep -v -F '@ts-expect-error' ;;
    *) grep -v -E '^note\.' ;;
  esac | awk -v domain="$domain" -v ignored="$ignored" '
      /^ban\.bare-error / && domain != "yes" { next }
      /^sec\.hardcoded-secret / && ignored == "yes" { next }
      { print }'
}

# scan <new|old>: the block's finding lines for that side, under the file's own relative path
# so the rows keyed to a role, a file kind, a language or a test path see the name the real file
# has. A block that fails to run judges nothing, and says so in the log rather than passing in
# silence.
scan() {
  side="$W/$1"
  case "$rel" in */*) mkdir -p "$side/${rel%/*}" ;; *) mkdir -p "$side" ;; esac
  cp "$W/$1.txt" "$side/$rel"
  printf '%s\0' "$rel" > "$W/$1.paths"
  (cd "$side" && SCOUT_PATHS="$W/$1.paths" bash "$W/block.sh" > "$W/$1.out" 2> "$W/$1.err")
  status=$?
  if [ "$status" -ne 0 ] || [ -s "$W/$1.err" ]; then
    append_log "$project" "guard | edit | skipped | 9.5 block failed on the $1 text (exit $status): $(head -n 1 "$W/$1.err" | cut -c1-120)"
  fi
  grep -E '^[a-z]+\.[a-z-]+ ' "$W/$1.out" | keep_applicable
}

# why <rule>: the law's own words for the rule, quoted in the prompt.
why() {
  case "$1" in
    ban.suppression) printf 'zero lint, type or coverage suppressions; the ban holds in test files too, whose sole exception is @ts-expect-error over deliberately invalid input with a comment saying why' ;;
    ban.empty-catch) printf 'zero empty catches, a comment-only body, a promise .catch that swallows, or an except: pass included' ;;
    ban.bare-error) printf 'zero bare Error throws in domain code; throw a domain-specific exception subclass' ;;
    ban.non-null) printf 'zero non-null assertions; narrow the value or handle its absence' ;;
    ban.inline-type) printf 'no inline interface or type of 2+ properties in a scoped module; extract it to the feature .types file' ;;
    ban.custom) printf 'the project'"'"'s own ban-patterns file names this pattern' ;;
    test.focused) printf 'zero focused tests committed; a focused test silently drops the rest of the suite' ;;
    test.skipped) printf 'a skipped test carries a ticket or an owner on the same line' ;;
    clean.debug-artifact) printf 'zero debug artifacts; no debugger, and no console.* in domain code, which logs through the project logger' ;;
    clean.debt-marker) printf 'a TODO with no owner or ticket is refused on sight' ;;
    clean.removed-comment) printf 'a comment marking deleted code is refused on sight' ;;
    style.flag-parameter) printf 'no flag parameters: a boolean that switches behaviour is two functions, or a named option' ;;
    sec.hardcoded-secret) printf 'zero hardcoded secrets; the matched value is redacted here and must not stay in the file' ;;
    name.type-case) printf 'a class, interface, enum, struct, trait or type alias is PascalCase' ;;
    name.interface-prefix) printf 'an interface carries no I prefix' ;;
    name.snake-in-camel) printf 'functions, methods, variables and parameters are camelCase in this language; only a true module constant is SCREAMING_SNAKE_CASE' ;;
    name.camel-in-snake) printf 'functions and variables are snake_case in this language' ;;
    name.refused-word) printf 'a name that says nothing (data, info, item, obj, temp, val, res, result, handle, process, manager, helper, util(s), base, core) or a My prefix is refused as a whole name; name it for what it holds or does' ;;
    name.boolean-prefix) printf 'a boolean starts with is, has, can or should' ;;
    name.export-file-mismatch) printf 'a file name and its primary export agree' ;;
    file.two-things) printf 'one component, one class per file; a sub-component or a second class gets its own file' ;;
    file.type-home) printf 'a type of 2+ properties lives in the feature .types file, not in an implementation file' ;;
    file.constant-home) printf 'an exported constant lives in the .constants file, a config value in .config' ;;
    file.schema-home) printf 'a validation schema lives in the .schema file' ;;
    file.style-home) printf 'style tokens and class maps live in the .styles file' ;;
    file.name-case) printf 'a file is <subject>.<role>.<ext> in kebab-case, PascalCase only for a component or a page; a folder is kebab-case, PascalCase only for that one component (2.2)' ;;
    file.refused-word) printf 'a file or folder named data, temp, utils, helpers, misc or the like says nothing; name it for what it holds (2.2)' ;;
    cap.fn-params) printf 'at most 3 parameters; group more into a named type' ;;
    folder.unlisted) printf 'a new top-level folder is a placement decision (2.3): put the file under a folder the map lists, or add the folder to the map first' ;;
    *) printf 'the code rules refuse %s in production code' "$1" ;;
  esac
}

# emit <reason> <context>: the prompt as the JSON Claude Code reads: the permission decision
# `ask` with its reason for the user, and the same case for the model beside the tool result.
emit() {
  jq -cn --arg r "$1" --arg c "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r,additionalContext:$c}}'
}

# growths: reads `new <finding>` and `old <finding>` lines; prints, in order of first appearance,
# the first new finding of every rule with more lines on the new side than on the old.
growths() {
  awk '
    $1 == "new" { n[$2]++; if (!($2 in first)) { first[$2] = substr($0, 5); order[++k] = $2 } }
    $1 == "old" { o[$2]++ }
    END { for (i = 1; i <= k; i++) if (n[order[i]] > o[order[i]]) print first[order[i]] }'
}

# describe <finding line>: one clause of the prompt: the rule, the line, the evidence, the law's
# words, and the exception the line states if it states one. The finding is
# `rule path:line:evidence`, the block's own shape; the log gets one line per rule.
describe() {
  rule=${1%% *}; detail=${1#"$rule $rel:"}; line_no=${detail%%:*}; text=${detail#*:}
  stated=""
  case "$text" in *law-exception:*) stated=" It states its exception: law-exception:${text##*law-exception:}." ;; esac
  append_log "$project" "guard | edit | ask | $rule | $path | line $line_no of the new text"
  printf '%s at line %s of the new text: %s. The rule: %s.%s' "$rule" "$line_no" "$(printf '%s' "$text" | cut -c1-"$EVIDENCE_CHARS")" "$(why "$rule")" "$stated"
}

# ask <finding lines>: the prompt, one clause per rule; the first PROMPT_RULES in full, the rest
# counted, so a big edit still gets one prompt the user can read.
ask() {
  total=$(printf '%s\n' "$1" | grep -c .)
  clauses=$(printf '%s\n' "$1" | head -n "$PROMPT_RULES" | while IFS= read -r finding; do printf ' %s' "$(describe "$finding")"; done)
  more=""
  [ "$total" -gt "$PROMPT_RULES" ] && more=" And $((total - PROMPT_RULES)) more rule(s) after these."
  breaks="a code-rule break"
  [ "$total" -gt 1 ] && breaks="$total code-rule breaks"
  emit "oneloop, the code rules (1.1, 2.2, 3.4): this edit adds $breaks.$clauses$more Approve to make this the exception (the line then carries \`law-exception: <what the technology needs>\`); reject to have the line fixed." \
       "engineering law (1.1, 2.2, 3.4): this edit adds $breaks.$clauses$more The user is being asked; their approval is the exception, recorded on that line as a comment \`law-exception: <what the technology needs>\`. A rejection means: fix the line and retry, never route around it. The patterns are the law scout's (9.5), run over the edit."
}

# map_folders <root>: the top-level folders the project map's Key directories list, one per line
# (`- \`src/\`: …` and `- \`src/components/\` …` both name `src`).
map_folders() {
  tick=$(printf '\140')
  sed -n -E '/^#+ .*[Dd]irectories/,/^#+ /p' "$1/CLAUDE.md" 2>/dev/null | sed -n -E "s#^- ${tick}\\.?/?([^${tick}/]+)(/[^${tick}]*)?${tick}.*#\\1#p"
}

# nearest_dir <path>: the closest existing directory on the path, for a file whose folder is new.
nearest_dir() {
  d=${1%/*}
  while [ ! -d "$d" ] && [ "$d" != "${d%/*}" ]; do d=${d%/*}; done
  printf '%s' "$d"
}

# unlisted_folder: for a Write that creates a file under a top-level folder of its repository,
# the finding when the project map lists Key directories and this folder is not among them.
# Paths are compared physically, so a symlinked temp dir matches its repository.
unlisted_folder() {
  if [ "$tool" != Write ] || [ -e "$path" ]; then return 0; fi
  near=$(nearest_dir "$path")
  physical="$(cd "$near" 2>/dev/null && pwd -P)${path#"$near"}"
  root=$(git -C "$near" rev-parse --show-toplevel 2>/dev/null) || return 0
  case "$physical" in "$root"/*/*) ;; *) return 0 ;; esac
  under=${physical#"$root"/}
  folder=${under%%/*}
  case "$folder" in .*) return 0 ;; esac
  listed=$(map_folders "$root")
  [ -n "$listed" ] || return 0
  printf '%s\n' "$listed" | grep -qx -F -- "$folder" && return 0
  printf 'folder.unlisted %s:1:%s/ is not among the Key directories of %s/CLAUDE.md (%s)\n' "$rel" "$folder" "${root##*/}" "$(printf '%s' "$listed" | tr '\n' ' ' | sed 's/ $//')"
}

# judge: prompt on every rule whose count grows from the old text to the new (a new file has no
# old text, so every finding in it counts), and on a new file under a folder the map does not list.
judge() {
  new_findings=$(scan new)
  grown=""
  if [ -n "$new_findings" ]; then
    if [ "$tool" = Write ] && [ ! -e "$path" ]; then old_findings=""; else old_findings=$(scan old); fi
    grown=$({ printf '%s\n' "$new_findings" | sed 's/^/new /'; [ -z "$old_findings" ] || printf '%s\n' "$old_findings" | sed 's/^/old /'; } | growths)
  fi
  unlisted=$(unlisted_folder)
  findings=$(printf '%s\n%s\n' "$grown" "$unlisted" | grep .)
  [ -z "$findings" ] || ask "$findings"
}

read_hook_input || exit 0
[ "$(hook_field '.hook_event_name // empty')" = PreToolUse ] || exit 0
tool=$(hook_field '.tool_name // empty')
case "$tool" in Edit|Write|MultiEdit|NotebookEdit) ;; *) exit 0 ;; esac
path=$(hook_field '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$path" ] || exit 0
cwd=$(hook_field '.cwd // empty')
project="${cwd##*/}"
rel=$(relative_path "$path" "$cwd")
kind=$(path_kind "$rel")
case "$kind" in prose|generated) exit 0 ;; esac
[ -f "$LAW_SCOUT" ] || { append_log "$project" "guard | edit | skipped | 9.5 not found at $LAW_SCOUT"; exit 0; }
W=$(mktemp -d "${TMPDIR:-/tmp}/edit-guard.XXXXXX")
trap 'rm -rf "$W"' EXIT
domain=$(domain_role "$rel")
ignored=$(git_ignored "$path")
extract_block > "$W/block.sh"
write_texts
judge
exit 0
