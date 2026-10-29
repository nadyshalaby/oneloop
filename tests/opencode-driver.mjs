// Drives opencode/plugin.js the way OpenCode 2.x calls a plugin, for tests/opencode.test.sh:
// a stand-in context records the skills, the system parts and the tool hooks, then each tool
// call it is given runs through execute.before and execute.after. Prints one JSON object.
// Run: node tests/opencode-driver.mjs <plugin.js> <project dir> <calls.json>
import { readFile } from "node:fs/promises"

const [pluginPath, directory, callsPath] = process.argv.slice(2)
const plugin = (await import(pluginPath)).default
const hooks = {}
const skills = []
await plugin.setup({
  location: { directory },
  skill: { transform: async (edit) => edit({ get: () => undefined, add: (skill) => skills.push(skill) }) },
  session: { hook: async (name, run) => { hooks[`session.${name}`] = run } },
  tool: { hook: async (name, run) => { hooks[`tool.${name}`] = run } },
})

const request = { system: [] }
await hooks["session.context"](request)

const outputs = []
const sessionID = `ses_test_${process.pid}`
for (const call of JSON.parse(await readFile(callsPath, "utf8"))) {
  const event = { id: `call_${outputs.length}`, sessionID, tool: call.tool, input: call.input }
  await hooks["tool.execute.before"](event)
  const done = { ...event, status: "completed", result: { content: "Edited." } }
  await hooks["tool.execute.after"](done)
  outputs.push(done.result.content)
}

process.stdout.write(JSON.stringify({
  skills: skills.map((skill) => ({ id: skill.id, name: skill.name, hasDescription: Boolean(skill.description), path: skill.path })),
  system: request.system.map((part) => part.text),
  outputs,
}))
