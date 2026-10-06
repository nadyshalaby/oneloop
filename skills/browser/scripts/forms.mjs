// Find, fill and read back form fields in every frame of a page, at human pace.
import { humanClick, moveMouse, replaceText } from './human.mjs';

/**
 * A field to act on: one locator key (css, name, role, placeholder, label), then optional narrowing.
 * @typedef {object} FieldSpec
 * @property {string} [label] visible label text (getByLabel)
 * @property {string} [name] the name or id attribute
 * @property {string} [css] any patchright selector
 * @property {string} [role] an ARIA role; `roleName` narrows it by accessible name (regex)
 * @property {string} [roleName]
 * @property {string} [placeholder]
 * @property {string} [text] keep only matches whose text matches this regex
 * @property {number} [nth] which match, 0 by default
 * @property {string} [kind] one of the FILLERS keys; inferred from the element when absent
 * @property {string|string[]} [value] text to type, option label, ISO date or file path(s)
 * @property {string} [env] name of an environment variable holding the text (a secret never goes on the command line)
 * @property {string} [option] regex of the option to choose (pick, combo)
 */

const OPTION_WAIT_MS = 6000;
const TOGGLE_CLICK_MS = 4000;
const HUMAN_CHECK_FRAME = /hcaptcha|recaptcha|turnstile|challenges\.cloudflare|arkoselabs|funcaptcha/i;

export const Verdict = Object.freeze({ SAME: 'same', REFORMATTED: 'reformatted', DIFFERS: 'differs', UNCHECKED: 'unchecked' });

function locatorIn(frame, spec) {
  if (spec.css) return frame.locator(spec.css);
  if (spec.name) return frame.locator(`[name="${spec.name}"], [id="${spec.name}"]`);
  if (spec.role) return frame.getByRole(spec.role, spec.roleName ? { name: new RegExp(spec.roleName, 'i') } : {});
  if (spec.placeholder) return frame.getByPlaceholder(spec.placeholder);
  if (spec.label) return frame.getByLabel(spec.label);
  throw new Error(`a field needs css, name, role, placeholder or label: ${JSON.stringify(spec)}`);
}

export async function findField(page, spec) {
  for (const frame of page.frames()) {
    if (frame.isDetached()) continue;
    const all = locatorIn(frame, spec);
    const narrowed = spec.text ? all.filter({ hasText: new RegExp(spec.text, 'i') }) : all;
    const locator = narrowed.nth(spec.nth ?? 0);
    if (await locator.count()) return locator;
  }
  throw new Error(`no field matches ${JSON.stringify(spec)}`);
}

// A button, link, tab or menu item by its visible name, in any frame.
export async function findClickable(page, namePattern) {
  const name = new RegExp(namePattern, 'i');
  for (const frame of page.frames()) {
    if (frame.isDetached()) continue;
    const named = frame.getByRole('button', { name }).or(frame.getByRole('link', { name })).or(frame.getByRole('tab', { name })).or(frame.getByRole('menuitem', { name }));
    if (await named.count()) return named.first();
  }
  throw new Error(`no button, link, tab or menu item is named /${namePattern}/`);
}

async function kindOf(locator) {
  return locator.evaluate((el) => {
    const role = el.getAttribute('role');
    if (el.tagName === 'SELECT') return 'select';
    if (['checkbox', 'radio'].includes(el.type) || ['checkbox', 'radio', 'switch'].includes(role)) return 'check';
    if (el.type === 'file' || el.type === 'date') return el.type;
    return role === 'combobox' && el.readOnly ? 'pick' : 'text';
  });
}

function textFor(spec) {
  if (!spec.env) return String(spec.value);
  const secret = process.env[spec.env];
  if (secret === undefined) throw new Error(`the environment variable ${spec.env} is not set`);
  return secret;
}

async function isOn(locator) {
  return locator.evaluate((el) => el.checked === true || el.getAttribute('aria-checked') === 'true');
}

// Custom checkboxes and radios hide the real input: the places a person could click, likeliest first.
async function clickTargetsFor(page, locator) {
  const id = await locator.getAttribute('id');
  const candidates = [locator, locator.locator('xpath=ancestor::label[1]'), page.locator(`label[for="${id ?? ''}"]`).first(), locator.locator('xpath=..')];
  const visible = [];
  for (const candidate of candidates) {
    if ((await candidate.count()) && (await candidate.isVisible())) visible.push(candidate);
  }
  return visible;
}

