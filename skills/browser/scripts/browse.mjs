#!/usr/bin/env node
// One command per browser action on the skill's Chrome, each at human pace. No arguments prints the list.
import { readFile } from 'node:fs/promises';
import { connect, humanClick, humanScroll, pause } from './human.mjs';
import { describeFields, fillField, findClickable, findField, Verdict } from './forms.mjs';

const USAGE = `usage: node browse.mjs <command> [tab] [arguments]
  tabs                               every open tab, numbered
  open <url>                         a new tab; prints the status and every failed request
  goto <tab> <url>                   the same in an open tab
  close <tab>                        never the last tab
  text <tab> [start] [length]        the visible text, frames included (4000 characters from 0)
  fields <tab>                       every field, button and error, with what each shows now
  fill <tab> '<json>' | @<json path> [{css|name|role|placeholder|label, value, kind?, option?, text?, nth?, env?}]
  click <tab> "<name regex>" | '<json field>'
  press <tab> <key>                  Enter, Escape, Tab, ArrowDown ...
  scroll <tab> <pixels>              negative scrolls up
  wait <tab> "<text regex>" [ms]     until the page shows the text (15000)
  shot <tab> <png path>              the page only, never the screen
  eval <tab> '<js expression>'       reads the DOM from a hidden world, prints the JSON it returns
  evalpage <tab> '<js expression>'   the same in the page's own world: sees its variables, and a bot check can see it
<tab> is its number from "tabs", or any part of its URL or title; the newest match wins.
fill kinds: text, select, check, pick (a click-to-open dropdown), combo (type, then choose), date, file.`;

const NEEDED_ARGUMENTS = Object.freeze({ open: 1, goto: 2, close: 1, text: 1, fields: 1, fill: 2, click: 2, press: 2, scroll: 2, wait: 2, shot: 2, eval: 2, evalpage: 2 });
const WAIT_MS = 15000;

const print = (line) => process.stdout.write(`${line}\n`);
const firstLine = (err) => err.message.split('\n')[0];

async function listTabs(context) {
  return Promise.all(context.pages().map(async (page) => ({ page, url: page.url(), title: await page.title() })));
}

const formatTabs = (tabs) => tabs.map((tab, i) => `${i + 1}  ${tab.title.slice(0, 60)}  ${tab.url.slice(0, 140)}`).join('\n');

async function pickTab(context, ref) {
  const tabs = await listTabs(context);
  const numbered = /^\d+$/.test(ref) ? tabs[Number(ref) - 1] : undefined;
  const needle = ref.toLowerCase();
  const chosen = numbered ?? tabs.findLast((tab) => tab.url.toLowerCase().includes(needle) || tab.title.toLowerCase().includes(needle));
  if (!chosen) throw new Error(`no tab matches "${ref}". Open tabs:\n${formatTabs(tabs)}`);
  return chosen.page;
}

async function announce(page) {
  await page.waitForLoadState('domcontentloaded');
  await pause(1200, 2500);
  print(`${await page.title()} | ${page.url()}`);
}

// Load a URL and say what a smoke test needs: the status, where it landed, and every request that failed.
async function visit(page, url) {
  const failures = [];
  const noteFailed = (request) => failures.push(`${request.failure()?.errorText ?? 'failed'} ${request.url().slice(0, 140)}`);
  const noteStatus = (response) => {
    if (response.status() >= 400) failures.push(`${response.status()} ${response.url().slice(0, 140)}`);
  };
  page.on('requestfailed', noteFailed);
  page.on('response', noteStatus);
  const response = await page.goto(url, { waitUntil: 'domcontentloaded' });
  await announce(page);
  page.off('requestfailed', noteFailed);
  page.off('response', noteStatus);
  print(`status ${response?.status() ?? 'none (a file or about: page has no network response)'}`);
  print(failures.length ? `${failures.length} failed request(s):\n  ${failures.slice(0, 10).join('\n  ')}` : 'no failed requests while loading');
}

async function frameText(frame) {
  try {
    return await frame.evaluate(() => document.body?.innerText ?? '');
  } catch (err) {
    return `[unreadable frame: ${firstLine(err)}]`;
  }
}

async function visibleText(page) {
  const parts = [];
  for (const frame of page.frames()) {
    if (frame.isDetached()) continue;
    const text = (await frameText(frame)).replace(/\s+/g, ' ').trim();
    if (text) parts.push(frame === page.mainFrame() ? text : `[frame ${frame.url().slice(0, 80)}] ${text}`);
  }
  return parts.join(' ');
}

