// Compose Play Store phone screenshots: a real device capture under a benefit
// headline, on the brand's ink/gold ground. Renders 1080x1920 PNGs via headless
// Chrome so the output needs no image library.
//
//   node build-screenshots.mjs <captures-dir>
//
// Captures come from a seeded emulator (see seed_demo_data.py) -- every number
// on screen is the app's own arithmetic over real rows.

import { execFileSync } from "node:child_process";
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  mkdtempSync,
  existsSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const CAPS = resolve(process.argv[2] ?? join(HERE, "captures"));
const OUT = join(HERE, "screenshots");
const FONTS = resolve(HERE, "../../assets/fonts");
const CHROME =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const W = 1080;
const H = 1920;

// Source captures are 1080x2424 (Pixel 9a). The device sits under the headline
// and bleeds off the bottom edge -- the app's UI stays large enough to read in
// the store carousel, which a fully-contained mockup never manages.
const DEVICE_W = 852;
const DEVICE_TOP = 548;
const SRC_W = 1080;
const SRC_H = 2424;
const SCALE = DEVICE_W / SRC_W;

const FRAMES = [
  {
    file: "home-01-top.png",
    out: "01-dashboard.png",
    eyebrow: "Automatic",
    headline: "Every rupee tracked.\nZero typing.",
    sub: "Budgetify reads your bank SMS and files each transaction the moment it lands.",
    offset: 0,
  },
  {
    file: "txn-detail-01.png",
    out: "02-reads-your-sms.png",
    eyebrow: "How it works",
    headline: "It reads the SMS.\nYou do nothing.",
    sub: "Payee, amount, account and category — lifted straight from the bank's own message.",
    offset: 96,
  },
  {
    file: "budgets-jul-01.png",
    out: "03-where-it-went.png",
    eyebrow: "Analytics",
    headline: "See exactly\nwhere it went.",
    sub: "Category breakdowns, your daily pace against budget, and the merchants taking the most.",
    offset: 560,
  },
  {
    file: "networth-01.png",
    out: "04-net-worth.png",
    eyebrow: "Net worth",
    headline: "Watch your net worth\ncompound.",
    sub: "Track what you own against what you owe, then project where your savings rate leads.",
    offset: 0,
  },
  {
    file: "recurring-01.png",
    out: "05-recurring.png",
    eyebrow: "Subscriptions",
    headline: "Nothing bills you\nby surprise.",
    sub: "Budgetify spots repeating payments on its own and nudges you before each one is due.",
    offset: 0,
  },
];

const dataUri = (p, mime) =>
  `data:${mime};base64,${readFileSync(p).toString("base64")}`;

const font = (w, file) => `@font-face{
  font-family:Manrope;font-weight:${w};font-style:normal;
  src:url(${dataUri(join(FONTS, file), "font/ttf")}) format("truetype");
}`;

const FACES = [
  font(500, "manrope-500.ttf"),
  font(700, "manrope-700.ttf"),
  font(800, "manrope-800.ttf"),
].join("\n");

const esc = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function page(frame) {
  const shot = dataUri(join(CAPS, frame.file), "image/png");
  const scaledH = Math.round(SRC_H * SCALE);
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${FACES}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden}
body{
  font-family:Manrope,sans-serif;
  /* Ink ground with a single warm rise behind the device, echoing the
     feature graphic rather than inventing a second palette. */
  background:
    radial-gradient(1100px 620px at 78% 104%, rgba(200,167,94,.30), transparent 62%),
    radial-gradient(760px 520px at 12% -6%, rgba(74,88,132,.34), transparent 66%),
    linear-gradient(168deg,#1a2036 0%,#141a2b 42%,#0b0e18 100%);
  position:relative;
}
.copy{position:absolute;top:96px;left:78px;right:78px}
.eyebrow{
  font-weight:700;font-size:27px;letter-spacing:.30em;text-transform:uppercase;
  color:#C8A75E;
}
.rule{width:74px;height:4px;background:#C8A75E;border-radius:2px;margin:26px 0 28px}
h1{
  font-weight:800;font-size:78px;line-height:1.06;letter-spacing:-.030em;
  color:#fff;white-space:pre-line;
}
.sub{
  margin-top:26px;font-weight:500;font-size:31px;line-height:1.42;
  color:#9aa4ba;max-width:880px;
}
.device{
  position:absolute;top:${DEVICE_TOP}px;left:${(W - DEVICE_W) / 2}px;
  width:${DEVICE_W}px;height:${H - DEVICE_TOP + 60}px;
  border-radius:46px 46px 0 0;
  overflow:hidden;
  border:1.5px solid rgba(200,167,94,.42);
  border-bottom:none;
  /* Lift the panel off the ground without a generic grey drop-shadow. */
  box-shadow:
    0 -2px 0 rgba(255,255,255,.06) inset,
    0 40px 90px rgba(0,0,0,.55),
    0 0 120px rgba(200,167,94,.10);
}
.device img{
  display:block;width:${DEVICE_W}px;height:${scaledH}px;
  margin-top:${-Math.round(frame.offset * SCALE)}px;
}
</style></head><body>
<div class="copy">
  <div class="eyebrow">${esc(frame.eyebrow)}</div>
  <div class="rule"></div>
  <h1>${esc(frame.headline)}</h1>
  <div class="sub">${esc(frame.sub)}</div>
</div>
<div class="device"><img src="${shot}"></div>
</body></html>`;
}

mkdirSync(OUT, { recursive: true });
// The intermediate HTML inlines the fonts and the capture as base64, so it is
// bulky and disposable -- keep it out of the repo.
const tmp = mkdtempSync(join(tmpdir(), "budgetify-store-"));

for (const frame of FRAMES) {
  const src = join(CAPS, frame.file);
  if (!existsSync(src)) {
    console.error(`missing capture: ${src}`);
    process.exit(1);
  }
  const html = join(tmp, frame.out.replace(/\.png$/, ".html"));
  writeFileSync(html, page(frame));
  execFileSync(
    CHROME,
    [
      "--headless",
      "--disable-gpu",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      `--window-size=${W},${H}`,
      `--screenshot=${join(OUT, frame.out)}`,
      `file://${html}`,
    ],
    { stdio: "ignore" },
  );
  console.log(`${frame.out}  <-  ${frame.file}`);
}
console.log(`\n${FRAMES.length} frames in ${OUT}`);