async function turnOn(page, locator) {
  const misses = [];
  for (const target of await clickTargetsFor(page, locator)) {
    if (await isOn(locator)) return;
    try {
      await humanClick(page, target, { timeout: TOGGLE_CLICK_MS });
    } catch (err) {
      misses.push(err.message.split('\n')[0]); // something covers this spot: the next place may take the click
    }
  }
  if (!(await isOn(locator))) throw new Error(`still not checked after clicking it and its label (${misses.join('; ') || 'every click landed'}): give the visible option with css`);
}

async function chooseSelectOption(page, locator, wanted) {
  const labels = await locator.evaluate((el) => [...el.options].map((o) => o.text.trim()));
  const exact = labels.indexOf(wanted);
  const index = exact >= 0 ? exact : labels.findIndex((t) => t.toLowerCase().includes(wanted.toLowerCase()));
  if (index < 0) throw new Error(`no option "${wanted}" in [${labels.join(' | ')}]`);
  const box = await locator.boundingBox();
  if (box) await moveMouse(page, { x: box.x + box.width / 2, y: box.y + box.height / 2 }); // a real click would open the OS menu, outside the page
  await locator.selectOption({ index });
}

// The options of an open dropdown: its own listbox when it names one, else every visible option.
async function optionsOf(page, locator) {
  const owned = (await locator.getAttribute('aria-controls')) || (await locator.getAttribute('aria-owns'));
  return owned ? page.locator(`[id="${owned}"] [role=option]`) : page.locator('[role=option]:visible, mat-option:visible');
}

async function chooseListOption(page, locator, pattern) {
  const options = await optionsOf(page, locator);
  await options.first().waitFor({ timeout: OPTION_WAIT_MS });
  const texts = (await options.allInnerTexts()).map((t) => t.trim());
  const index = texts.findIndex((t) => new RegExp(pattern, 'i').test(t));
  if (index < 0) {
    await page.keyboard.press('Escape');
    throw new Error(`no option matches /${pattern}/ in [${texts.slice(0, 20).join(' | ')}]`);
  }
  await humanClick(page, options.nth(index));
}

const FILLERS = Object.freeze({
  text: (page, locator, spec) => replaceText(page, locator, textFor(spec)),
  select: (page, locator, spec) => chooseSelectOption(page, locator, String(spec.value)),
  check: (page, locator) => turnOn(page, locator),
  pick: async (page, locator, spec) => {
    if ((await locator.getAttribute('aria-expanded')) !== 'true') await humanClick(page, locator);
    await chooseListOption(page, locator, spec.option ?? String(spec.value));
  },
  combo: async (page, locator, spec) => {
    await replaceText(page, locator, String(spec.value));
    await chooseListOption(page, locator, spec.option ?? String(spec.value));
  },
  date: (page, locator, spec) => locator.fill(String(spec.value)),
  file: (page, locator, spec) => locator.setInputFiles(spec.value),
});

// What the page now shows for the field, the only proof a fill worked. A password comes back as dots.
export async function readBack(locator) {
  return locator.evaluate((el) => {
    if (el.tagName === 'SELECT') return el.selectedOptions[0]?.text.trim() ?? '';
    if (el.type === 'password') return '•'.repeat(el.value.length);
    if (el.type === 'checkbox' || el.type === 'radio') return String(el.checked);
    if (el.type === 'file') return [...el.files].map((f) => f.name).join(', ');
    if (el.hasAttribute('aria-checked')) return el.getAttribute('aria-checked');
    if (el.getAttribute('role') === 'combobox' && !el.value) return (el.closest('[class*="container"], [class*="select"]') || el.parentElement).innerText.replace(/\s+/g, ' ').trim();
    return 'value' in el ? el.value : el.innerText.trim();
  });
}

// A typed value the page reshaped: grouping or a mask is fine, anything else changed its meaning.
export function compareShown(spec, kind, shown) {
  if (!['text', 'date'].includes(kind) || spec.env || spec.value === undefined) return Verdict.UNCHECKED;
  const wanted = String(spec.value);
  if (shown === wanted) return Verdict.SAME;
  const withoutMask = shown.replace(/[^\p{L}\p{N}]/gu, '');
  const withoutSpacing = wanted.replace(/[,\s]/g, '');
  return withoutMask === withoutSpacing ? Verdict.REFORMATTED : Verdict.DIFFERS;
}