async function readSpecs(source) {
  const json = source.startsWith('@') ? await readFile(source.slice(1), 'utf8') : source;
  const specs = JSON.parse(json);
  return Array.isArray(specs) ? specs : [specs];
}

const keyOf = (spec) => spec.label ?? spec.name ?? spec.css ?? spec.placeholder ?? `${spec.role} ${spec.roleName ?? ''}`.trim();

// One line for one field: what it shows now, and whether that still means what was asked.
async function fillOne(page, spec) {
  try {
    const { kind, shown, verdict } = await fillField(page, spec);
    const line = `${keyOf(spec)} [${kind}] shows ${JSON.stringify(shown)}`;
    if (verdict === Verdict.DIFFERS) return { isWrong: true, line: `DIFFERS ${line}, asked ${JSON.stringify(spec.value)}: fix it before submitting` };
    return { isWrong: false, line: verdict === Verdict.REFORMATTED ? `ok ${line} (the page reformatted ${JSON.stringify(spec.value)})` : `ok ${line}` };
  } catch (err) {
    return { isWrong: true, line: `FAIL ${keyOf(spec)}: ${firstLine(err)}` };
  }
}

async function fillAll(page, [source]) {
  let wrong = 0;
  for (const spec of await readSpecs(source)) {
    const { isWrong, line } = await fillOne(page, spec);
    wrong += isWrong ? 1 : 0;
    print(line);
  }
  if (wrong === 0) return;
  process.exitCode = 1;
  print(`${wrong} field(s) need a look before anything is submitted`);
}

async function clickTarget(page, [target], context) {
  const locator = target.trim().startsWith('{') ? await findField(page, JSON.parse(target)) : await findClickable(page, target);
  const tabsBefore = context.pages().length;
  await humanClick(page, locator);
  await announce(page);
  const opened = context.pages().slice(tabsBefore);
  for (const tab of opened) print(`a new tab opened: ${tab.url()}`);
}

const TAB_COMMANDS = Object.freeze({
  goto: (page, [url]) => visit(page, url),
  close: async (page, _unused, context) => {
    if (context.pages().length === 1) throw new Error('this is the last tab: closing it leaves Chrome with no window to attach to');
    await page.close();
    print('closed');
  },
  text: async (page, [start = '0', length = '4000']) => print((await visibleText(page)).slice(Number(start), Number(start) + Number(length))),
  fields: async (page) => print((await describeFields(page)).join('\n')),
  fill: fillAll,
  click: clickTarget,
  press: async (page, [key]) => {
    await page.keyboard.press(key);
    await pause(300, 800);
    print(`pressed ${key}`);
  },
  scroll: async (page, [pixels]) => {
    await humanScroll(page, Number(pixels));
    print(`scrolled to ${await page.evaluate(() => Math.round(scrollY))}`);
  },
  wait: async (page, [pattern, ms = WAIT_MS]) => {
    await page.waitForFunction((source) => new RegExp(source, 'i').test(document.body.innerText), pattern, { timeout: Number(ms) });
    print(`the page shows /${pattern}/`);
  },
  shot: async (page, [file]) => {
    await page.screenshot({ path: file });
    print(`${file} | ${page.url()}`);
  },
  eval: async (page, [expression]) => print(JSON.stringify(await page.evaluate(expression), null, 1)),
  evalpage: async (page, [expression]) => {
    const isIsolated = false; // patchright's 4th argument: the page's own variables live outside its default isolated world
    print(JSON.stringify(await page.evaluate(expression, undefined, undefined, isIsolated), null, 1));
  },
});

async function runCommand(context, [command, ...rest]) {
  if (command === 'tabs') return print(formatTabs(await listTabs(context)));
  if (command === 'open') {
    return visit(await context.newPage(), rest[0]);
  }
  const [tabRef, ...args] = rest;
  return TAB_COMMANDS[command](await pickTab(context, tabRef), args, context);
}

async function main(argv) {
  const [command] = argv;
  const isKnown = command === 'tabs' || command in NEEDED_ARGUMENTS;
  if (!isKnown || argv.length - 1 < (NEEDED_ARGUMENTS[command] ?? 0)) {
    print(USAGE);
    process.exitCode = command ? 2 : 0;
    return;
  }
  const { browser, context } = await connect();
  try {
    await runCommand(context, argv);
  } finally {
    await browser.close(); // over CDP this only disconnects: the Chrome window stays open
  }
}

main(process.argv.slice(2)).catch((err) => {
  process.stderr.write(`error: ${err.message}\n`);
  process.exitCode = 1;
});
