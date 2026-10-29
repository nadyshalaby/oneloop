// oneloop for OpenCode 2.x. Every guard stays the bash hook under hooks/: this entry feeds each
// one the JSON Claude Code would send and hands its additionalContext to the model, so the law,
// the pointers and the skills match the Claude Code plugin with one copy of each rule.
import { spawn } from "node:child_process"
import { readdir, readFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = fileURLToPath(new URL("..", import.meta.url))

// runHook: what one hook script prints for the JSON it is fed; a hook that cannot run gives a
// line saying so, never a failed tool call (a hook never blocks on its own bug).
function runHook(hook) {
  return new Promise((resolve) => {
    const script = path.join(root, "hooks", hook.script)
    const child = spawn("bash", [script, ...(hook.args ?? [])], { cwd: hook.cwd, timeout: 20000 })
    let stdout = ""
    child.stdout.on("data", (chunk) => { stdout += chunk })
    child.on("error", (error) => resolve(`oneloop: ${hook.script} did not run (${error.message})`))
    child.stdin.on("error", (error) => resolve(`oneloop: ${hook.script} closed its input (${error.message})`))
    child.on("close", () => resolve(stdout))
    child.stdin.end(JSON.stringify(hook.payload))
  })
}

// contextOf: the additionalContext in a hook's JSON output, its plain text otherwise.
function contextOf(stdout, script) {
  const text = stdout.trim()
  if (!text.startsWith("{")) return text
  try {
    return JSON.parse(text).hookSpecificOutput?.additionalContext ?? ""
  } catch (error) {
    return `oneloop: ${script} printed unreadable JSON (${error.message})`
  }
}

async function hookContext(hook) {
  return contextOf(await runHook(hook), hook.script)
}

// lawParts: the system parts every request carries: how the law's Claude Code names map here,
// the law's two parts as SessionStart hands them over, and the loop reminder.
async function lawParts(directory) {
  const start = { hook_event_name: "SessionStart", source: "startup", session_id: "opencode", cwd: directory }
  const prompt = { hook_event_name: "UserPromptSubmit", cwd: directory }
  const texts = [
    "oneloop in OpenCode. The law below was written for Claude Code; here AskUserQuestion is the `question` tool, a `oneloop:<name>` skill or `/oneloop:<name>` command is loaded with the `skill` tool (id `oneloop:<name>`), Edit, Write, Read and Bash are `edit` (or `patch`), `write`, `read` and `shell`, a guard's pointer arrives at the end of the tool's output, and `oneloop:er-reader` does not exist here: search yourself.",
    await hookContext({ script: "session-start.sh", args: ["1"], payload: start, cwd: directory }),
    await hookContext({ script: "session-start.sh", args: ["2"], payload: start, cwd: directory }),
    await hookContext({ script: "loop-reminder.sh", payload: prompt, cwd: directory }),
  ]
  return texts.filter(Boolean).map((text) => ({ type: "text", text }))
}

function unquote(value) {
  const quoted = /^(["'])([\s\S]*)\1$/.exec(value)
  if (!quoted) return value
  return quoted[1] === "'" ? quoted[2].replaceAll("''", "'") : quoted[2]
}

// headerFields: the top-level `key: value` lines of a YAML header; a folded `>-` block's lines
// are joined with spaces.
function headerFields(header) {
  const fields = {}
  let blockKey = ""
  for (const line of header.split("\n")) {
    const field = /^([A-Za-z][\w-]*):\s*(.*)$/.exec(line)
    if (field) {
      blockKey = /^[>|][-+]?$/.test(field[2]) ? field[1] : ""
      fields[field[1]] = blockKey ? "" : unquote(field[2])
    } else if (blockKey) {
      fields[blockKey] = `${fields[blockKey]} ${line.trim()}`.trim()
    }
  }
  return fields
}

// readSkill: skills/<name>/SKILL.md as the skill `oneloop:<name>`, the name Claude Code types.
async function readSkill(name) {
  const file = path.join(root, "skills", name, "SKILL.md")
  const markdown = await readFile(file, "utf8")
  const parts = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/.exec(markdown)
  const fields = parts ? headerFields(parts[1]) : {}
  return {
    id: `oneloop:${name}`,
    name: `oneloop:${name}`,
    description: fields.description,
    autoinvoke: fields["disable-model-invocation"] !== "true",
    path: file,
    content: parts ? parts[2] : markdown,
  }
}

async function loadSkills() {
  const entries = await readdir(path.join(root, "skills"), { withFileTypes: true })
  return Promise.all(entries.filter((entry) => entry.isDirectory()).map((entry) => readSkill(entry.name)))
}

// patchCalls: a `patch` call as one Claude Code call per file it touches: an added file is a
// Write of its + lines, an updated or deleted one an Edit from its - lines to its + lines.
function patchCalls(patchText, directory) {
  const sections = []
  for (const line of String(patchText ?? "").split("\n")) {
    const header = /^\*\*\* (Add|Update|Delete) File: (.+)$/.exec(line)
    const section = sections.at(-1)
    if (header) {
      sections.push({ kind: header[1], file: path.resolve(directory, header[2].trim()), added: [], removed: [] })
    } else if (section && /^[+-]/.test(line)) {
      (line[0] === "+" ? section.added : section.removed).push(line.slice(1))
    }
  }
  return sections.map((section) => section.kind === "Add"
    ? { tool_name: "Write", tool_input: { file_path: section.file, content: section.added.join("\n") } }
    : { tool_name: "Edit", tool_input: { file_path: section.file, old_string: section.removed.join("\n"), new_string: section.added.join("\n") } })
}

// claudeCalls: the Claude Code tool calls one OpenCode call stands for.
function claudeCalls(tool, input, directory) {
  const file = typeof input.path === "string" ? path.resolve(directory, input.path) : ""
  if (tool === "edit") return [{ tool_name: "Edit", tool_input: { file_path: file, old_string: input.oldString, new_string: input.newString } }]
  if (tool === "write") return [{ tool_name: "Write", tool_input: { file_path: file, content: input.content } }]
  if (tool === "read") return [{ tool_name: "Read", tool_input: { file_path: file } }]
  if (tool === "shell") return [{ tool_name: "Bash", tool_input: { command: input.command } }]
  if (tool === "patch") return patchCalls(input.patchText, directory)
  return []
}

// guardsOf: the PreToolUse scripts hooks/hooks.json runs for a Claude Code tool.
function guardsOf(toolName) {
  if (toolName === "Read") return ["code-rules.sh"]
  if (toolName === "Bash") return ["commit-check.sh"]
  return ["risk-zone.sh", "scope-check.sh", "code-rules.sh", "edit-guard.sh"]
}

// pointersFor: every guard's pointer for one OpenCode tool call, joined; empty when none points.
async function pointersFor(event, directory) {
  const texts = []
  for (const call of claudeCalls(event.tool, event.input ?? {}, directory)) {
    const payload = { ...call, hook_event_name: "PreToolUse", session_id: event.sessionID, cwd: directory }
    const contexts = await Promise.all(guardsOf(call.tool_name).map((script) => hookContext({ script, payload, cwd: directory })))
    texts.push(...contexts.filter(Boolean))
  }
  return texts.join("\n\n")
}

// recordEdits: the PostToolUse half of the risk-zone guard, so an edited file is not pointed at again.
async function recordEdits(event, directory) {
  for (const call of claudeCalls(event.tool, event.input ?? {}, directory)) {
    const payload = { ...call, hook_event_name: "PostToolUse", session_id: event.sessionID, cwd: directory }
    await runHook({ script: "risk-zone.sh", payload, cwd: directory })
  }
}

function withPointers(content, text) {
  if (Array.isArray(content)) return [...content, { type: "text", text }]
  return `${content ?? ""}\n\n${text}`
}

export default {
  id: "oneloop",
  async setup(ctx) {
    const directory = ctx.location.directory
    const system = await lawParts(directory)
    const skills = await loadSkills()
    const pointers = new Map()
    await ctx.skill.transform((editor) => {
      skills.filter((skill) => !editor.get(skill.id)).forEach((skill) => editor.add(skill))
    })
    await ctx.session.hook("context", (event) => {
      event.system.push(...system) // law-exception: an OpenCode hook takes its change by mutating the event
    })
    await ctx.tool.hook("execute.before", async (event) => {
      const text = await pointersFor(event, directory)
      if (text) pointers.set(event.id, text)
    })
    await ctx.tool.hook("execute.after", async (event) => {
      const text = pointers.get(event.id)
      pointers.delete(event.id)
      if (event.status !== "completed") return
      if (["edit", "write", "patch"].includes(event.tool)) await recordEdits(event, directory)
      if (text) event.result.content = withPointers(event.result.content, text) // law-exception: an OpenCode hook takes its change by mutating the event
    })
  },
}
