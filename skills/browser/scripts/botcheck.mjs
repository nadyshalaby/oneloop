// Prove the connected Chrome looks normal: runs two public bot-detection pages, prints each check.
import { connect } from './human.mjs';
const { browser, context } = await connect();
const page = await context.newPage();
let bad = 0;
await page.goto('https://bot-detector.rebrowser.net/', { waitUntil: 'load' });
await page.waitForTimeout(6000);
const rows = (await page.evaluate(() => document.body.innerText)).split('\n').filter((l) => /^[🟢🔴🟡⚪️]/u.test(l.trim()));
for (const r of rows) { console.log('rebrowser', r.trim().slice(0, 110)); if (/🔴|🟡/u.test(r)) bad++; }
await page.goto('https://bot.sannysoft.com/', { waitUntil: 'load' });
await page.waitForTimeout(5000);
const fails = await page.$$eval('td', (tds) => tds.filter((td) => /failed/i.test(td.className) || /^failed$/i.test(td.textContent.trim())).map((td) => td.parentElement.innerText.replace(/\s+/g, ' ').slice(0, 100)));
for (const f of fails) console.log('sannysoft FAIL', f);
bad += fails.length;
console.log(bad ? `NOT CLEAN: ${bad} problem(s)` : 'CLEAN: no automation flag, no leaks, normal Chrome');
await page.close();
await browser.close(); // disconnects only; the Chrome window stays open
process.exit(bad ? 1 : 0);
