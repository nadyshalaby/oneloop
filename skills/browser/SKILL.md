---
name: browser
description: >-
  Drives a real Google Chrome that sites do not flag as automated (its own saved profile, no
  automation flags, patchright on its latest release, curved mouse paths, wheel scrolling,
  uneven typing), one command per action. Use it for every smoke test of a page, every
  browser-based task (browsing, signing in, filling or submitting forms, clicking through a
  site, a screenshot of a page) and any research that needs a real browser (pages behind a
  login, a bot check or Cloudflare). In a oneloop session it is the only browser tool, in
  place of Playwright or Chrome DevTools MCP servers and headless scripts.
---

# The browser

One real Chrome window, driven the way a person drives it. The law sends every smoke test of a
page, every browser-based task and all research that needs a browser through this skill (the
law, Browser). A quick lookup that needs no browser stays on the built-in web search, and a
check command a project's map configures still runs as written.

## Why sites do not flag it

| Piece | Why |
|---|---|
| The user's real `/Applications/Google Chrome.app` | Reads as a normal current Chrome. Chrome for Testing reports another brand, and its Google sign-in gets challenged. |
| Started plainly, with only `--remote-debugging-port` | No `--enable-automation`, so `navigator.webdriver` stays false and the user can use the window by hand. |
| Its own saved profile | Logins survive between sessions; the user's everyday Chrome profile is never touched. |
| `patchright` over CDP, on its latest release | Playwright with the known giveaways patched out, the same version numbers as Playwright; `setup.sh` moves it to the newest one on every run. |
| Human pacing (`human.mjs`) | Sites judge behaviour too: the mouse travels a curved path from where it last was, the page scrolls by wheel in uneven steps, keys have a hold time and uneven gaps, long text is pasted. |

`botcheck.mjs` proves it on two public bot-check pages (bot-detector.rebrowser.net and
bot.sannysoft.com) and ends with `CLEAN` or names what leaked.

## Where it lives

- **Scripts**: `skills/browser/scripts/` under the harness root, which the law's first lines
  name. Shell state does not survive between commands, so start each one with
  `B="$(jq -r '.plugins["oneloop@oneloop"][0].installPath' ~/.claude/plugins/installed_plugins.json)/skills/browser/scripts"`.
- **Runtime** (patchright): `~/.local/share/oneloop-browser`, or `BROWSER_RUNTIME`.
- **Saved profile**: `~/.local/share/oneloop-browser/profile`, or `BROWSER_PROFILE`.
- **Control port**: 9334, or `BROWSER_PORT`. A second browser beside the first (a throwaway
  one for a test that must not see the saved logins) is another port with another profile.
- macOS with Google Chrome installed, `node`, `jq` and `curl`.

## Start

1. `bash "$B/setup.sh"` at the start of every browser job. It installs patchright or moves it
   to its latest release, and prints the version; offline, it keeps the installed one and says so.
2. `bash "$B/launch.sh" 'https://example.com'` starts Chrome, or reuses the one already running
   and opens the URL in it, and brings that window to the front (a second Chrome icon in the
   Dock). Only this script takes the focus; the commands below never do.
3. `node "$B/botcheck.mjs"` before the first sign-in on a machine, and after Chrome or patchright
   changed version. It must end with `CLEAN`; anything else, stop and fix it first.
4. **A login is the user's.** Ask them to sign in themselves in that window and to say when it
   is done. Never ask for, store or type their password. A script that truly must type a secret
   reads it from an environment variable at run time, `{"label":"Password","env":"SITE_PASSWORD"}`,
   and every read-back shows a password as dots.

## Drive it: one command per action

`node "$B/browse.mjs" <command> [tab] [arguments]`; with no arguments it prints this list.