export async function fillField(page, spec) {
  const locator = await findField(page, spec);
  const kind = spec.kind ?? (await kindOf(locator));
  const fill = FILLERS[kind];
  if (!fill) throw new Error(`unknown kind "${kind}": use ${Object.keys(FILLERS).join(', ')}`);
  await fill(page, locator, spec);
  const shown = await readBack(locator);
  return { kind, shown, verdict: compareShown(spec, kind, shown) };
}

// Every visible field, button and error message of one frame, as printable lines. Runs inside the page.
function describeFrame() {
  const isShown = (e) => { const r = e.getBoundingClientRect(); return (r.width > 0 && r.height > 0 && getComputedStyle(e).visibility !== 'hidden') || e.type === 'file'; };
  const labelOf = (el) => {
    const byFor = el.id && document.querySelector(`label[for="${CSS.escape(el.id)}"]`)?.innerText;
    const byIds = el.getAttribute('aria-labelledby')?.split(' ').map((i) => document.getElementById(i)?.innerText || '').join(' ');
    const wrapping = el.closest('label');
    const byWrap = wrapping && [...wrapping.childNodes].filter((n) => n.nodeType === Node.TEXT_NODE || !n.matches?.('select, input, textarea')).map((n) => n.textContent).join(' ');
    const text = byFor || el.getAttribute('aria-label') || byIds || byWrap || el.closest('fieldset')?.querySelector('legend')?.innerText || el.placeholder || '';
    return text.replace(/\s+/g, ' ').trim().slice(0, 120);
  };
  const shownValueOf = (el) => {
    if (el.type === 'password') return '•'.repeat(el.value.length);
    if (el.type === 'checkbox' || el.type === 'radio') return String(el.checked);
    return el.getAttribute('aria-checked') ?? (el.value ?? el.innerText ?? '').slice(0, 60);
  };
  const widgets = 'input:not([type=hidden]), select, textarea, [role=radio], [role=checkbox], [role=switch], [role=combobox]:not(input), [contenteditable=true]';
  const lines = [...document.querySelectorAll(widgets)].filter(isShown).map((el) => {
    const role = el.getAttribute('role');
    const kind = role || el.type || el.tagName.toLowerCase();
    const option = ['radio', 'checkbox', 'switch'].includes(role) ? ` option="${el.innerText.replace(/\s+/g, ' ').trim().slice(0, 60)}"` : '';
    const options = el.tagName === 'SELECT' ? ` options=[${[...el.options].map((o) => o.text.trim()).slice(0, 15).join(' | ')}]` : '';
    const required = el.required || el.getAttribute('aria-required') === 'true' ? ' *required' : '';
    return `field ${kind} name=${el.name || el.id || '-'} label="${labelOf(el)}"${option} value=${JSON.stringify(shownValueOf(el))}${required}${options}`;
  });
  const buttons = [...document.querySelectorAll('button, [role=button], input[type=submit]')].filter(isShown).map((b) => (b.innerText || b.value || b.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim()).filter(Boolean);
  const errors = [...document.querySelectorAll('[role=alert], [aria-invalid=true], [class*=error]')].filter(isShown).map((e) => (e.innerText || e.name || '').trim()).filter(Boolean);
  return [...lines, `buttons: ${[...new Set(buttons)].slice(0, 40).join(' | ') || 'none'}`, `errors: ${errors.slice(0, 10).join(' | ') || 'none'}`];
}

async function describeOneFrame(frame) {
  try {
    return await frame.evaluate(describeFrame);
  } catch (err) {
    return [`unreadable: ${err.message.split('\n')[0]}`];
  }
}

export async function describeFields(page) {
  const described = [];
  for (const frame of page.frames()) {
    if (frame.isDetached()) continue;
    if (HUMAN_CHECK_FRAME.test(frame.url())) {
      described.push(`human-check frame present (${new URL(frame.url()).hostname}): an invisible one clears itself, a visible challenge is the user's to solve`);
      continue;
    }
    const lines = await describeOneFrame(frame);
    if (lines.length > 2 || frame === page.mainFrame()) described.push(`frame ${frame.url().slice(0, 100)}`, ...lines);
  }
  return described;
}
