# oneloop, the history

One entry per version, newest first. The README says what the setup is now; this file says how it got there.

- **14.1.0**: the scope guard points when the Scope step's output is not visible, after the first
  real dry run of 14.0.0 (a fresh Sonnet session driven by expect through a plain rename: the
  progress lines, the checklist line at Scope, the edit, the lint, the commit with the checklist
  ticked and archived, the final reply, no hook prompt, no guard pointer, one permission prompt
  from Claude Code itself for a `node` one-liner the test's allow-list did not cover) showed the
  child writing the scope line, the note and the explanation inside its thinking and believing it
  had printed them; the user's pick: "Wording fix plus a machine pointer". Once an edit passes the
  scope, `hooks/scope-check.sh` reads the session transcript for this turn's reply text (the
  assistant text blocks after the last human message: one typed, a string or text blocks with no
  tool result, not injected, not a compaction summary; or one queued mid-turn) and points when
  that stored text carries no `scope:` ("no scope line is visible in this turn (your thinking is
  invisible). Fix it now: print the progress line, `scope: <files>`, the note of at most 3 lines
  and the explanation … as chat text, then go on; nothing blocks this edit"), or when none carries
  the explanation (the word problem with effect or risk: "the explanation is not visible in this
  turn"); the log says `scope line not visible` or `explanation not visible`. A turn with no stored
  reply text is not judged: the session that built this showed its own transcript keeping none
  of the text sent along with a tool call (only text-only closing messages), while the dry run's
  child kept all of it, and the cause is not known; so silence is not proof of a missing line,
  and the pointer fires on the dry run's exact case only, text stored without the line. The
  reader fails open: a missing or unreadable transcript skips the check, a big transcript is read from its
  last 2 MB minus the cut line (0.12 s on a 150 MB one), each line is parsed with `fromjson?` so
  a line that is not JSON or has an odd shape is skipped (the 13.1.0 reader aborted on one).
  Known edge: a Stop hook's feedback arrives as a user message and counts as a new turn, so the
  next edit may be pointed at once more. The law's Scope step says "all of it reply text the user
  sees, before the first edit: thinking is invisible", the Guards bullet names the new pointer
  ("or made before the scope line and the explanation are visible … print what is missing"), the
  start skill's Scope step and the explain skill say the same ("a plan inside your thinking is
  not an explanation"); the README's loop step, hook row and the map follow. Minor: a new check
  that points, nothing removed or loosened. Trims that paid for the law's new words: "whatever
  the message named" (the ratchet already says a needed file goes on the scope), ", only to
  search" (the helper is already "a read-only Sonnet search"), "a behaviour the user did not ask
  to change" → "an unasked behaviour change", "3.1 to 3.4" → "3.1-3.4", "the frontend design
  law" → "the design law". Tests: `hooks/tests/scope-check.test.sh` gains the visible-output
  cases (a turn with no stored reply text passes, a progress line alone is pointed at, the scope
  line without the explanation, both visible, a new typed or queued message starting a new turn, a task
  notification, an injected text, a compaction summary and a tool result not being the user, a
  message with an image stored as blocks, `scope:` inside a tool result, the pointer order, a
  missing transcript) and a big-transcript case (a 2.7 MB fixture read from its tail, a
  non-JSON line skipped): 77 checks, main's hook fails 12; `tests/explain.test.sh` pins the new
  sentence (main's skill fails it); the law's pins gain three (main's law fails them). Law: 88
  lines and 12,408 characters before, 88 and 12,498 after (cap 12,500); code rules unchanged at
  49 and 7,596.
- **14.0.0**: auto-pilot with self-control, at the user's word ("whether i am in bypass-permissions
  mode or any other modes there is nothing should block file edits, the model shall strictly apply
  the engineering rules/laws without asking for edit permissions or to correct it. it should be in
  auto-pilot mode with self-control. the only allowed questions or asking, is clarification
  questions or critical change in logic that needs my confirmation"; their picks: the model
  estimates the criticality itself, the scope is read from the checklist file's `- [~]` lines, and
  `/oneloop:start` asks only when nothing names a line and several are open; then "instead of
  noteing violations … fix it since we are auto-pilot self-controlled self-judging by the model it
  self" and "hooks shall point and claude fixes raised problems"; then "I need the oneloop to
  `oneloop:explain` the implementation before starting the task (part of the loop, no approval
  needed, it's for helping me to keep up with the model while he is working …)" and "print very
  simple colorized vistual progress note which step we are in (previous, current, next) before
  progressing to a new step in the loop"). No hook asks or blocks any more, in any permission
  mode (Claude Code honours a hook's `ask` even in bypass-permissions mode, which is where every
  prompt of the day came from): the risk-zone, scope-check, commit-check and edit-guard hooks hand
  Claude a pointer beside the tool result (`additionalContext` alone, no `permissionDecision`)
  that names the problem and its fix, log it (`guard | <hook> | fix | …`; the risk zone's first
  edit as `first`), and Claude fixes it at once: the file goes on the task line, the checklist is
  ticked, staged and committed right after, the code-rule break is fixed in the next edit; a
  technical exception stays on the line as `law-exception: <what the technology needs>` and is
  listed in the final reply. The Scope step waits for no yes and the word "go" means nothing
  special any more: the scope line, the note, then `oneloop:explain` on the change (the problem,
  the pseudocode, the effect, the risks) so the user can follow the work, then Edit; the scope
  ratchet restates the scope on the task line and goes on; `- [~]` is written at Scope (`- [ ]`
  only while parked or waiting on a question); a progress line precedes each step (the four steps
  in order, ✅ on the done ones, 🔵 on the current, ⚪ on the rest); the final reply lists each
  guard's point and its fix; the only questions left, through `AskUserQuestion`, are a
  clarification the code cannot answer and a change in logic Claude judges critical, asked before
  it is built. The scope-check hook reads the scope from the checklist file alone (the `scope:`
  of every `- [~]` line of `docs/oneloop-todos/TODO.md`, joined), so the transcript reader with
  its yes, its "go" and its picked option is gone, and with it a failure seen the same day: the
  13.1.0 reader's jq aborted on a transcript line whose content was an array of blocks and then
  judged every later edit against a stale scope. `/oneloop:start` resumes a named line, or the one
  open line, without a question. Major, and a loosening the user chose, said plainly: every
  machine stop is gone; an out-of-scope edit, a risk-zone first edit, a code-rule break and a
  commit without the checklist all go through and rely on Claude fixing what the hook pointed at,
  and the yes at Scope is gone. The reminder line is `one loop · auto-pilot: a guard points, you
  fix · proof required · ask only a clarification or a critical logic change` (121 bytes). The
  law's cap rises from 12,000 to 12,500 characters to hold the explain and the progress-line
  rules, both asked for; four trims paid for part of it ("The list goes to the user at the end"
  gone, the catalog names in the last section gone, the risk-zone yes gone from Never waivable,
  the checklist's parked clause shortened). The long forms 1.1, 1.4, 1.6, 1.10, 2.2, 5.3, 9.5,
  15.28, 16.1 and 16.4, the start, explain, brainstorm and design-spec skills, the README, the map
  and the manifests follow. Tests: `hooks/tests/scope-check.test.sh` rewritten for the file-based
  guard (50 checks, from 81 transcript cases; main's hook fails 23), `risk-zone.test.sh` (33
  checks; main's hook fails 19), `edit-guard.test.sh` (117; main's fails 67),
  `commit-check.test.sh` (25; main's fails 12) and `loop-reminder.test.sh` (9; main's fails 1)
  read a pointer instead of a decision, `tests/explain.test.sh` pins the new handoff (main's
  skill fails it), the pins and the retired wording move with the law (main's law and main's code
  rules each fail both checks). Law: 88 lines and 11,994 characters before, 88 and 12,408 after;
  code rules 49 and 7,593 before, 49 and 7,596 after.
- **13.1.0**: `/oneloop:start` starts a new task, resumes an in-flight one or picks up a parked
  line, at the user's word ("start skill: enables me to start new, resume existing, or complete
  parked task."; their picks: the skill and the hook together, the pick is the yes, and a resume
  always asks once even with "go"). A task that names an open checklist line resumes it; no
  task lists the open lines of `docs/oneloop-todos/TODO.md`, `- [~]` first, then `- [ ]`, as one
  `AskUserQuestion` whose options carry the task in a few words and a description that starts
  with `scope: <files>` and says where the work stopped (`not started, from Edit` when nothing
  changed under the scope, `edited, from Check` on uncommitted changes); anything else is a new
  task, and "go" inside it pre-approves its scope as before. The scope-check hook learns that
  third source of the yes: when the user's answer picks an option whose description carries
  `scope: <files>` (Claude Code stores a pick as `"<question>"="<label>"`, matched exactly), that
  scope is a proposal placed just before the reply, so the pick approves it; a pick without one,
  a typed answer matching no option and an unanswered question propose nothing, and edits then
  prompt as before. So resuming a task in a fresh session costs one question instead of a
  question and a permission prompt. Minor: a new behaviour in a command and a new source of an
  approval that the user still gives by hand; nothing loosened. The law's Guards bullet names
  the picked option (three trims elsewhere paid for it: "written down" → "written", "for
  architectural work" → "for architecture", "and only to search" → ", only to search", "the
  scanner the edit guard runs" → "the edit guard's scanner"); the README's checklist paragraph,
  hook row and command row, and the map's entry point follow. Tests:
  `hooks/tests/scope-check.test.sh` gains the pick-list cases (the picked option's scope is
  approved and the other option's is not, backticks stripped and the words after `; ` or `. `
  dropped, an option without a scope, a typed answer, an unanswered question, the pick over an
  earlier task line, a pick without a scope leaving the line's proposal; 81 checks; main's hook
  fails 6 of them) and a pin for the law's new words (main's law fails it). Law: 88 lines and
  11,979 characters before, 88 and 11,994 after; code rules unchanged at 49 and 7,593.
- **13.0.0**: the checklist moves out of the project's root into `docs/oneloop-todos/`, at the
  user's word ("we can place the todo files in its docs/oneloop-todos folder so they can mess with
  the projects main files", read with them as: so they do not sit among the project's main files;
  their pick: fixed there, the old root files moved with `git mv` at the next Scope).
  `docs/oneloop-todos/TODO.md` is now the only task tracker and `docs/oneloop-todos/TODO.archive.md`
  its archive; the law's checklist paragraph and Guards bullet, the `start` and `status-report`
  skills, the README, the map and the manifests say so. The scope-check hook reads the task line
  from that file alone (a `- [ ] ... scope:` line added to a `TODO.md` anywhere else, the root
  included, proposes nothing), exempts the checklist and its archive from judgment instead of the
  root pair, and, while the checklist is missing and a root `TODO.md` exists, says in its reason
  to `git mv` that file and its archive into `docs/oneloop-todos/` first; the commit hook passes a
  commit that stages or names `docs/oneloop-todos/TODO.md` and asks on one that only carries a
  root `TODO.md`. Major because a rule's home moves and the hooks no longer accept the old one: in
  a project on 12.x or earlier, the next task's Scope step moves the root `TODO.md` and
  `TODO.archive.md` with `git mv` into `docs/oneloop-todos/` and that task's commit carries the
  move; until then the scope-check hook asks on every edit and its reason says what to do. This
  repository's own pair moved the same way in this commit. "at the repository root" joins the
  retired wording. Tests: `hooks/tests/scope-check.test.sh` gains the root-file cases (a task
  line written into a root `TODO.md` proposes nothing, an open line there does not count and the
  reason says to move it, a root or other `TODO.md` is judged like any file; 69 checks) and
  `hooks/tests/commit-check.test.sh` a second fixture in the old layout (a root `TODO.md` staged
  or named still asks, the `git mv` commit passes; 25 checks); the pins follow the new wording,
  and the old law, scope hook and commit hook fail 2, 30 and 6 of the new checks. Law: 88 lines
  and 11,980 characters before, 88 and 11,979 after (three trims elsewhere paid for the path);
  code rules unchanged at 49 and 7,593. Nothing loosened: the checklist stays mandatory, only its
  place changes.
- **12.0.0**: the edit guard prompts on everything the code rules ban, at the user's word ("these
  laws are my own coding style, i want to enforce every single law. when anyone see the codebase.
  he should see these all laws are applied cleanly. claude models can't ignore them unless the
  target technology will break if it used them"; their pick among the offered bites: a prompt on
  everything, no hard refusal). `hooks/edit-guard.sh` now returns `permissionDecision: ask` for
  every rule an edit adds, with a reason that names each rule, its line, the evidence and the
  law's words (the first four in full, the rest counted) and the same case beside the tool
  result; the user's approval is the exception, recorded on that line as a comment
  `law-exception: <what the technology needs>`, which the scanner lists (`note.law-exception`)
  and the audit shows; a line that already states one still prompts, with the exception quoted,
  so nothing passes on its own say-so. The guard judges every row of the scanner now
  (`ban.non-null` and `ban.inline-type` included, which 10.0.0 left to the diff read), a new
  file whole (its name and folder included, since it has no old text to compare against), and
  one rule of its own, `folder.unlisted`: a Write that creates a file under a top-level folder
  the map's Key directories do not list. The scanner (9.5) gains the rows the naming and
  placement law can judge without a parser: `name.type-case`, `name.interface-prefix`,
  `name.snake-in-camel`, `name.camel-in-snake`, `name.refused-word`, `name.boolean-prefix`,
  `name.export-file-mismatch`, `style.flag-parameter`, `cap.fn-params`, `file.two-things`,
  `file.type-home`, `file.constant-home`, `file.schema-home`, `file.style-home`,
  `file.name-case`, `file.refused-word` and the `note.law-exception` listing, each in the
  languages whose convention is the law's (Go's symbol case is visibility and C#'s `I` prefix is
  its own convention, so neither is judged; a Python or Ruby module holds many classes by its
  own convention; PascalCase file names stay where the language demands them, snake_case where
  it does; a name a framework fixes, a callback's boolean or an injector-filled constructor is
  weighed at the prompt). `hooks/path-kind.sh` resolves a path from the nearest folder that
  exists, so a new file's folder is judged too. The audit rule catalog (16.4) gains a row per
  new id (`cap.fn-params`'s row now says the scanner counts a declared function or arrow), a
  `note.*` listing table with a `none` severity, and `tests/catalog-ids.test.sh` checks the
  `name.`, `file.` and `note.` families against it too. The law's Guards bullet, the code rules' hook
  line, the 1.1 long form, 2.2's Enforcement, the README and the map say prompt where they said
  warn; "The code-rules hook warns", "never blocks" and "warning, not a block" join the retired
  wording. Tests: `tests/law-scout.test.sh` plants one instance per new rule and its allowed form
  (130 checks), `hooks/tests/edit-guard.test.sh` reads `ask` where it read `warn`, one case per
  rule, the stated exception, the multi-rule prompt, the folder rule, and a pin that every
  scanner rule has the law's words in the prompt (116 checks). For every session: an edit that
  breaks a code rule now waits for the user instead of going through with a note; no protection
  is removed. Law 11,997 → 11,980 characters, 88 lines ("never an instruction", "of your own",
  "of that scope line", "never fixed mid-task", "(by id)" and "banned-token" trimmed to make
  room); code rules 7,484 → 7,593 characters, 49 lines ("documented" and "exact" trimmed).
- **11.1.0**: `/oneloop:start <task>`, the loop's entry point, at the user's word ("sometimes
  claude might ingnore the oneloop. i need some entrypoint skill to trigger on a task .e.g.
  (start, do, go, or ...etc.)"; their picks: typed and self-triggered, named `start`). The skill
  (`skills/start/SKILL.md`) takes the task from its arguments (the user's last message when
  empty), makes sure the law is in context (it reads `law/engineering-law.md` under the plugin
  root when it cannot quote the law's first line), and restates the four steps as a checklist of
  the outputs each one owes: the scope line, the note and the `TODO.md` task line, then the wait
  for the yes ("go" in the task is the yes, a risk zone still asks); `- [~]` and the smallest
  diff inside the scope; lint, typecheck, test, `ui_check`, one `git diff` read; the commit with
  `TODO.md` ticked, and the reply of files, checks and side finds. Its description also lets
  Claude invoke it on its own when the user asks to start, do, build, implement, fix, change,
  add, rename or remove something and no loop step has happened yet, which is the case the user
  saw: a session that let a plain request slip past the loop. The law's last line names it
  (`Commands: /oneloop:start (the loop on a typed task), …`) and, to stay under the
  12,000-character cap, that line got shorter elsewhere: "(look up an id)" to "(by id)", "the
  code-rules hook runs" to "the edit guard runs", "Typed commands" to "Commands", "worked
  anti-patterns" to "anti-patterns", and "(UI work)" dropped after the frontend design law;
  11,996 to 11,997 characters, 88 lines. `tests/commands.test.sh` lists `start` among the
  standalone skills (a description, model invocation on, under the cap) and the pins add
  the `/oneloop:start` phrase and "A plain request is the loop". Code rules unchanged: 49 lines
  and 7,484 characters.
- **11.0.2**: `TODO.md` named in a comment is no longer debt. The edit guard's debt-marker scan
  (9.5, `clean.debt-marker`) fired on a comment line starting with `TODO.md` (seen on
  `hooks/scope-check.sh`'s own header while 11.0.0 was built): the marker regex now stops at a
  dot, so `TODO.md` and `TODO.archive.md`, the checklist's mandated names, pass, while `TODO`,
  `TODO:` and `TODO(` still warn; a marker that ends a sentence with a dot is the one case it
  no longer sees. The 9.5 HOW block also drops the `docs/work/` exclusion from its `git diff`
  line, the work-doc folder having gone with 10.0.0 (the hook and the audit swap that line out
  anyway). `tests/law-scout.test.sh` (95 to 97 checks) plants `TODO.md` in a `//` and a `#`
  comment and wants both left alone; `hooks/tests/edit-guard.test.sh` (61 to 62) allows the
  edit. Law sizes unchanged: 88 lines and 11,996 characters; the code rules 49 and 7,484.
- **11.0.1**: the law reaches the session in two parts. The live check after 11.0.0 found a fresh
  session got a 2KB preview of the law and a file path in its place: Claude Code keeps only a
  preview of a hook context over 10,000 characters and saves the whole to a file (its
  context-window page says so for hook output; measured here on SessionStart with `claude -p
  --settings`: 9,000 characters arrive whole, 10,500 are cut, 11,000 on plain stdout are cut the
  same way, and two hooks of 6,500 each both arrive whole, so the limit is per hook, not per
  event). The law with its header ran to 12,185 characters (12,411 after a compaction), and the
  dry run's session spent a tool call reading the saved file. Now `hooks/hooks.json` runs
  `hooks/session-start.sh` twice on every session start, `1` and `2`, and each run carries one
  part: the split is the `## ` heading nearest the middle by characters (the line nearest the
  middle when that heading would leave a part over 9,000), so today part 1 is lines 1 to 38
  (6,361 characters with its header) and part 2 lines 39 to 88 (6,519 with the header and the
  compaction anchor); each part's header names the part and its lines, the plugin version and
  the harness root, and part 2 carries the re-anchor, now "the law in its two parts is the law".
  `hooks/tests/session-start.test.sh` (22 to 37 checks) joins the two parts back into the law
  byte for byte, holds both under 10,000 on a fresh start and after a compaction, and splits a
  long law whose only heading sits at the top near the middle; `tests/hooks-wiring.test.sh` (30
  to 32) pins the two runs in order; `hooks/tests/code-rules.test.sh` (21 to 22) holds the
  code-rules context (7,328 characters) under the same limit. Law sizes unchanged: 88 lines and
  11,996 characters; the code rules 49 and 7,484.
- **11.0.0**: oneloop, the harness as a Claude Code plugin, at the user's word ("convert this
  harness to claude plugin that i can install and maintain once needed", "reallocate the folder
  inside our ~/Code project then install it and refresh claude plugins", "rename the repo as
  well"; the name from their pick, "oneloop"). The repository is the plugin and its own
  marketplace (`.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` with
  `source: "."`), installed with `claude plugin marketplace add nadyshalaby/oneloop` and
  `claude plugin install oneloop@oneloop`, updated with `claude plugin update oneloop@oneloop`;
  the dev checkout moved from `~/.claude/engineering-rules` to `~/Code/oneloop`, and the GitHub
  repository was renamed from `claude-engineering-rules` to `oneloop`. A plugin cannot add to
  CLAUDE.md or place a rules file, so the law reaches the session another way:
  `hooks/session-start.sh` hands the whole core law to every session as it starts (startup,
  resume, clear, compact, fork), headed by the plugin version and the harness root, and after a
  compaction or a resume adds the re-anchor lines (the re-anchor hook is gone);
  `hooks/code-rules.sh` hands the code rules (front matter off) to a session with the first code
  file it reads or edits, once per session, on PreToolUse for Read and the four edit tools. The
  law's paths are relative to that root (`references/`, `law/engineering-code.md`,
  `settings/loop.json`); the typed commands are `/oneloop:brainstorm`, `:audit`, `:triage`,
  `:design-spec`, `:release-notes`, `:status-report`, `:update-rules` and `oneloop:explain` (a
  skill's name is its folder, the plugin adds the prefix; `update-engineering-rules` became
  `update-rules`); the reader is `oneloop:er-reader`. The scope check now reads the scope from
  `TODO.md`: the session that shipped 10.1.1 showed that Claude Code keeps every tool call and
  every user message in the transcript but only some of Claude's own chat text (19 of a day's
  messages), so the `scope:` line in chat could not be relied on; at the user's pick ("Yes,
  TODO.md is the source") the task line is `- [ ] <task> (scope: <files>)`, appended to its
  group, and the hook reads the scope from the Edit, Write or MultiEdit that adds it (of several
  added at once, the last; a line the edit's old text held, or one turning `[~]`, adds nothing),
  while a scope line in chat, in another file's edit or in a tool result no longer counts
  (`hooks/tests/scope-check.test.sh`, 54 to 62 checks). Gone: `install.sh` and its 62 checks,
  `settings/hooks.json` (now `hooks/hooks.json`, every command under `${CLAUDE_PLUGIN_ROOT}`),
  `settings/claude-md-block.md`, the rules copy and the CLAUDE.md block, `hooks/re-anchor.sh`.
  New: `bin/setup-statusline.sh` (a plugin cannot set the status line; this writes one that finds
  the installed version through installed_plugins.json on each render and falls back to the
  personal script; `--check`, `--remove`, `--force`), `tests/plugin.test.sh` (the manifests,
  their versions equal to this entry's), `tests/setup-statusline.test.sh`,
  `hooks/tests/session-start.test.sh`, `hooks/tests/code-rules.test.sh`; `tests/old-words.test.sh`
  also refuses the installer era's names now, and `tests/hooks-wiring.test.sh` pins the plugin
  root and the absence of a status line in the fragment. The docs say the plugin: the README, the
  map (its `risk_regex` covers the manifests, the wiring and `bin/`), the update-rules skill (the
  push is the publish, then `claude plugin update`; a hook check runs against the installed
  copy). One limit, said plainly: a subagent gets no law, because no hook injects context into
  one, where the CLAUDE.md import may have reached it; the law allows only the read-only reader
  anyway. Sizes: the core law 11,939 to 11,996 bytes (88 lines; the paths shrank, the checklist
  and the scope-hook rule grew); the code rules 7,598 to 7,484 (50 to 49 lines; the managed-by
  line went).
- **10.1.1**: `TODO.md` is the only task tracker, at the user's word ("if the user asked to work
  from old docs or tracking files. the harness shall only study his file(s). but strictly use our
  main todo to reflect this work. TODO.md is the only main trusted task tracking in the harness.
  that why updating it is a god law not optional after each task change"): the checklist
  paragraph now says a doc or tracking file the user points at is studied as input and never
  used to track, and that each marker is written the moment the status changes; four pins for
  it, one reworded. The scope check learns two more shapes of the user's reply, both read off a
  real transcript this session: a pick-list answer (Claude Code stores an `AskUserQuestion`
  answer as that call's result, so the yes the law requires through `AskUserQuestion` never
  counted and the first edit after it still asked) and a message typed while Claude was working
  (stored as a `queued_command` attachment with `humanTurn: true`, never as a user message; in
  the session that shipped 10.1.0 every message after the first was one of these, so the hook
  saw none of them). Another tool's result and a queued task notification are still not replies.
  The transcript is now read in one pass that keeps the ids of the pick-lists asked
  (`hooks/tests/scope-check.test.sh`, 48 to 54 checks, the four new ones watched failing on the
  10.1.0 hook). Sizes: the core law 11,786 to 11,939 bytes (88 lines), its cap 11,800 to 12,000
  (the tracker rule is always-on, asked for by name); the code rules unchanged at 7,598.
- **10.1.0**: the checklist, at the user's word ("add very very simple checklist one liner per
  task like most of simple todos out there and the flow must tick each task when its status
  change and achieve the whole list once its done. updating this list each task change is a
  must not nogotiatable mandatory thing"), and the scope ratchet as a hook (the pick, "Add a
  scope hook", after the 10.0.x dry runs showed the text rule not holding: Sonnet sessions
  given "go" widened to a second file and committed both). The loop gains the checklist:
  `TODO.md` at the repository root, one line per task, `- [ ]` at Scope with the scope line,
  `- [~]` at the yes or "go", `- [x]` at Commit with `TODO.md` staged in the same commit (no
  hash on the line: it does not exist until the commit it must sit in); a task sits under a
  `## <milestone>` heading when the user names one (their question mid-build, "i may work on
  multiple milestones how the todo will manage that", and their pick, "Milestone headings,
  archive per group"), else unheaded at the top, and a group whose every line is ticked moves
  whole to `TODO.archive.md` under a dated heading while the other groups stay, in that commit;
  the checklist joins the never-waivable list. Two new hooks, both asking and
  never blocking: `hooks/scope-check.sh` (PreToolUse on the four edit tools, second in line
  after the risk-zone prompt) reads the session transcript for the approved scope line, the
  `scope:` line that stood when the user last replied, or, after a message of theirs saying
  "go", the first one printed after it, so a restated scope waits for a new yes even after
  "go"; it turns an edit to a file not on that line (a path, or a folder it is under), an edit
  before any approved line, or an edit while `TODO.md` has no `[ ]` or `[~]` line into a
  permission prompt. `hooks/commit-check.sh`, the first hook on the Bash tool, turns a `git
  commit` that neither stages nor names `TODO.md` into one. Nothing to judge stays silent: no
  repository, a file outside it, `TODO.md` and `TODO.archive.md` themselves, no readable
  transcript, a command with no commit in it. Tests: `hooks/tests/scope-check.test.sh` (48
  checks on transcripts built from the harness's real-shape lines, where replies, tool
  results, injected texts and compaction summaries are told apart) and
  `hooks/tests/commit-check.test.sh` (21); `tests/hooks-wiring.test.sh` now allows exactly
  the commit check on Bash and pins the edit-hook order (risk-zone, scope-check, edit-guard);
  nine new pins. The status-report skill reads `TODO.md`; this repository keeps its own
  `TODO.md` and `TODO.archive.md`; the README and the map name the two hooks. Sizes: the core
  law 11,084 to 11,786 bytes (85 to 88 lines), its cap 11,200 to 11,800 (the checklist and the
  two guards are always-on rules; the side-find definition and the conventions line lost their
  example lists to pay for part of it, and the two new hooks say "your approval is the yes" in
  their own prompt text rather than in the law); the code rules unchanged at 7,598. Two limits, said
  plainly: the scope check judges only what the transcript holds, so a `claude -p` run without
  session persistence is not judged, and a `git -C` whose folder is a shell variable is judged
  against the session's folder instead.
- **10.0.1**: the reader runs on Sonnet, at the user's word ("replace haiku with sonet"):
  `agents/er-reader.md` (`model: sonnet`), the law's Helpers line, 1.8, the README, the agents
  test (which now refuses any other model) and the fresh-session recipe in
  `/update-engineering-rules` all say Sonnet. And two loop lines tightened after the 10.0.0 dry
  runs, where Sonnet sessions given "go" printed no scope line, and one, told the file, widened
  to the caller in a second file and committed both without a stop (another, told "only" that
  file, renamed it and left the caller broken as a follow-up): "go" is now pre-approval of the
  printed scope line (print it and the note, then proceed without waiting), and the scope
  ratchet waits for the yes even after "go" (a file the change needs is in the scope or the work
  stops, whatever the message named); two new pins hold both. The core law 10,932 to 11,084
  bytes at 85 lines; the code rules unchanged at 7,598.
- **10.0.0**: one loop for everything, at the user's word ("Re-engineer my engineering-rules
  plugin into ONE mode for everything. No fast/careful, no tiers, no modes of any kind. Every
  task, from a typo to a new module, runs the same short loop"; the pick, "Yes, build it"). The
  always-on law now carries the loop. Scope: the project's `CLAUDE.md` first, no discovery when
  the message names the files, else the symbol, its file, its direct callers and imports within
  a budget of 10 tool calls, then one `scope:` line, a note of at most 3 lines and the yes
  through `AskUserQuestion`, with the word "go" as pre-approval. Edit: one grep for something to
  reuse, the smallest diff, an existing test file extended in the same edit, the scope ratchet
  (a file outside the scope line, more than double the files, a risk-zone file: stop, restate,
  wait) and the stuck-twice stop. Check: lint on the changed files, typecheck, the test command,
  `ui_check` under a UI path, then one read of the diff and no reviewer. Commit: files staged by
  name, one commit, and a final reply of the files, the check results and the side finds. Deploy
  is a command (1.11: the checks, the deploy, the live check). The guards: the risk zones (the
  first edit to a path matching the risk regex needs the user's yes, even after "go") and the
  code-rules hook, which warns and never blocks ("Hard blocks caused silent edit-retry loops").
  The map rule: `CLAUDE.md` holds the four check commands, the key directories, the 5 to 10
  entry files and the conventions under 60 lines; over that is a side find. Helpers: none, but
  `er-reader`, read-only, after grep has failed twice ("No Builder, no Reviewer"). Plan mode is
  the user's own to enter, and there Scope is the plan. New files: `settings/loop.json` (the
  four checks, `discovery_budget`, `risk_regex`, `ui_path_regex`); `hooks/risk-zone.sh`, which
  turns the first edit to a risk-zone file into a permission prompt (the pick, "Hook turns the
  first edit into a permission prompt") and records the edit on `PostToolUse`, so a rejected
  edit asks again and the next edit passes; `hooks/loop-reminder.sh`, exactly one line per
  prompt, `one loop · wait for yes unless "go" · proof required · risk zones need my yes` (81
  bytes, where the advisor cue was 521); this repository's own `CLAUDE.md` as a map; and tests
  for the two hooks, the config, the map, the one helper and the commands, with the edit guard,
  re-anchor, notify, status-line, hooks-wiring, install, short-law, explain, old-words and
  references tests rewritten to match. The re-anchor prints three lines (the law, the code
  rules, resume at the loop step you were in); every turn end notifies; the status line drops
  the ledger position; `PostToolUse` is the ninth wired event. Removed, at the user's words
  (section 8 of the request, "DELETE"), each a protection the loop no longer carries: the fast
  and careful lanes and `scripts/lane.sh`; the Plan, Implement and Verify & Deploy checklist,
  the phase ledger and the plan note (the work-doc); the six deploy proofs (a boot against a
  production-like copy, switches that default off, a named rollback and the rest; a deploy now
  runs the checks, deploys and verifies live); the review pass and the `er-reviewer` and
  `er-builder` helpers; the ship gate (11.3) and cross-package verification (11.4); the cleanup
  sweep (13.2, `scripts/sweep.sh`); the perf scout (9.4), the design scout (15.29) and the
  design pre-flight (15.30) with `scripts/scout.sh` (the pick, "Delete them"); the debug pages
  (10.1, 10.2; stuck twice is now stop, root cause, ask); the question banks (06-questions);
  the advisor (5.7 and the advisor cue hook); the logic-first gate, so `explain` explains and
  gates nothing (the pick, "Drop its gate role"); the trivial-ask carve-out; "done when"
  authoring, the test-first ritual and task-branch creation; automatic release notes (16.13
  prints only when asked); the per-step `→ verify:` line of the code rules (a change is proven
  by a check you ran); and the edit guard's hard block, now a warning. The per-category test
  table of 9.2 survives as the domains-only table in 3.3. 31 reference pages go (103 to 72),
  and the 2.x, 3.x, 5.x, 14.1, 15.x and 16.x pages that cited the removed machinery now cite the
  loop's steps, `ui_check`, the read of the diff, the scope ratchet and side finds. Sizes: the
  core law 69 lines and 9,381 bytes to 85 and 10,932, and its character cap 10,000 to 11,200,
  because the loop and the guards now live in the always-on law where the workflow page's
  13,784 bytes per task and the cue's 521 bytes per prompt used to be; the code rules 7,572 to
  7,598 bytes at 50 lines. The `/engineering-rules:workflow` command is gone: a plain request
  is the loop.
- **9.19.0**: the cleanup sweep's eight mechanical classes as one proven script, the last task of
  the token-cut series (the user's pick, "Yes, build it"). `scripts/sweep.sh` runs classes 1, 2,
  3, 6, 7, 8, 12 and 13 of 13.2's Step D (debug output, `removed:` markers, ownerless debt
  markers, scratch files and empty folders, placeholders and stubs, changes outside the Plan's
  files, branches made during the task, focused or skipped tests) with the patterns 13.2's table
  held, now kept only there. Before it reads the change it proves every check on a planted
  repository (ten planted hits: one per class, two for classes 6 and 7) and stops with exit 2
  when one misses; then it prints every hit for the session to judge. `scout.sh --sweep <base>
  <work-doc>` runs it after the scouts, whose rows classes 10 and 13 already asked for, so the
  workflow's cleanup step is one command; the other classes (4, 5, 9, 11 and the rest of 10) stay
  by hand, their rows word for word. The sweep reads more than the old commands did: uncommitted
  and untracked work as well as commits, a rename as both of its paths (so a folder a move
  emptied is found), paths with spaces or brackets taken literally, a Plan's folder and glob
  entries, and branches from their reflog since the task's branch was made (a first push
  included) where the old row asked for a cross-check by hand. It leaves out only the work-doc
  itself, and docs/work/ for class 8 as before. Measured on a clean change: the cleanup page 7,147
  to 6,651 bytes, the workflow page 13,778 to 13,784, the ten commands the eight rows spelled out
  (1,125 bytes of cells) and the scout run become one 75-byte command, and the sweep prints 462
  bytes: about 1.1k bytes and ten commands fewer per cleanup. Eight pins moved to the script's
  report lines and four new ones hold the command. tests/sweep.test.sh is new (56 checks):
  sixteen of its guards were each seen failing on a copy with that guard broken, all but the
  one for a path with a space, which no one-line break reaches, and four broken copies show the
  self-check stopping the run. tests/scout.test.sh gains 13, eight of which fail against the old
  scout.
- **9.18.0**: the debug page split, the fifth token-cut release (the user's pick, "Split it").
  10.1 keeps the ways in, the trigger conditions and D1, the root-cause investigation (3,614
  bytes); the new 10.2 holds D2 to D4, the hypothesis chain, the circuit breaker, the advisor's
  two later moments, the forbidden patterns and the worked example (7,156). A bug fix's
  investigation at Plan now reads 3,614 bytes instead of 11,161; a stuck task reads both
  (10,770). 10.1 ends by sending debug mode on to 10.2, the workflow's stuck-twice line reads
  "read 10.1, then 10.2", and the citers of the moved parts point at 10.2 (5.7's advisor moments
  before a fix and before a halt, 6.10's hypothesis chain). A sentence-by-sentence check found a
  home for every one of the old page's 141 sentences.
- **9.17.0**: the naming rules back in front of the model, and in more places than before, at the
  user's pick (the always-loaded code rules over the short placement page). 9.13.0 had left 2.2's
  symbol table and refused names in the full guide, read only where a repo lacks a kind of file
  or in a workflow review. The code rules now carry them as one Names paragraph (834 bytes):
  casing per kind of name, `is`/`has`/`can`/`should` booleans, verb-first functions, the
  language's own private marker, a file's name agreeing with its primary export, and the refused
  names, so they are there whenever code is written, new names in existing files included. They
  apply where the language, its frameworks and the codebase set no convention: the table is
  JavaScript-flavoured and the code rules load for every language (Python keeps its own style,
  Express keeps `res`). 2.2 keeps the full table and its examples, with a note that the short
  form wins where the two differ and a language's, framework's or codebase's own convention
  comes before both. The code rules grow from 6,737 to 7,572 bytes (cap 7,500 to 7,600); nine
  new code-rule pins, which fail against the rules before this change. Open sessions keep the
  copy they loaded until they restart.
- **9.16.0**: the workflow asks about helpers while planning, at the user's word ("the workflow
  hasn't asked me whether i should use them or continue on the main chat"). With the agent tool
  there, Plan step 2 asks, in the round of the which-reading question or on its own and before any
  helper is sent: helpers where they fit, or all in this chat? It recommends helpers for a wide
  unfamiliar tree, independent tasks or a likely careful lane, this chat otherwise. The pick goes
  on the work-doc's Goal line (`Helpers: on | off`). Off runs the sweep, the building and the
  review here, as a missing agent tool already did; on only allows them where they fit (a
  fast-lane review still runs here, a one-task plan still gets no builders). A fully known task
  is asked too; a resumed work-doc keeps its pick and asks only when it has none. The first
  ledger print now reads `Helpers: available | unavailable` (the tool, not the pick), since it
  comes before the question. No `:agents` switch comes back. The page grows from 13,395 to
  13,756 bytes and its cap from 13,500 to 13,800, which also leaves room for the held debug
  split's 22 bytes; the workflow guard gains four pins and updates two, all six failing against
  the page before this change.
- **9.15.0**: the logic-first gate stressed, at the user's word ("keep it reminder but stress on
  it"): the per-prompt cue now calls it a hard gate in plain chat and the workflow alike, for
  logic the user hasn't seen (a new task, approach or plan), says why (the user must stay on top
  of all logic built), names AskUserQuestion for the yes, and says approved logic being carried
  on, or a trivial edit, needs no new yes. It stays a reminder that never blocks: the user chose
  that over an edit-blocking hook. The cue grows from 297 to 521 bytes a prompt (its cap from
  320 to 530), and the law's gate line adds "in plain chat and the workflow alike" (9,343 to
  9,381 bytes). A scan of this machine's sessions found no real-project session where a new
  task arrived after the gate went in, so whether it fired there is still unchecked.
- **9.14.0**: the ship gate, the fourth token-cut release (the user's pick, "Trim + skip on
  docs-only"). A diff of only tests, docs, comments, CI config or editor settings (11.3's own
  skip row, with CI config spelled out as pipeline files only: env, build and startup config
  always read 11.3) now writes its three ship rows as skipped without opening 11.3;
  anything else still reads it when the manifest has a build or start script or the task
  deploys (the workflow's Verify & Deploy step 1). 11.3 drops from 9,780 to 8,160 bytes: the
  explanations and the "Anti-rationalizations" table go, and the two rows of that table that
  held rules found nowhere else move into the legs (an absent e2e suite means one throwaway
  request with a real assertion, never a skipped leg; a build warning is checked against the
  base, pre-existing to the sweep's class 10, new to the review). The skip rule now names both
  reasons (what was searched, or the diff's scope), and "See also" goes. The old read trigger
  joins the retired-wording list. The workflow page grows to 13395 bytes.
- **9.13.0**: the file-placement page split, the third token-cut release (the user's pick,
  "Split it"). Before any file or folder is created, the code rules, the workflow's Implement
  step 1, the builder helper, 1.1 and 9.3 now send the model to the new 2.3 (1,993 bytes):
  detect the repository's layout, state it, obey it exactly, never migrate as a side effect.
  Only a gap (a new repository, or a kind of file it has never had) reads 2.2 in full, and a
  review reads 2.3 first, then 2.2 in full (12.7). 2.2 hands its precedence section to 2.3 and
  drops some explanation (24,991 to 23,288 bytes); it keeps every table and rule, and every
  section other pages cite by name. A new file in a repository with a settled layout now costs 1,993 bytes of reading
  instead of 24,991. The always-loaded code rules change by one character (2.2 to 2.3), and the
  pin that guards that line moves with it; the two old pointer phrases join the retired-wording
  list, so neither can come back. 102 reference pages.
- **9.12.0**: the review pages, the second token-cut release: what one review reads (12.2,
  12.3, 12.4, 12.6, 12.7 and the reviewer's own page) drops from 17,650 to 15,864 bytes, and
  12.5 (UI work only) from 4,590 to 4,529. 12.2 keeps all nine coverage rules and its ledger in
  2,407 bytes instead of 3,812 (the explanations go); every verification list says "yes / no"
  once in its heading instead of on each line; 12.3 keeps "reproduce, do not reason" in one line
  (the reviewer's page carries the rest); 12.7's reuse-search item says the same in fewer
  words. No rule, check or verification question goes.
- **9.11.0**: the workflow page cut from 15,413 to 13,307 bytes, the first of the token-cut
  releases the user picked ("Yes, the whole run"): the page loads with every workflow run and
  stays in context for all of it. Only text the always-on law, the code rules or the reviewer's
  own page already carry goes, and every rule stays: the ways-in paragraph and the references
  path; the restated precedence, recommended option, whole-file read, reuse search, explicit
  paths, six proofs, helper re-run and present-at-base follow-ups; the reviewer's return format;
  the self-audit's ten "yes / no" tails (one header now); the route table's row for the workflow
  itself; and the section-number paragraph (the law says how a number finds its page, and the
  reach test shows every page it listed is still cited). Parallel work moves into the Helpers
  paragraph. Kept on purpose: the route table, which 15.19, 16.1, 16.2 and 16.3 route by when
  the user's words match a route, and every step number, which 82 citations elsewhere use. The
  waiver line points at the law's never-waivable list and keeps only its two workflow-only items
  (a blocking ship-gate leg, the review); the power guard's row is split the same way, one row
  on the law's words. The page's size cap drops from 16,000 to 13,500 bytes, so the cut stays
  cut; the old page fails it.
- **9.10.0**: cleanup release 4d, the last: the folders and files named for the old six-phase
  flow are renamed, and a guard keeps the old names out. `06-phase-1-clarify` is now
  `06-questions`, `09-phase-3-implement` `09-implement`, `10-phase-3b-debug` `10-debug`,
  `11-phase-4-verify` `11-verify`, `12-phase-5-review` `12-review` and `13-phase-6-finish`
  `13-cleanup-and-landing`; six pages take their titles' names (1.4 questions and decisions,
  1.8 helpers, 10.1 debug when stuck, 13.2 the cleanup sweep and landing rules, 16.13 printing
  the release notes, 16.1 brainstorm), and `tests/sub-commands.test.sh` is
  `tests/commands.test.sh`. Section numbers do not change, so every citation still resolves; the
  seven files that named a path (the scout script, the edit guard hook, the reviewer helper and
  four tests) move with them. Nothing outside the repository reads one: a search of
  `~/.claude`, the memory and the project folders found them only in the old, disabled
  plugin's source under `~/Code`, which names its own copies, and in saved runs of a deleted
  skill. `tests/old-words.test.sh` fails when an old-flow name (a phase
  number, the Sprint Backlog, the Retrospective, the wizard tool, the update log, full or quick
  mode, a sub-command, an old folder name) comes back in what the model and the user read,
  and shows itself catching planted ones; it proves names, not rules. Allowed on purpose: the
  changelog and the tests, 16.13's older labels and the two `Phase 01` label examples. A session
  already open keeps the old paths until it restarts.
- **9.9.0**: cleanup release 4c, the law's long forms (1.1, 1.3, 1.5, 1.6, 1.9, 1.10, 1.11), the
  doctrine and working pages (2.1, 2.2, 5.4, 6.2, 6.6, 11.3, 12.7, 14.1), the README and the
  workflow's route table in the workflow's words: phase numbers become Plan, Implement, Verify &
  Deploy and the review; acceptance criteria become Done-when checks; the file allowlist becomes
  the task's declared files; "the wizard tool" becomes `AskUserQuestion`; the drift check runs
  after every task; the route table's "Sub-command" column is "Command". One rule aligned: 2.2
  said to read it at the old Phase 1 as well as before creating a file, and now matches the
  workflow's Implement step 1 (read it before a source or test file or a folder is created);
  and 1.6 and 5.4 no longer read the old clarify round as the Plan's rules: the goal is
  confirmed first only when the ask reads two ways, and the coverage is the one-line list with
  6.15's full map only on the lane's risk list (the workflow's Plan steps 2 and 4). Kept on
  purpose, since none is an old-flow name: "the always-on law" (the workflow page's words), "the
  logic-first gate" (the explain skill's) and "the short law" (the update skill's, 5.4's and the
  README's name for the one-file law, which calls itself "this short form"); the hook tests' ledger
  samples in the old "(n of 6, Phase m)" shape are data for a parser that takes any "(n of m,
  name)", and a ledger line naming "Verify & Deploy" was read back correctly.
- **9.8.0**: cleanup release 4b, the route pages (16.2 to 16.8) and the route skills in the
  workflow's words, and the audit aligned with the law on line caps. The whole-codebase audit
  (16.3) still extracted "function lines, params, nesting, file lines" with a default floor of
  "40 / 3 / 3 / 500", so it kept enforcing the two line caps 5.0.0 removed at the user's word;
  the floor is now 3 / 3 (params and nesting), and a project's own rules can still set line caps.
  The triage page (16.2) drops the same two caps from its Important examples, and its worked
  example no longer rests on a 500-line cap; the design-spec route (15.19) stops citing "the hard
  cap (1.1) is 500" for a spec's length. The audit's own steps, "Phase 0" to "Phase 6", are
  renamed "Step 0" to "Step 6" (16.3, 16.4, 16.6, 16.7, 16.8), so they no longer read as the
  workflow's phases; "the wizard tool" becomes `AskUserQuestion`, the Retrospective becomes the
  Follow-ups, and the route skills say "a command" for "a sub-command". Words only elsewhere.
- **9.7.0**: cleanup release 4a, the design pages (15.1, 15.2, 15.19 to 15.30) and 12.5 in the
  workflow's words. The design scout's page (15.29) now describes the run `scripts/scout.sh`
  already makes: with the other two scouts after every task, once the change has a UI file,
  and again inside the design pre-flight at Verify & Deploy step 1; its separate run at the
  review's start is gone, so 12.5 takes the `pre-flight` table and the staged rows in the
  Evidence. It keeps the same safety net as 9.6.0, and the workflow's Implement step 5 now names
  a Critical design row beside the perf row and the secret (the page goes from 15,400 to 15,417
  bytes); a pre-existing tell goes to Follow-ups, as
  law 1.9 says, where the page offered to fix it. The security check (12.3) gains the step 9.5
  already relied on: it re-judges every staged `sec.hardcoded-secret` row, the only check that
  may clear one. The design pipeline in 15.2 is redrawn on Plan, Implement and Verify & Deploy;
  "update log" becomes "release notes" and "the wizard tool" `AskUserQuestion`. Words only
  elsewhere.
- **9.6.0**: cleanup release 3b, the perf and law scout pages (9.4, 9.5) in the workflow's words,
  and their rules aligned to what runs. `scripts/scout.sh` runs the scouts once after every task
  (the workflow's Implement step 5) over the whole change against the base, committed or not, so
  the pages' two run points (each stage's own files, then the whole scope at the review's start)
  become that one run; run-point ids go from `stage-<n>` and `phase-5` to `task-<n>`. The safety
  net is kept, by the user's pick ("Keep the net"): a Critical perf candidate, a hard-coded secret
  or a row in doubt is never dismissed after a task but staged into the work-doc's Evidence, which
  the reviewer is handed and re-judges (12.4, 12.7), and a staged row makes the review run even
  on a diff that changes no behaviour; the workflow's Implement and Verify steps now say so (the
  page goes from 15,215 to 15,400 bytes). A pre-existing finding in a touched file
  goes to Follow-ups, never fixed here, as law 1.9 says, where the law scout's page still offered
  to fix it. The scan blocks the tests run are unchanged apart from their comments.
- **9.5.0**: cleanup release 3a, the verify, review, debug, finish and catalog pages in the
  workflow's words, with three rules aligned to the workflow the user runs (the user's picks:
  "Match the live rules", "Test first, like the workflow", "One per task, like the workflow").
  - **The finish page (13.2)** goes from 16,336 to 7,147 bytes: the cleanup sweep (Step D, its
    thirteen classes and their check commands unchanged) and four landing rules the user kept
    ("Typed 'discard' first", "Tests after a local merge", "Worktree goes last", "Leave
    worktrees properly"). Its other steps are gone: they repeated the workflow page's Verify &
    Deploy steps, apart from two old habits the workflow had already dropped (the closing
    summary's offer of a scheduled follow-up, and leaving the work-doc open when the branch is
    kept); the release notes' field guide and voice move to 16.13 (5.3 re-pointed), and the
    rule for a session that died mid-close moves into the workflow's resume check. The workflow
    page grows from 15,043 to 15,215 bytes for that rule and the pointer to the landing rules.
  - **Rules aligned, not words only (9.2, 9.3).** Tests are written first and seen failing before
    their code (the workflow's Implement step 3); the break-a-line mutation stays as the proof for
    a test over code already on disk. One commit per task, not one per stage, since the resume
    check reopens a task whose commit is gone. A user can waive tests for one task in their own
    words, the protection lost recorded, as the law and the workflow's Waivers already said.
  - **Words only** in 10.1 (the work-doc's `status` stays `implement` while debugging, as its own
    close already said), 11.3, 12.2, 12.5, 12.8, 12.9 and the four catalogs: phase numbers,
    the Evidence Ledger, the Retrospective, the "wizard tool" and the update log become the
    workflow's own names.
- **9.4.0**: the workflow page, trimmed; the last of the four trims. Words only: all 64
  `tests/fixtures/workflow-power.txt` rows homed on the page, the coverage line, the route table's
  shape and the work-doc's sections stay, and the page, read on each use, goes from 15,466 to
  15,043 bytes (15,654 before 9.3.0 trimmed its blurb). What went: the intro's repeat of how the
  law and the code rules load (the law says it), the ways-in line's "is the default ... runs the
  same flow" (the route table's first row says it), the self-audit's alignment padding, and the
  route table's longer "right when" notes (the brainstorm's one or two questions per turn stays in
  16.1). Words-only trimming ends here: the page's other sentences each carry a rule, and cutting
  further would drop one.
- **9.3.0**: the always-on law and the listed blurbs, trimmed; the second of the four trims.
  Words only: all 72 of the law's pins, every rule clause and the 1.4 advisor line the cue leans
  on stay, and the law, loaded with every request, goes from 9,597 to 9,343 bytes. What went:
  how the law loads ("through the user-global CLAUDE.md, with nothing to call"), the pointer
  "The procedures are 1.5's long form." (the header names the long forms' folder), and filler
  in the precedence line, 1.2, 1.4's first bullet, 1.5, 1.8, 1.10 and 1.11; "questions through
  the question tool" now names the tool, `AskUserQuestion`. The blurbs every session lists keep
  every trigger condition (the workflow's everyday-word guard, explain's "before changing
  anything for a new task", each helper's when) and lose their padding: the frontmatter of the
  workflow, explain, update-engineering-rules and the three helpers goes from 2,302 to 1,949
  bytes.
- **9.2.0**: the per-prompt advisor cue, one line. The user ticked all four trims offered ("The
  per-message reminder", "Always-on rules and skill blurbs", "The workflow page's phases",
  "Repeats in your own CLAUDE.md"), each its own release, the most repeated first. The cue
  printed into every prompt goes from 863 to 297 bytes: it keeps the logic-first gate with its
  "a detailed or fixed ask is not a yes" and the advisor's moments, and leaves to the always-on
  law's 1.4 what the answer is worth, stating the decision first, the no-advisor case, acting on
  a review or root cause and a change of direction, and the protocol path (the law cites 5.7).
  Its fixture test pins the new line and caps it at 320 bytes (was 900); the wiring test checks
  that the cue names law 1.4 instead of the path; 5.7 says what the cue now carries.
- **9.1.0**: the debug check-back time goes. The user: "drop the timeout thing and focus on the
  todos". The debug bank's Q6 (when to stop and check back) and 10.1's Check-back time rule,
  both from 8.1.0, are removed; Q6's number stays a gap, so Q7 and Q8 keep every reference.
  10.1's circuit breaker after three failed hypotheses stays the bound on an investigation.
- **9.0.0**: one way in. The user: "build vs workflow. what's the different keep only one", then
  "Keep workflow, drop build". `/engineering-rules:build` was a 1 KB doorway that only loaded the
  workflow skill, so it goes, and `/engineering-rules:workflow <request>` is the default route,
  running the same flow. The law's route line, the README, the audit, brainstorm, design-spec and
  triage skills, the workflow page's ways in and route table, and the brainstorm (16.1), audit
  (16.3) and research (6.11) pages name the workflow; a brainstorm or research handoff goes to a
  new task's Plan. `tests/sub-commands.test.sh` holds the doorway shape to the doorways only,
  since the default row is now the workflow skill itself, and `tests/install.test.sh` uses the
  workflow link for its conflict and missing-link cases. The installer drops the stale
  `engineering-rules:build` link; open sessions list it until they restart. A command goes away,
  so a major version. Workflow page 15,689 to 15,654 bytes; core law 9,594 to 9,597 bytes.
- **8.1.0**: the question banks speak the workflow's words, the second of four cleanup releases.
  The user, of the options: "Retire it" (the repo brief), "One list, deeper on risk" (coverage),
  "Yes, build it" (the logic) and "Keep it, make it real" (the debug check-back). The question
  pages (6.2 to 6.12 and 6.15) name Plan, the Goal line, Done-when checks, the Log, Evidence, the
  logic gate and follow-ups where they named the old phases, sections and gates. No bank says
  "always ask" any more: every question yields to 6.2's drop rule, so what the request,
  `CLAUDE.md` or the code settles is stated with its source instead of asked, and the goal
  question (6.4, Q0) is asked only when the ask reads two ways. The repo brief (6.13) is retired:
  its citers point at the project's own manifest, `CLAUDE.md` or README (the core law's triad),
  and 1.5 points helper briefs at the core law's one line; 101 sections remain. The coverage
  line (the workflow skill, Plan step 4) and the coverage map (6.15) name the same sixteen
  aspects, and a task on the lane's risk list walks the full map per deliverable;
  `tests/coverage-aspects.test.sh` fails when the two drift apart, shown failing before the
  change and on a planted rename. What had gone with the old phases now points at live steps:
  the research bank's build answer hands off to a Build task's Plan and its logic gate; the fix
  bank's bisect waits for the logic gate's yes, and its hotfix fast path gives way to the
  landing question (Verify & Deploy step 6); the debug bank's check-back time works again, as
  10.1's new Check-back time rule: the clock noted as the investigation starts, checked at every
  numbered step, and at the named time a stop, a report and a question (keep going, change
  direction or stop). **What it removes:** the research depth question's time-box and sandbox
  worktree, which nothing ran. Workflow page 15,522 to 15,689 bytes (cap 16,000); core
  law and code rules unchanged.
- **8.0.0**: the old workflow's leftovers go, the first of four cleanup releases. The user:
  "quick and full old skills still have menyions and leftovers" and "check other names too, we
  don't want discrapences in the rules"; of the options, "Yes, build it" (four small releases),
  "Yes, build it" (one name per thing) and "Rename to design-spec". The 21 pages of the old
  six-phase flow go: 0.1 (the map), 4.1 to 4.4 (the old routes and modes), 5.1, 5.2, 5.5 and 5.6
  (the ledger, the goal anchor, the phase agents, the check-in), 6.1, 6.14, 7.1 to 7.3, 8.1,
  8.2, 9.1, 11.1, 11.2, 12.1 and 13.1; 102 sections remain. Every mention of them now names its
  new home (a step of the workflow skill, a helper's own file, the status-report skill), and
  `tests/references.test.sh` fails on a cited section with no page and on a page nothing
  reaches, each shown failing on a planted case; it also caught 5.7's range to the routes
  7.0.0 removed. The design command becomes `/engineering-rules:design-spec`, a rename and so a
  major version, and the workflow page drops its check-in line (the check-in is the user's
  `loop.md` and the status-report skill). **The rules the old pages held with no new home**, by
  the user's choices ("Done-when checks" and all four rules offered): what must not change is
  a Done-when check, one no command can check naming the file to read and what to confirm, and
  a broken one is Critical; no secret, token, credential or customer data in the work-doc or a
  helper's brief; a test run that ran zero tests is a fail; a task branch off the default
  branch, and a worktree only in a folder git ignores; a bug fix starts 10.1's root-cause
  investigation at Plan by reading only, its reproduction and boundary logging waiting for the
  logic gate's yes, since nothing runs before it. **What it removes:** of the 30 rules a read of
  the old pages found missing, whole or in part, from the workflow, its helpers and the law, 10
  already live in pages that stay, some minus a detail, and 1 in the user's `loop.md`; 6 come
  back by the user's picks, 1 whole and 5 in part; and 13 stay out, among them the pause
  checkpoint, the plan's rejected alternatives, the verbatim ask in the work-doc and the
  reviewer's read of each file's untouched neighbour. The
  brainstorm (16.1) hands its distillation to Build's Plan and writes no work-doc, since a
  graduation signal is not the logic gate's yes; the release notes (16.13) read the new
  work-doc, older labels still read, and run on demand only, the Close step printing its own.
  5.7's run points are the three phases' steps. 1.4, 1.7 and 1.8 carry the law's own headings,
  and the citations that leaned on their old titles moved: the re-anchor hook's "(1.7, step 7)"
  now names the workflow skill's ledger, where the re-read rule is written. Old dead code is
  written down, never deleted: 3.0.0's never-chase rule (1.9) retired its removal, but 1.1,
  1.6, 2.1, 3.4, 9.3, 9.5, 12.7, 13.2 (class 10) and 16.13 still sent it to a cleanup commit of
  its own; each now files it as a follow-up with its `file:line` and zero-reference proof, and
  12.7 makes old dead code that a diff removed a finding. Workflow page 15,024 to
  15,522 characters; core law 70 lines, 9,596 to 9,594 characters (the design command's
  name); code rules unchanged at 6,737.
- **7.0.0**: fewer skills, common names. The user: "remove explore feature skill, rename other
  skills to something technically common", "remove agents skill, "skill" creation skill," and
  "move the status report skill to the engineering rules"; of the options, "Yes, build it" and
  "Rename to explain". Removed: `/engineering-rules:explore-feature` with its scripts, page
  template, capture loaders, their six test files and sections 16.9 to 16.11;
  `/engineering-rules:skill` with 16.12; and the helper switch `/engineering-rules:agents` (the
  three helpers stay on, and their work runs in the session only where the agent tool is
  missing). Renamed, folders and every mention with them: `do` to `build`, `shape` to
  `brainstorm`, `design` to `design-system`, `log` to `release-notes`, `demystify` to `explain`,
  and the workflow skill `engineering-rules:engineering-rules` to `engineering-rules:workflow`;
  `audit`, `triage` and `update-engineering-rules` keep their names. The workflow's description
  no longer lists its route words, so it starts only when the user names the engineering-rules
  workflow or types one of its commands, never on an everyday word like build or audit.
  `status-report` moves into `skills/status-report/` word for word under its own name, so
  `/status-report` still answers, and the uninstall now takes it out with the rest. **What it
  removes:** a feature page with every cited line checked against the tree, the switch that
  kept helpers off for a conversation, and the route that checked a new skill's structure (the
  skill-creator plugin still makes skills). Fixed on the way: the README's hooks table, broken
  by the blank line 5.0.0 left where the file-cap row was. Core law 70 lines, 9,639 to 9,596
  characters (the gate's skill name and the routes line); code rules unchanged at 6,737.
- **6.0.0**: the lite workflow. The user: "merge quick mode with full mode into default one i
  need only 3 phases plan, implement, verify&deploy. and skip any phase if it was done
  previously or when you have full context to avoid reworking things. i want lite version with
  the same power of original one", then "focus also on development speed". One default route,
  `/engineering-rules:do`, runs three phases (Plan, Implement, Verify & Deploy) and skips a
  phase that a resumed work-doc or the user's own words already cover, never the logic-first
  gate; `/engineering-rules:quick` and `:full` are removed, which makes this a major version.
  The workflow page is 15,402 characters, from 35,819, with a slim work-doc written once after
  the user's yes and a ten-row self-audit. Plan runs `scripts/lane.sh`, which gives the fast
  lane only on checkable facts (a test command, at most 3 code files, no risky kind of file, a
  test with the code) plus one honest plan line (no money, auth, state machine, migration,
  concurrency or data-loss code, no deploy); anything else is the careful lane. Implement runs
  `scripts/scout.sh`: the perf (9.4, its tables turned into commands by
  `scripts/perf-scout.sh`), law (9.5) and design (15.29) scouts over the working tree against a
  base, every row tagged introduced or present at base, each scout first proven on a planted hit.
  Three capped helpers (`er-reader`, `er-builder`, `er-reviewer`) replace the per-phase agents,
  and `install.sh` links them into `~/.claude/agents/`. Every row of the old checklists keeps a
  home (`tests/workflow-power.test.sh`). **The places it checks less, by the user's choices,
  each with the protection it removes:** a fast-lane change is reviewed in the session from the
  reviewer's checklist, not by the separate reviewer (a mistake the session cannot see in its
  own work is not caught by fresh eyes); the reviewer takes the session's proven Evidence lines
  without re-running them and has 10 turns, from 20 (a wrong Evidence line is not re-checked);
  the intent is confirmed first only when the ask reads two ways (a misread single reading
  surfaces at the logic gate instead); the spec review becomes the advisor's plan check (no
  separate reviewer reads the plan); the landing menu appears only when there is a choice; and
  2.2 and 11.3 are read only when a step needs them (placement or ship-gate detail is not
  re-read on a task that creates no file or has no build target). Shipped without the timing
  runs or a live end-to-end run, by the user's choice ("skip tests"): the speed gain is
  unmeasured, and the last full run was of an earlier build. Core law 70 lines, 9,580 to
  9,639 characters (the routes line); code rules unchanged at 6,737.
- **5.0.0**: the two line caps are gone. The user: "i want to remove the lines cap rules", and
  of the options, "the two code caps": 40 lines per function and 500 lines per file. Both law
  files drop them (the 3-parameter and 3-level nesting caps stay), and so do the 1.1 long form,
  the file-cap hook (unwired and deleted in one step, since Claude Code's docs and this setup's
  own install show settings hooks reload in running sessions), the law scout's `cap.file-lines`
  row (9.5, so the edit guard and scout.sh no longer report it), the audit's `cap.file-lines`
  and `cap.fn-lines` rows with their scanner flag, carve-outs, judgment check, report
  placeholders and porting notes (16.3 to 16.8), the review's length checks (12.7) and the
  repository's own cap test (`tests/hook-caps.test.sh`). The skill-page and explore-feature
  template limits stay, by the user's choice. **The protection removed:** nothing measures or
  flags the length of a function or a file any more, so either can grow unchecked; one thing
  per file and the clean-code floor still push toward small units. The removed wording is on
  `tests/fixtures/short-law-absent.txt`, so it cannot come back unseen. The hackify
  `lawkeeper` plugin, outside this repository, still enforces the old caps. Core law 70 lines,
  9,620 to 9,580 characters; code rules 48 lines, 6,813 to 6,737.
- **4.2.0**: the logic-first gate is cued on every prompt. A timing run gave a plain session a
  fully specified ask ("the intent is exactly this and fixed ... commit on the current branch
  when done") in a real project; it planned, built, tested and committed without explaining or
  asking, and its reasoning never named the gate, while it did follow the advisor rule, the one
  a hook repeats on every prompt (one run, cause not proven). The advisor cue now opens with the
  gate: explain with `demystify` and wait for the user's yes, and a detailed or fixed ask, or one
  that says to commit when done, is not a yes. The core law's gate says the same and that only
  the user's own words can skip it, for one task (two pins). The cue grows from 623 to 881 bytes
  (about 60 tokens a prompt, the cost the user approved), so its cap in
  `hooks/tests/advisor-cue.test.sh` goes from 700 to 900 bytes. Shipped without live proof runs,
  by the user's choice ("skip tests"): the local suite is green and the installed hook prints
  the new cue, but no fresh session was run to show the gate now holds on such an ask. Core law
  70 lines, 9,546 to 9,620 characters; code rules unchanged.
- **4.1.0**: the explain step reads, and runs nothing. Two fresh sessions on a one-line isEven ran
  node experiments before explaining and took 233 s and 348 s to reach the question; the user
  chose "explain from reading only". `demystify` now reads files, searches and `git` history
  only until the yes: nothing is run to try an idea (no scratch code, no experiments, no test
  runs). `tests/demystify.test.sh` pins the skill's shape (the problem, what I'd build, the
  effect, the risks, the ask, nothing built before a yes, never about tests, reviews or specs)
  and the new rule. Law files unchanged.
- **4.0.0**: logic first, and `demystify` replaces `generate-pseudocode`. The user: "before start
  working on a new task. to explain in short the business logic that will be implemented ...
  (law, hard gate, mandatory)", in the shape "SHORT, pseudocode representation, plain words
  explaination ... the main implementation idea, what effect it will add to the code, if
  there're risks", and "the new skill replaces the plugin:pseudocode skill entirely since they
  both fix the same problem". The core law's 1.4 gains a hard gate: before changing anything for
  a new substantive task, explain it short (the problem, what you'd build in pseudocode, its
  effect, the risks; no tests, reviews or specs) and get a yes through `AskUserQuestion`; nothing
  changes before it, a changed logic asks again, a helper builds only confirmed logic, and only
  the user can skip it, for one task. The new `engineering-rules:demystify` skill, which the
  model can invoke, carries that shape with a neutral example, and a second mode explains
  existing code the same way. `/engineering-rules:generate-pseudocode` is removed with its page
  kit, worked example and scripts; the published full-page walkthrough, every helper expanded
  with `file:line` notes, goes with it (ask `demystify` for more depth instead), which makes this
  a major version. Six new pins hold the gate's wording. Core law 69 to 70 lines and 9,130 to
  9,546 characters; code rules unchanged at 48 lines and 6,813.
- **3.0.0**: no plugin. The law now binds every session from the user-global `CLAUDE.md`, with
  nothing to call. The always-on law is two short files. `law/engineering-law.md`, the core
  (definitions, precedence, the caps and bans in one line, 1.2, 1.4, 1.5, 1.7 to 1.11; capped
  at 90 lines and 10,000 characters), is imported by a managed `CLAUDE.md` block and measured
  3,144 tokens a message. `law/engineering-code.md`, 1.1, 1.3 and 1.6 in full (capped at 60
  lines and 7,500 characters, about 2,414 tokens), is copied by `install.sh` into
  `~/.claude/rules/`, where its `paths:` globs make Claude Code load it the first time a code
  file is read; a session that reads no code never pays for it. The first one-file short law
  measured 6,756 tokens a message. Two pin lists in `tests/short-law.test.sh` hold every cap,
  ban, guardrail, git rule, banned phrase and deploy proof the two files must keep. The plugin's long always-on text moved to
  `references/01-always-on-law/` as long forms the short one wins over. The phase workflow no
  longer loads on its own whenever code is touched; it runs when the user calls it by name or
  through a route, and every command keeps its plugin-era name through its skill's `name:`
  line. `install.sh` wires the folder in: a link home, one link per skill, the `CLAUDE.md`
  block, the copy of the code rules (refusing a file there it did not write), the hooks and the
  status line merged into `settings.json` from `settings/hooks.json`, and the plugin switched
  off; it checks before it changes, backs each file up to a folder of
  its own, keeps permissions and links, runs twice with no change, and `--uninstall` puts back
  what it replaced. The hooks find the repository through `ENGINEERING_RULES_HOME` or their own
  path instead of the plugin root. **Never chase what you find on the way** (1.9): a bug, a
  failing check, a law break, dead code or a smell noticed while working is written down with
  its `file:line` and handed back, never fixed in the task; a serious find is told at once and
  still not fixed; a check already red at the base commit is filed while a red check still
  stops a deploy; only the diff's own breakage and a true blocker are fixed on the way, and the
  rule names the reasons that do not count. That retires the standing removal of old dead code
  in touched files, and a defect's family is fixed only where the goal names it; the file cap
  hook names a file already over the cap at the last commit as a follow-up, once per session,
  instead of asking for a split. The re-anchor hook and the status line read the ledger
  position only from Claude's own reply text, so a heading quoted in a file or a tool result no
  longer reports a workflow in flight and asks for a full re-read. `/update-engineering-rules`
  changes these rules and ships the change: the ethics (the user's words are the
  specification, nothing loosened quietly or lost by accident, both law files' sizes reported,
  one source of truth) and a release that tests in a worktree, merges, installs, verifies in a
  fresh session, commits and pushes. The plugin packaging (`.claude-plugin/`), its evals and
  its docs are gone. Major, because the packaging changed, a standing rule was retired and the
  workflow no longer loads on its own.

- **2.21.0**: a second opinion at every decision. Claude Code's `advisor` tool is a model the
  user pairs with the one that is running, at least as capable, which reads the whole
  conversation and answers with guidance; until now nothing in this law mentioned it, so a
  session that had one consulted it whenever it felt like it. `1.4` now carries the rule, a
  bullet beside the wizard tool's: before an approach or a plan is committed to, before the
  options put to the user are ranked, before a review or a root cause is acted on, before a
  change of direction, before anything hard to undo, and before anything is called done, the
  decision, the options and the evidence are stated and the advisor is called. **The test is
  the tool list, never the model.** The strongest model gets a second opinion exactly as the
  smallest one does, because the pairing is the user's decision and a context that wants its
  own plan to be right is the same context whichever model runs it.
  **What comes back is a report, never proof** (`1.5`). The user's words, the anchor, this law
  and fresh evidence all outrank it, a clash is said in one line rather than followed, and it
  never stands in for the reviewer or the spec reviewer, which are sent precisely because they
  have not read this conversation. It never answers a question that is the user's, and it never
  settles a fact one command would settle (`1.10`).
  **A session with no advisor loses the call, not the step.** The decision is still stated with
  its options and its evidence; the ledger line records `Advisor: none in this session`, and a
  verdict written for a call that was not made is a false tick under `1.5`.
  The new `5.7` carries the protocol: nine run points keyed to the phase files, the four moments
  that bind on every route and outside any phase, how the call is set up (the tool takes no
  input, so what is on the page before it is the question), what the answer is worth, the
  `advisor:` verdict that rides each tick and the reflection in `5.1`, and eight
  anti-rationalizations. `6.1`, `7.1`, `8.1`, `9.1`, `10.1`, `11.1`, `12.1` and `13.1` each
  carry their run point; the four prompts in `5.5` whose shape decides something, the planner,
  the spec reviewer, the reviewer and the builder, carry the same sentence word for word, and
  the mechanic and the reader, which decide nothing, carry none. `1.7`'s self-audit grows a
  nineteenth row.
  **And the rule reaches a session that never loads the skill.** `hooks/advisor-cue.sh` is wired
  to `UserPromptSubmit`, the event that fires on every prompt and takes no matcher, and prints
  the rule in short into the turn. It judges nothing and refuses nothing: a hook cannot see a
  tool list, so it can neither know whether an advisor is there nor tell a decision from a
  greeting, and a refusal built on that guess would block work. `tests/advisor-wiring.test.sh`
  holds all of it in place, both ways, and `tests/hooks-wiring.test.sh` now expects nine events
  and no matcher on the prompt hook.
- **2.20.0**: both work-doc gates come out, and the planner checks its own file. Full mode no
  longer stops for a plan sign-off: `7.1` step 5 is now *say what you are about to build*, a
  statement in chat with the path, the link and what is deliberately not being done, and the
  work starts on it. What still reaches the user is a real fork, asked as one question the
  moment it appears: a decision the planner brought back, or a spec-review finding that moves
  the anchor (`8.1`). `hooks/work-doc-gate.sh` is deleted, unwired and its fixture test with
  it; nothing at the tool boundary reads the work-doc any more. The doc stays the map the work
  follows (`1.4`, `7.3`), held by the session keeping it current at every tick and every
  check-in rather than by a refusal. The ledger's second item, the exit artifact in `5.1`, the
  template's ledger block and its `### Gate` entry, `0.1`, `4.2`, `4.3`, `4.4`, `6.1`, `6.2`,
  `5.5`, the `full` sub-command, the README and both manifests all follow; `7.1` is renamed
  `7.1-phase-2-plan.md`.
  **The planner now audits what it wrote.** Before it returns, it re-reads the file from disk
  and fixes what it finds, in three passes: the shape (every template heading present, spelled
  and ordered the template's way, nothing renumbered), the plan against itself (a criterion no
  task covers, a task no criterion needs, a task serving a Non-Goal, two tasks writing one
  file, a stage needing what a later stage builds, a `→ verify:` line that cannot fail, a
  citation it never opened, an answer from the Q&A contradicted), and ledger and task state
  (ten items, Phase 2 the only one open, every task unticked and unstarted, `current_task`
  null, `status: planning`). It reports `doc check: clean` or says what the second pass
  changed.
  **And the contradiction that made all this necessary:** `7.1` told the planner to write
  `Primary Goal & Guardrails` as section 2 and to end at a section 9, while the template in
  `7.2` leaves that heading unnumbered and ends at 8, so every number after it was one too
  high and `6.13`, `5.2` and `7.2`'s own conformance list cited the other scheme. `7.1` now
  carries a table of the template's real headings, the planner prompt names headings instead
  of counting, and `tests/work-doc-sections.test.sh` compares all three heading by heading, so
  the law can no longer disagree with itself about its own document.
- **2.19.0**: the plan phase's agent writes the work-doc itself. Phase 2 used to send a
  read-only `Plan` agent, take its plan back as a report and re-type it here; the context that
  had just run the clarify round was the one writing the plan down, and the agent's fresh eyes
  reached the page only through it. The planner is now a fresh `general-purpose` agent on
  `opus` that creates `docs/work/<YYYY-MM-DD>-<slug>.md` from the template (`7.2`) and fills
  it: the ask, the anchor and the Q&A copied verbatim out of its brief, then the acceptance
  criteria, the approach with its rejected alternatives and the sprint backlog. It may write
  that one path and nothing else, it never publishes, and when shaping (`16.1`) already made
  the file it edits it in place, leaving the frontmatter, the phase ledger and the Shaping
  Provenance block untouched. The root cause of Phase 3b stays a `Plan` agent on `opus`,
  read-only by construction, because implementation is open and the tree is full of
  half-finished work. `7.1` is rebuilt around the change: step 1 sends the planner, step 2 is
  the read-back that replaces the transcription (one changed path in `git status --porcelain`
  and it is the work-doc; the template's shape; the ask, anchor and Q&A verbatim; every
  citation opened; every criterion covered by a task that names its files and its verify line;
  nothing serving a Non-Goal), step 3 publishes, and the gate follows. The publish, the ledger,
  the gate and every later edit stay in this session. `1.8`'s map, `5.5`'s shapes table,
  runtime table and planner prompt, `7.2`, `7.3`, `8.1`, `10.1`, `16.1` and the README all say
  it in one voice, and `tests/planner-writes.test.sh` (17 checks) fails if any of them drifts
  back.
- **2.18.0**: the work-doc becomes a hard gate. In full mode the doc is the only map: the
  phase its ledger shows open is the phase you are in, the task its Sprint Backlog lists next
  is the task you take, a reorder is an edit to the doc with its reason, and every tick is
  written as it lands. `hooks/work-doc-gate.sh` holds that at the tool boundary. While a live
  work-doc sits under `docs/work/`, a `PreToolUse` on the edit tools refuses an edit to a code
  or test file when the doc disagrees: no phase in progress, two phases in progress, an open
  phase that does not write code (code lands in Phase 3, 3b, the Phase 5 fix pass and the
  Phase 6 cleanup), a task started while an earlier one still waits, a task ticked with no
  `###` entry under Daily Updates, a doc with no phase ledger or no backlog, or two live
  work-docs at once. Parallel stages still pass, because several tasks may run at once as
  long as they are the ones at the front (5.5). Prose and generated files are never gated, so
  the work-doc, the README and every document stay editable at any moment, and the way
  through the gate is to bring the doc up to date. A task with no live work-doc, which is
  quick mode or a trivial ask, is not gated at all. `SKILL.md` 1.4 carries the map sentence,
  `7.3` the rules and the gate's contract, and `9.1` opens each task in the doc before its
  first edit. `hooks/tests/work-doc-gate.test.sh` covers nine cases on fixtures.
- **2.17.0**: every phase becomes an agent on a named model, and that is the default. `1.8`
  is now a map, one row per run point: the question batch and the scouts to a `fork`, which
  runs on the session's own model; a wide search to an `Explore` agent on `sonnet`; the draft
  plan (`7.1`) and the root cause (`10.1`) to a `Plan` agent on `opus`; the spec review to a
  `Plan` agent on `opus`; each implementation stage and every fix pass to a `general-purpose`
  agent on `sonnet`; the counts, proofs and sweep scans to a `general-purpose` agent on
  `sonnet`; the five review checks to a `general-purpose` agent on `opus`. The model is named
  on every send but a fork, which cannot take one, reversing 2.7.1's "no send names a model".
  `5.5` grows from four shapes to six, with a new planner prompt for the plan and the root
  cause, and its brief now pastes `1.9` and `1.10` under every shape's prompt. Agentless
  becomes the opt-out: `/engineering-rules:agents off` for the conversation, bare to switch
  back, with the cost said once. Three always-on laws arrive. `1.9`, one goal: a task ends
  when its goal is delivered and verified, and every pre-existing defect or law break found on
  the way is written down as a follow-up with its `file:line` and fixed in a task of its own,
  never in this one; the four carve-outs are your own diff's leftovers, dead code in a touched
  file, a defect that genuinely blocks the goal and a Critical finding against this diff. The
  follow-ups get a `## Follow-ups` section in the work-doc (`7.2`) and a "What I left for
  later" block in the update log (`16.13`). `1.10`, quick, never lazy, never approximate:
  independent calls in one message, whole files read, every detail of the ask a requirement,
  no fact guessed that a command would settle, and it binds every agent through the brief.
  `1.11`, shipping: small verified releases behind their own switch, six proof rows before any
  deploy and a live verify after. `5.6` adds the ten-minute check-in, work-doc first, then a
  three-line brief and the drift check. The self-audit grows to eighteen rows. A ninth suite,
  `tests/agent-map.test.sh`, keeps the map honest across `SKILL.md` and `5.5` and proves it
  fails on a planted drift; the `agentless-default` eval becomes `agents-default`, and a new
  `agentless-switch` case covers the other direction.
- **2.16.1**: the context bar becomes a labelled percentage, `ctx:42%`, written and coloured
  like the usage windows (green, yellow from 50, red from 75), so the meters row reads as
  one set of labelled numbers. The context meter and both usage windows share one
  formatter, `format_meter`. `hooks/tests/statusline.test.sh` checks the label, the
  rounding, the colour, a value that is not a number, and that no bar is drawn.
- **2.16.0**: the status line prints two rows and gains two meters. The first row says where
  you are (directory, git, model, ledger position); the second holds the meters (context
  bar, uptime and the two new ones) and is left out while all are empty. `5h:24% 7d:61%` is
  the claude.ai plan's rolling five-hour and weekly windows from `rate_limits` in the
  status-line JSON, each shown only when Claude Code sends it and coloured like the context
  bar. `compacted 2x (1 auto)` counts the `compact_boundary` lines Claude Code writes into
  the transcript and stays hidden until the first; it keeps its own cursor beside the
  ledger's, reads only the whole lines added since the last render and waits while a line is
  still being written, so no compaction is counted twice. Both scans now reach their offset
  through `dd`, because `tail -c +N` took close to two seconds on a 70 MB transcript on
  macOS; the first render of that transcript went from 1.9 s to 0.8 s with the new scan
  included. `hooks/tests/statusline.test.sh` covers the rows, the two windows, one window
  alone, the colour, the count across appends, a quoted marker, a half-written line, a
  replaced transcript and a broken cursor file, on macOS and on Debian.
- **2.15.0**: a second skill ships beside the law. `skills/generate-pseudocode/` turns
  "explain how this code flow works" into one published page of complete pseudocode: every
  routine read from source in the session and every helper expanded down to the SQL or the
  external call, `file:line` beside each, shaded phrases that open a note on why a line is
  the way it is, an up-link on every routine and a return button after any jump, light and
  dark themes, and a closing analysis in three groups (what differs, what to know before
  changing anything, suggestions), each finding resting on a linked line. A question whose
  answer is one routine is answered in chat in the same conventions. The skill triggers on
  its own description or by `/engineering-rules:generate-pseudocode`; its page kit, a worked
  example, `check-page.sh` (links, notes, the theme blocks, the mechanics against the kit,
  the script parse) and `serve.sh` sit beside it. `tests/sub-commands.test.sh` now allows a
  listed standalone skill and checks its shape. Built with skill-creator against three
  prompts: with the skill 24 of 26 checks pass, without it 9.
- **2.14.0**: the explore-feature page carries one real run. `capture-run.sh --test <the
  project's own test command>`, or `--live <its start command>` and `--stop` once the user
  has fired a request, runs the code under a load-time rewrite (a Bun preload and a Node
  `--import` hook under `skills/explore-feature/capture/`, both over the same rewriter, which
  uses the explored repo's own `typescript` 5, or the one `EXPLORE_CAPTURE_TYPESCRIPT` names
  when the repo carries 7, which has no compiler API) that wraps every function inside a hop's excerpt
  and records the arguments in, the value out or the error thrown, the time, and which way
  each `if`, ternary and `switch` went; secrets, emails, phone numbers, tokens and the tickets
  inside URLs are masked and every value capped before a byte reaches disk. The runner aggregates the events
  (`capture-aggregate.jq`), scans them (`secret-scan.sh`, the `9.5` block, now the one place
  it runs for the builder too) and verifies them against the trace (`capture-verify.jq`)
  before writing `capture.json`, the contract in `16.10`; `build-page.sh --capture` runs both
  checks again and embeds it. The page gains a Runtime tab, a block under each excerpt, a
  chip on every function and branch line, and timings on the sequence arrows, all labelled
  as one run and absent without a capture. `16.9` step 6b runs it (the project's test by
  default, a live request on the user's word) and the handoff gains `Captured:`; `16.11`
  says a captured value is an observation, never the contract, and its gate gains a row.
  Nothing is written into the explored repository. Three suites follow:
  `capture/tests/rewrite.test.sh` (the rewriter and the sink over a sample file),
  `scripts/tests/capture-run.test.sh` (the runner over a Bun fixture and its Node twin: test
  mode, `bun test`, the override, the two refusals, live mode) and the `--capture` cases in
  the builder and template guards.
- **2.13.1**: the grey lines explain themselves, the verifier holds the line for weaker
  models, and the switch is `agents`. A dimmed excerpt line now sits on a grey band with a
  dotted rail and a tooltip, its excerpt header counts the lines not on this path, and the
  help overlay has a legend for the entry line, a skipped line and a comment.
  `verify-trace.sh` refuses an `invoked` list that leaves out the hop's own line or a child's
  call line, or that names a blank or comment-only line, and prints a note when no hop dims
  at all, so a trace from a weaker model cannot ship inconsistent dimming; `16.9`, `16.10`
  and `16.11` say the rules before the tool does. `/engineering-rules:helpers` is renamed
  `/engineering-rules:agents`, the word a user reads as "send subagents"; agentless stays the
  default and `agents off` goes back to it.
- **2.13.0**: the walkthrough route becomes `explore-feature`, and its output becomes a
  verified page. `/engineering-rules:explore-feature <entry point>` walks one entry to its
  leaves and writes `trace.json` to the v2 contract in `16.10`;
  `skills/explore-feature/scripts/verify-trace.sh` refuses any citation the working tree
  disagrees with (eleven checks, the structural ones in `verify-trace.jq`) before writing
  `excerpts.json` with every line copied by `sed`; `build-page.sh` refuses an excerpt carrying a
  hardcoded secret (the `9.5` patterns, the value never printed) and inlines the template under
  `assets/` into one self-contained page (the call stack, diff-style excerpts with hop
  badges, a clickable sequence diagram, steps, branches, the failure path, shapes, decisions
  and a quiz, all keyed to one selected hop, syntax-highlighted, in GitHub's light and dark palettes with a theme switch) that is published through the
  artifact tool and never written into the explored repository. `16.9` is the route, `16.11`
  the code-only rubric with its gate: the explored repo's docs are a map, never a source.
  Playbook mode, note merging and the `.walkthrough/` viewer are gone. Two script tests on a
  sample-repo fixture, a page-template guard, the caps test over the skills' scripts and
  the cross-references in `4.1`, `4.4`, `5.1`, `6.2`, `13.1`, `13.2`, `0.1`, the README, the
  manifests and the full-mode eval grader follow.
  The defaults flip: full mode and agentless are the defaults for every substantive prompt;
  quick mode and helpers are what the user names, by `/engineering-rules:quick`,
  `/engineering-rules:helpers` (the renamed agentless switch: bare switches helpers on, `off`
  back to agentless) or their own words. `4.2` and `4.3` swap their subtitles, the eval
  `agentless-quick` becomes `agentless-default`, and `1.7`, `1.8`, `4.1`, `4.4`, `5.1` and
  `16.1` say the same thing.
- **2.12.1**: the gaps a sweep of 2.12.0 found. The bold "never in this session" lines of
  `8.1` and `12.1` name agentless mode as their one exception and `12.1`'s intro reads the
  check files here under it too; `16.1`'s build-verb veto does not apply to a prompt typed
  after `/engineering-rules:shape`; `1.8` says the user's word holds for the conversation;
  the README's helper-shapes section says none is sent in agentless mode; and the
  route-picker grader is named for the intake it checks.
- **2.12.0**: agentless is a sub-command, not a token. `/engineering-rules:agentless` switches
  the mode on for the task in flight and every task that starts in the conversation, until
  `/engineering-rules:agentless off`; with a request after it, the request classifies as
  prose and starts agentless. The nine route sub-commands take no mode token any more (no
  `arguments` list, no `$mode` line), the intake skips its helper question when the switch
  is already on, and `4.4`, `4.1`, `SKILL.md`, the test and the `agentless-quick` eval say so.
- **2.11.0**: the route parameter becomes nine sub-commands, the bare invocation becomes an
  intake, and agentless mode arrives. `skills/quick`, `full`, `shape`, `walkthrough`,
  `audit`, `triage`, `skill`, `design` and `log` each hold a short skill only the user can
  invoke (`disable-model-invocation: true`), which loads the law, picks its row outright and
  hands over the request; `SKILL.md` drops `arguments: [route]` and the `$route` line, and
  `/engineering-rules:engineering-rules <request>` classifies the request as prose. Typed
  bare, the skill walks the user through the options through the wizard tool (what they are
  here for, which route, helpers or agentless, the request) and starts only when all three
  are settled; the old picker asked for nine options in one question, which the wizard tool
  cannot hold. Agentless mode, by an `agentless` first word, the user's own words or the
  intake, keeps every helper shape in the session: a third helper line in `1.8` and `5.1`,
  every mandatory send done here in the same order, the one-line cost at task start, all
  written up in a new `4.4`, with `4.1`, `4.2`, `4.3`, `5.5`, `6.1`, `8.1`, `9.1`, `12.1` and
  the seven route sections pointing at it. `tests/sub-commands.test.sh` keeps the route
  table and the skill directories in step; two eval cases, `sub-command-full` and
  `agentless-quick`, state the promise.
- **2.10.0**: every built-in agent type is employed, and the builder reads what binds it.
  The spec review of Phase 2.5 moves out of the context that wrote the plan into a fresh
  `Plan` agent, read-only by construction, with its own prompt block in `5.5`; `8.1` sends
  it, `8.2` returns the execution order for the session to write, and it is a mandatory
  send in `1.8`. The builder prompt no longer says `2.2` and `9.2` "bind you" and leaves
  it there: the Skill tool loads `SKILL.md` alone, so the builder now reads `2.2` before
  creating or moving a file, `9.2` before writing a test and `14.1` when an approach feels
  grand, at paths the brief carries, and a file placed or a test written without them is a
  finding.
- **2.9.0**: the clarify round is hardened into a senior product owner's. A new `6.15`,
  the end-to-end coverage map: sixteen aspects (value, actors, entry points, inputs, the
  happy path, states, data, failure paths, integrations, security, volume, observability,
  rollout, surfaces, tests, operations) walked per deliverable, each `pinned:<source>`,
  `asked:Q<n>` or `n/a:<reason>`, printed with the restatement, and Phase 1 does not close
  on a hole. `6.4` gains Q0, the intent restatement (outcome, for whom, why now, done,
  excluded, the interpretations weighed) confirmed by the user before any domain question,
  plus an `Assuming:` list with a source per line. Every question carries `traces-to` (a
  deliverable or requirement, or it is cut) and `cost-of-guessing` (the costliest fork is
  asked first). The anchor's goal gains a value line and In-Scope is written as
  deliverables (`5.2`). A `Suggestions:` block brings the options the user did not ask for,
  each with its evidence tier (`6.2`). Always-on: a **Product owner** hat (`1.2`, `5.4`) and
  **Memory is a hypothesis** (`1.5`): nothing about a library, API, tool, version or
  platform is a fact until verified this session in the lockfile, the installed source, its
  help or docs fetched now; the repo brief gets an Externals row (`6.13`), the investigation
  method a go-and-read step (`6.14`), and the self-audit a fourteenth line.
- **2.8.0**: the law leaves nothing behind. `1.1` gains a "leave nothing behind" principle
  and "DRY, with the search shown": every new symbol carries the pasted search that found no
  existing equivalent. The leftover sweep moves from the finish to every stage end (`9.1`,
  `9.3`), and dead code runs both directions: what the diff added with no caller, and what it
  orphaned by removing the last caller, import or reference. Dead code that was already in a
  touched file is removed by default in its own `chore(<scope>): remove dead code in touched
  files` commit, with a zero-reference proof per symbol, the looks-dead-but-may-not-be
  guardrails in `13.2` class 10, one `git revert` as the veto, and the commit named in the
  update log (`16.13`); `1.6`, `2.1` and `3.4` carry the exception. `12.7` names leftovers and
  the reuse search explicitly, `9.5` hands it a leftovers lens, the builder prompt in `5.5`
  searches before it adds and sweeps before it returns, and the self-audit asks.
- **2.7.1**: every helper runs on the session's model. The mechanic's `haiku` pin is gone,
  and with it "the cheapest model" and "no weaker than" from `1.8`, `5.5` and the README: no
  send names a `model`, a fork runs on the session's model by construction and a fresh type
  inherits it, so the reviewer, the mechanic, a builder and a reader are all the model the
  user is talking to. A runtime default that would hand helpers a different model is
  overridden by naming the session's model on the send.
- **2.7.0**: the shipped agents are gone. `agents/` (`law-reviewer`, `law-mechanic`,
  `law-builder`) is removed, and the four helper shapes run on the agent types Claude Code
  ships itself: `fork` for a reader that needs the conversation, `Explore` for a wide
  read-only search, `general-purpose` for the reviewer, the mechanic (on `haiku`) and a
  builder. `5.5` now carries each shape's prompt, the former agent bodies plus a reader
  block, pasted whole on every fresh send, so a built-in type is bound exactly as the shipped
  agent was; the session checks `git status --porcelain` after a reviewer or a mechanic
  returns. The agent-tool definition, `12.1` and the manifests name the built-in types; the
  notifier's fixture test logs a `general-purpose` helper.
- **2.6.0**: the git guard is gone. The `PreToolUse` hook on `Bash` that refused the git
  commands `1.7` bans and prompted on the waivable ones is removed with its fixture test, and
  `1.7` no longer says a hook stands behind it; the git safety law itself is unchanged and
  still binds every session through the skill. `tests/hooks-wiring.test.sh` now fails when a
  hook reaches the `Bash` tool. The `git-safety` eval stays, since its graders accept an
  explicit refusal with no hook behind it.
- **2.5.1**: the law scout's path helper in `9.5` matches a glob without a slash against the
  file name alone, and the one slash glob that named a file shape (`*/test_*`) is gone, so a
  directory named like a test file (`pkg.test.util/`, `src/test_utils/`) no longer makes
  every file under it a test file, which had applied the test-only rows to real code and
  invited the test-file waivers on it; the same helper serves the domain, scoped and
  non-null rows, which now read a file name where they always meant one.
  `tests/law-scout.test.sh` plants both look-alike directories, and the edit guard's test
  pins its test globs to the scout's. Re-run any scout table built over a tree with such a
  directory.
- **2.5.0**: the law meets Claude Code's runtime. Four new hooks: a git guard on every
  `Bash` call that refuses the commands `1.7` bans and prompts on the waivable ones; an edit
  guard on the four edit tools that runs `9.5`'s block over the edit and refuses an added
  banned token under nine rule ids, with the law's own exemptions; a file cap that reports a
  file over 500 lines as it is written; a re-anchor that puts the re-read instruction and the
  last ledger position into a compacted or resumed session. The notifier gains `StopFailure`,
  `SubagentStart` and `SubagentStop`. Three agents ship (`law-reviewer`, `law-mechanic`,
  `law-builder`) and `5.5`, `12.1` and the agent-tool definition name them; `7.1` and `13.2`
  name the worktree tools; `9.5` says which rows are enforced at write time and learns shell's
  `shellcheck disable`; `1.1` and `1.7` say that a guard's refusal is the law speaking and
  never an obstacle to route around. Three eval cases under `evals/`. Tests: one fixture test
  per hook script, `tests/hooks-wiring.test.sh`, `tests/hook-caps.test.sh`, and every test
  now shares `tests/harness.sh`.
- **2.4.0**: group 15 grows from nineteen to thirty-one sections, folding in the design read
  and the three dials (`15.20`), the design-system map (`15.21`), the page composition law
  (`15.22`), the copy and imagery law (`15.23`), the AI-tell catalog with stable
  `tell.<area>.<slug>` ids (`15.24`), motion discipline and recipes (`15.25`), implementation
  guardrails (`15.26`), the pattern vocabulary (`15.27`), the redesign protocol (`15.28`), a
  third scout keyed to the tell ids (`15.29`), the design pre-flight (`15.30`) and image-first
  and brand work (`15.31`). `15.1` carries the expanded bans and musts, the twelve profiles
  carry a default dial triple and three new anti-tells, `15.3` gains optional `dials` and
  `system` blocks and a thirteenth validation item, `12.5` re-judges the scout's rows and
  re-runs the pre-flight, and `SKILL.md`, `0.1`, `2.2`, `4.2`, `4.3`, `5.1`, `5.4`, `5.5`,
  `6.1`, `6.6`, `6.9`, `6.13`, `7.1`, `7.2`, `9.1`, `9.3`, `12.1`, `13.2` and `16.13` are
  aligned to it: three scouts where they said two, the read and the dials in the clarify
  step and the work-doc, the block library in the folder law, placeholder image slots in
  the cleanup sweep and the update log. `tests/design-scout.test.sh` is new and
  `tests/catalog-ids.test.sh` checks the `tell` family.
- **2.2.0**: the clean-code catalog (`3.4`) is new, 99 judged rows with stable
  `style.<domain>.<slug>` ids across naming, functions, comments, structure, objects, error
  handling, boundaries, classes, async and test hygiene, plus the community rules this law
  deliberately does not adopt; `2.1` is extended to match and `SKILL.md` 1.1 carries its
  ten-line floor. The always-on bans grew by focused or unticketed skipped tests, debug
  artifacts and coverage-ignore markers, and the test-file exception was narrowed to the one
  1.1 names. The law scout (`9.5`) now catches the suppression siblings (`oxlint`, `deno`,
  `tslint`, `stylelint`, Flow, Sonar, JetBrains), comment-only and multi-line empty catches
  and the promise `.catch(() => {})`, `throw` without `new`, thrown literals and
  `reject(new Error(`, the cross-language analogs, owner-aware debt markers, and redacts every
  secret it finds; inline types are scanned in the five scoped roles only, `console.*` in the
  domain roles only, focused tests in test files only, where a test file is now named by
  every language's convention (`_test.go`, `_spec.rb`, `test_*.py`, a `src/test/` tree), and
  the non-null `!` only where the language has the operator; every line the scout prints
  starts with its rule id. `16.4`, `16.5`, `16.6`, `16.7`,
  `16.3`, `16.2`, `13.1`, `13.2`, `12.7`, `11.2` and `9.3` follow, and
  `tests/catalog-ids.test.sh` is new.
- **2.1.1**: the law scout's shell block in `9.5` carried raw control bytes where `\n`, `\0`
  and `\b` were typed, so in 2.0.1 and 2.1.0 every construct-ban row came back empty and the
  readable count read zero without scanning; re-run any table built from it. The path list is
  now NUL-separated at the source (`git diff -z`), a list built without `-z` is refused, the
  readable count no longer runs a shell per path, `9.4` takes the same list, the three
  word-boundary patterns are POSIX ERE, and `tests/no-control-bytes.test.sh` and
  `tests/law-scout.test.sh` guard the plugin's files and the block itself.
- **2.1.0**: the file and folder law (`2.2`) now puts every file of a feature in a role
  folder (`services/`, `types/`, `tests/` and the rest) and refuses the flat feature
  folder; `2.1`, the always-on law in `SKILL.md` and the review-triage example in `16.2`
  were aligned to it. `5.5` (delegation) is new: what stays in this session and what goes
  to a helper, with the always-on Helpers rule, `0.1`, `6.1`, `9.1` and `12.1` pointing
  at it. Hooks ship with the plugin (`hooks/`): a progress log and a desktop notification
  on every turn end and whenever Claude is waiting, a status line with the ledger position,
  and the notify-at-every-tick rule in `1.4` and `5.1`.
- **2.0.1**: the skill description trimmed under the 1024-character cap the Agent Skills
  spec sets for a `description`; install notes rewritten around the copy-on-install
  behaviour.
- **2.0.0**: the hardening pass described at the top. Sections were rewritten where they
  contradicted each other or pointed at machinery that is not part of this plugin, and `1.7`
  (run discipline) was added. The section numbering is unchanged; `1.7` is the only new
  number.
- **1.0.0**: a mechanical split of the original `CLAUDE.md`, one section per file, text
  unchanged.