| Command | What it does |
|---|---|
| `tabs` | every open tab, numbered |
| `open <url>` | a new tab; prints the HTTP status, where it landed and every failed request |
| `goto <tab> <url>` | the same in an open tab |
| `close <tab>` | closes it; refuses the last tab (Chrome with no window cannot be attached to) |
| `text <tab> [start] [length]` | the visible text, frames included; 4000 characters from 0 |
| `fields <tab>` | every field with its label, name and what it shows now, the buttons, the error messages, and a line when a human check is on the page |
| `fill <tab> '<json>'` or `@<path of a JSON file>` | fills the listed fields and prints what each one shows afterwards |
| `click <tab> "<name regex>"` | a button, link, tab or menu item by its visible name; a JSON field in place of the name clicks any element |
| `press <tab> <key>` | `Enter`, `Escape`, `Tab`, `ArrowDown` ... |
| `scroll <tab> <pixels>` | by wheel; negative scrolls up |
| `wait <tab> "<text regex>" [ms]` | until the page shows the text (15 seconds) |
| `shot <tab> <path of the PNG>` | the page only, never the screen; then Read the image |
| `eval <tab> '<js>'` | reads the DOM from a hidden world and prints the JSON |
| `evalpage <tab> '<js>'` | the same in the page's own world: it sees the page's variables, and a bot check can see it, so keep it for pages you trust |

`<tab>` is its number from `tabs`, or any part of its URL or title; the newest match wins.

### A form

```
node "$B/browse.mjs" fields jobs.example
node "$B/browse.mjs" fill jobs.example '[{"label":"Full name","value":"Ada Lovelace"},{"name":"country","value":"Egypt"}]'
node "$B/browse.mjs" fields jobs.example        # read every value back
node "$B/browse.mjs" click jobs.example '^Submit application$'
```

A field is found by ONE of `css`, `name` (the name or id attribute), `role` (with `roleName`,
a regex on its accessible name), `placeholder` or `label`, then narrowed by `text` (a regex on
its own text) and `nth` (0 first). `value` is what to enter, and `kind` says how when the
element does not say it itself:

| `kind` | For | `value` / `option` |
|---|---|---|
| `text` | inputs, textareas, editable boxes (the default) | replaces what is there; over 120 characters it is pasted |
| `select` | a native `<select>` (detected) | the option's label, or part of it |
| `check` | checkboxes, radios, switches, `role=radio` blocks (detected) | none; clicks the control, then its label, until it shows checked |
| `pick` | a dropdown that opens on a click (detected when read-only) | `option`, a regex on the option to choose |
| `combo` | a typeahead: type, wait for suggestions, choose one | `value` to type, `option` to choose |
| `date` | a date input (detected) | ISO `yyyy-mm-dd` |
| `file` | a file input (detected) | a path, or a list of paths |

Every line of `fill` says what the field SHOWS now, the only proof it worked:

- `ok ... shows "..."`: as asked. `ok ... (the page reformatted "105000")`: a mask or grouping
  only, the meaning is the same.
- `DIFFERS ... asked "..."`: the page changed the meaning. A range typed into a number box,
  `3,000 - 3,500`, becomes `30,003,500`. Fix it before anything else.
- `FAIL ...`: the field was not found or would not take the value; the others are still filled.

A `DIFFERS` or a `FAIL` ends the command with exit code 1. **Submitting is always a separate
command, after the values were read back**, never chained to a fill.

### A smoke test

```
node "$B/browse.mjs" open 'http://localhost:3000/checkout'     # status 200, no failed requests
node "$B/browse.mjs" wait checkout 'Order summary'
node "$B/browse.mjs" click checkout '^Place order$'
node "$B/browse.mjs" wait checkout 'Thank you'
node "$B/browse.mjs" shot checkout "$PWD/checkout.png"
```

Paste what the commands printed: that is the proof the Check step and a deploy's live check ask
for. What it sees: the HTTP status, every failed request, what the page shows. What it cannot
see: the page's own console messages and script errors, because patchright keeps that channel
closed (it is one of the giveaways). Judge the page by what it shows, and read the server's log
for the rest.

### Research

