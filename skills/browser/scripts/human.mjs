// Human-paced input for patchright pages: connect, curved mouse paths, wheel scrolling, uneven typing.
const RUNTIME = process.env.BROWSER_RUNTIME || `${process.env.HOME}/.local/share/oneloop-browser`;
const LONG_TEXT = 120;
const SCROLL_TRIES = 25;
const SELECT_MODIFIER = process.platform === 'darwin' ? 'Meta' : 'Control';
const lastPointer = new WeakMap();

export const pause = (min = 400, max = 1200) => new Promise((r) => setTimeout(r, min + Math.random() * (max - min)));

// Chrome keeps running when every window is closed, but CDP then has no browser context to attach to.
async function ensureWindow(port) {
  const cdpUrl = `http://127.0.0.1:${port}`;
  let targets;
  try {
    targets = await (await fetch(`${cdpUrl}/json/list`)).json();
  } catch (err) {
    throw new Error(`no Chrome answers on port ${port}: run launch.sh first`, { cause: err });
  }
  if (!targets.some((t) => t.type === 'page')) await fetch(`${cdpUrl}/json/new?about:blank`, { method: 'PUT' });
}

export async function connect(port = Number(process.env.BROWSER_PORT || 9334)) {
  await ensureWindow(port);
  const { chromium } = await import(`${RUNTIME}/node_modules/patchright/index.mjs`);
  const browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`);
  return { browser, context: browser.contexts()[0] };
}

async function viewportOf(page) {
  return page.evaluate(() => ({ width: innerWidth, height: innerHeight }));
}

// A cubic Bezier from `from` to `to` with both control points pushed sideways, sampled with ease-in-out.
function curvedPath(from, to) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const distance = Math.hypot(dx, dy);
  const steps = Math.max(12, Math.min(45, Math.round(distance / 14)));
  const bend = (Math.random() - 0.5) * Math.min(distance * 0.35, 160);
  const nx = distance ? -dy / distance : 0;
  const ny = distance ? dx / distance : 0;
  const c1 = { x: from.x + dx * 0.3 + nx * bend, y: from.y + dy * 0.3 + ny * bend };
  const c2 = { x: from.x + dx * 0.7 + nx * bend * 0.6, y: from.y + dy * 0.7 + ny * bend * 0.6 };
  return Array.from({ length: steps }, (_, i) => {
    const s = (i + 1) / steps;
    const t = s < 0.5 ? 2 * s * s : 1 - (-2 * s + 2) ** 2 / 2;
    const u = 1 - t;
    return {
      x: u ** 3 * from.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t ** 3 * to.x,
      y: u ** 3 * from.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t ** 3 * to.y,
    };
  });
}

export async function moveMouse(page, target) {
  let from = lastPointer.get(page);
  if (!from) {
    const view = await viewportOf(page);
    from = { x: view.width * (0.3 + Math.random() * 0.4), y: view.height * (0.2 + Math.random() * 0.3) };
  }
  for (const point of curvedPath(from, target)) {
    await page.mouse.move(point.x, point.y);
    await pause(4, 14);
  }
  lastPointer.set(page, target);
}

// Pixels the element must travel to sit in the middle band of the viewport; 0 when it is close enough.
function offsetToBand(box, view) {
  const isInBand = box.y >= view.height * 0.15 && box.y + box.height <= view.height * 0.85;
  const offset = box.y + box.height / 2 - view.height / 2;
  return isInBand || Math.abs(offset) < 8 ? 0 : offset;
}

export async function scrollIntoView(page, locator) {
  const view = await viewportOf(page);
  for (let i = 0; i < SCROLL_TRIES; i++) {
    const box = await locator.boundingBox();
    const offset = box ? offsetToBand(box, view) : 0;
    if (offset === 0) break;
    await page.mouse.wheel(0, Math.sign(offset) * Math.min(Math.abs(offset), 380 + Math.random() * 260));
    await pause(110, 300);
    const after = await locator.boundingBox();
    if (after && Math.abs(after.y - box.y) < 2) break; // the wheel moved nothing: a fixed page, or the pointer is over another scroller
  }
  await locator.scrollIntoViewIfNeeded();
}

export async function humanScroll(page, pixels) {
  let left = pixels;
  while (Math.abs(left) > 1) {
    const step = Math.sign(left) * Math.min(Math.abs(left), 120 + Math.random() * 280);
    await page.mouse.wheel(0, step);
    left -= step;
    await pause(90, 260);
  }
}

// The click itself is patchright's, so a banner covering the target fails loudly instead of taking the click.
export async function humanClick(page, locator, { timeout } = {}) {
  await scrollIntoView(page, locator);
  const box = await locator.boundingBox();
  if (!box) {
    await locator.click({ timeout });
    await pause();
    return;
  }
  const inside = { x: box.width * (0.3 + Math.random() * 0.4), y: box.height * (0.3 + Math.random() * 0.4) };
  await moveMouse(page, { x: box.x + inside.x, y: box.y + inside.y });
  await pause(90, 260);
  await locator.click({ position: inside, delay: 40 + Math.random() * 80, timeout });
  await pause();
}

const keyHold = () => 35 + Math.random() * 70;

// The gap before the next key: longer after a word or a sentence, now and then a pause to think.
function keyGap(char) {
  if (Math.random() < 0.03) return [350, 900];
  if (/[.,;:!?]/.test(char)) return [160, 420];
  if (char === ' ') return [90, 260];
  return [45, 150];
}

// Types into whatever has focus, key by key; `field` only takes the paste of a long text.
async function enterText(page, field, text) {
  if (text.length > LONG_TEXT) {
    await field.fill(text); // people paste long text; typing it key by key also outlasts patchright's 30 s action timeout
  } else {
    for (const char of text) {
      await page.keyboard.type(char, { delay: keyHold() });
      await pause(...keyGap(char));
    }
  }
  await pause(300, 900);
}

export async function humanType(page, locator, text) {
  await humanClick(page, locator);
  await enterText(page, locator, text);
}

export async function replaceText(page, locator, text) {
  await humanClick(page, locator);
  await page.keyboard.down(SELECT_MODIFIER);
  await pause(40, 110);
  await page.keyboard.press('a', { delay: keyHold() });
  await page.keyboard.up(SELECT_MODIFIER);
  await pause(60, 180);
  await page.keyboard.press('Backspace', { delay: keyHold() });
  await pause(120, 300);
  await enterText(page, locator, text);
}
