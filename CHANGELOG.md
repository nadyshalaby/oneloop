# engineering-rules, the history

One entry per version, newest first. The README says what the setup is now; this file says how it got there.

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