`open` the page, read it with `text` (page through with `start`), follow links with `click`,
pull lists out with `eval`, such as
`'[...document.querySelectorAll("h2 a")].map((a) => [a.innerText, a.href])'`. Reading hundreds
of public pages fast is another job: fetch those directly, and keep this window for what
needs a person's pace.

### Beyond the commands

A flow no command covers is a short script that imports the same modules by full path:

```js
import { connect, pause, humanClick, humanType, humanScroll } from '<scripts>/human.mjs';
import { fillField, findField, describeFields } from '<scripts>/forms.mjs';
const { browser, context } = await connect();          // BROWSER_PORT, default 9334
const page = context.pages().at(-1);
await humanClick(page, page.getByRole('button', { name: 'Next' }));
await browser.close();                                 // over CDP this only disconnects
```

## Rules

- One action at a time, at a person's pace, and low volume: a few submissions an hour on any
  one site. Nothing is undetectable for ever, since sites also watch volume and patterns; say so.
- Anything outward-facing (an application, a post, a message, a payment) needs the user's
  authorisation before it is submitted.
- A human check (press and hold, a puzzle, a visible captcha) and a required voice or video
  recording belong to the user: fill everything else, leave the tab open and tell them.
- Screenshots are of the page only (`shot`), never the screen.
- Close only the tabs you opened, never the last one, and leave the window open at the end
  unless the user asks to close it.
- No other browser tool in a oneloop session: no Playwright or Chrome DevTools MCP server, no
  headless script. Those windows are shared with other sessions and with the user, and sites
  flag them.

## Traps already hit

- `osascript -e 'tell application "Google Chrome" to activate'` focuses the user's everyday
  Chrome. `launch.sh` focuses by the process that listens on the port.
- `pgrep -f pattern` and `pkill -f pattern` also match the shell running them: write the
  pattern with one bracketed letter, `oneloop-browser/[p]rofile`.
- A Cloudflare "Just a moment" page clears in about 15 seconds on its own: stay on it, never
  reload in a loop.
- Job boards that hide the real apply link behind their own sign-up: search for the company's
  own job page and apply there.
- A CSS `#id` that starts with a digit is invalid: give the id as `name`, which matches it as
  an attribute.
- An Angular Material date input can be disabled: pick the date through its calendar and read
  the field back, since the shown date can be a day off with the time zone.
- A recording page can freeze behind a microphone prompt: CDP `Browser.setPermission` with the
  names `microphone` and `camera` set to `denied` frees it; set them back to `prompt` after.
- A form can hold a photo file box before the resume box: target the file input by what it
  accepts, `{"css":"input[type=file][accept*=\".pdf\"]","value":"/path/cv.pdf"}`, never the
  first file input.
- A form can pre-fill an address guessed from the connection: read `fields` and replace it.
- Questions drawn as blocks, not inputs (`role=radio` with the question as its label):
  `{"role":"radio","roleName":"Remote ok","text":"^\\s*Yes\\s*$"}`.
- A dropdown that filters as you type and lists nothing until then: `kind: "combo"`. One that
  lists everything on a click: `kind: "pick"`, also when it is not read-only.
- Rate limits seen when reading fast with plain fetches, not this window: LinkedIn guest job
  pages answered 429 after about 80 requests 700 ms apart, and ran clean at a random 2200 to
  3700 ms.

## Files

- `scripts/setup.sh`: installs patchright into the runtime folder, or updates it to the latest.
- `scripts/launch.sh`: starts or reuses the real Chrome, opens a URL, brings it to the front.
- `scripts/browse.mjs`: the commands above.
- `scripts/human.mjs`: `connect`, `pause`, `moveMouse`, `scrollIntoView`, `humanScroll`,
  `humanClick`, `humanType`, `replaceText`.
- `scripts/forms.mjs`: `findField`, `findClickable`, `fillField`, `readBack`, `compareShown`,
  `describeFields`.
- `scripts/botcheck.mjs`: the two bot-check pages; exit 1 when anything is flagged.
