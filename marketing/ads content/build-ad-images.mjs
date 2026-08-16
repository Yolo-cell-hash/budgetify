// Compose Google Ads App-campaign image assets in the three ratios Google
// serves: 1.91:1 landscape, 1:1 square and 4:5 portrait.
//
//   node "build-ad-images.mjs" [captures-dir]
//
// Same ground rules as the Play Store screenshots next door: the device panel
// is a real capture off a seeded emulator, the palette is the app's own ink and
// gold, and the type is the app's own Manrope. Nothing here is a mockup.
//
// Ad images are read at thumbnail size and Google draws its own app icon,
// headline and Install button over most placements, so the copy here stays to
// one short line -- anything longer competes with Google's chrome and loses.
//
// LAYOUT RULE: the wordmark, eyebrow, rule, headline and sub are ONE normal-flow
// column with margins expressed as multiples of the ratio's own type scale. They
// were absolutely positioned independently at first, which made the gap under
// the wordmark a function of the logo size and the eyebrow's length -- so
// "HOW IT WORKS" crowded the wordmark while "BUDGETS" did not, and the set
// looked hand-placed. Keep them in one flow so the rhythm is identical across
// every concept and every ratio by construction.

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
const CAPS = resolve(process.argv[2] ?? join(HERE, "../playstore/captures"));
const OUT = join(HERE, "images");
const FONTS = resolve(HERE, "../../assets/fonts");
const LOGO = resolve(HERE, "../../assets/branding/logo.png");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// Source captures are 1080x2424 (Pixel 9a).
const SRC_W = 1080;
const SRC_H = 2424;

// Every canvas Google accepts for an App campaign image asset. Landscape and
// square are the two it requires; portrait is optional but unlocks inventory
// the other two never reach.
//
// `gap` is the breath under the wordmark, in multiples of the logo size. One
// number, shared by every concept -- that is what keeps the set consistent.
const GAP = 1.05;

const RATIOS = [
  {
    id: "1200x628",
    w: 1200,
    h: 628,
    layout: "side", // copy left, device standing off the right edge
    deviceW: 372,
    deviceTop: 54,
    deviceLeft: 742,
    padX: 76,
    padTop: 62,
    logoSize: 44,
    logoText: 24,
    eyebrow: 15,
    h1: 50,
    sub: 20,
    proof: 19,
    statementBump: 1,
    statementProof: 1,
  },
  {
    id: "1200x1200",
    w: 1200,
    h: 1200,
    layout: "stack", // copy top, device bleeding off the bottom edge
    deviceW: 612,
    deviceTop: 556,
    padX: 84,
    padTop: 80,
    logoSize: 52,
    logoText: 28,
    eyebrow: 18,
    h1: 70,
    sub: 26,
    proof: 27,
    statementBump: 1.24,
    statementProof: 1.1,
  },
  {
    id: "1200x1500",
    w: 1200,
    h: 1500,
    layout: "stack",
    deviceW: 700,
    deviceTop: 636,
    padX: 88,
    padTop: 96,
    logoSize: 58,
    logoText: 31,
    eyebrow: 19,
    h1: 82,
    sub: 29,
    proof: 30,
    statementBump: 1.46,
    statementProof: 1.24,
  },
];

// One concept per claim, so the campaign learns which claim pulls rather than
// which crop of the same claim pulls.
//
// `wide` is the landscape wording -- a wide canvas fits a longer line than a
// stacked one. Every headline is deliberately two lines in both forms: a
// one-line headline would shift everything below it and break the shared
// rhythm. `sub` is held to two rendered lines for the same reason.
//
// KEEP EACH `wide` LINE UNDER ~27 CHARACTERS. The landscape copy column is
// 622px at 50px/800, so a longer line wraps and silently makes a THREE-line
// headline -- which pushes the sub down and breaks the rhythm against every
// other landscape in the set. `wide` may equal `headline` when the claim does
// not have a longer form worth writing; it is there to allow a longer line,
// not to require one.
//
// Concept 03 carries no device on purpose. A screenshot cannot show the absence
// of a permission, so the claim itself is the creative -- and a set of four
// near-identical phone shots reads as one blurred rectangle at thumbnail size.
const CONCEPTS = [
  {
    id: "01-automatic",
    file: "home-01-top.png",
    offset: 0,
    eyebrow: "Automatic",
    headline: "Every rupee\ntracked.",
    wide: "Every rupee tracked.\nZero typing.",
    sub: "Budgetify reads the bank SMS you already get and files\neach transaction itself.",
  },
  {
    id: "02-reads-sms",
    file: "txn-detail-01.png",
    offset: 96,
    eyebrow: "How it works",
    headline: "It reads\nyour bank SMS.",
    wide: "It reads your bank SMS.\nYou do nothing.",
    sub: "Amount, payee and account — lifted straight from\nthe bank's own message.",
  },
  {
    id: "03-no-internet",
    eyebrow: "Private by design",
    headline: "No internet\npermission.",
    wide: "No internet permission.\nNone. At all.",
    sub: "Not a promise in a policy document — a line the release\nbuild does not contain.",
    proof: [
      "Your money data cannot leave the phone",
      "No account, no cloud, no sign-up",
      "No ads, no analytics, no trackers",
      "Works fully in airplane mode",
    ],
  },
  {
    id: "04-where-it-went",
    file: "budgets-jul-01.png",
    offset: 560,
    eyebrow: "Budgets",
    headline: "See where\nit actually went.",
    wide: "See where it actually went.\nEvery month.",
    sub: "Category budgets, your daily pace, and the merchants\ntaking the most.",
  },
  // No overlay at all -- Google draws its own headline, app icon and Install
  // button over the creative, and its guidance is to supply at least one
  // untexted image per ratio so there is something that does not fight that
  // chrome. The only words in this one are the app's own UI.
  {
    id: "05-product",
    plain: true,
    file: "home-01-top.png",
    offset: 0,
    // The wide canvas gets a second screen rather than one lonely phone.
    fileWide: "budgets-jul-01.png",
    offsetWide: 560,
  },

  // 06-08 exist to fill the ad group to Google's cap of 20 images. They render
  // in SOME ratios only (`ratios`), because 5 concepts x 3 ratios is already 15
  // and three more full sets would be 24. The split favours landscape and
  // square: landscape draws the most Display inventory and square dominates
  // Discover and mobile feeds, while portrait is the one Google treats as
  // optional. Final spread is 7 landscape / 7 square / 6 portrait.
  //
  // Claims here are lifted from the Play Store screenshot builder next door, so
  // the ads and the store listing make the same promises in the same words.
  {
    id: "06-recurring",
    file: "recurring-01.png",
    offset: 0,
    ratios: ["1200x628", "1200x1200"],
    eyebrow: "Recurring",
    headline: "Nothing bills you\nby surprise.",
    wide: "Nothing bills you\nby surprise.",
    sub: "Budgetify spots repeating payments on its own and nudges\nyou before each one is due.",
  },
  {
    id: "07-your-language",
    file: "localisation-hindi.png",
    offset: 0,
    ratios: ["1200x628", "1200x1500"],
    eyebrow: "Six languages",
    headline: "Budgetify speaks\nyour language.",
    wide: "Budgetify speaks\nyour language.",
    sub: "Every screen, category and insight — in English, Hindi,\nMarathi, Bengali, Telugu or Tamil.",
  },
  {
    id: "08-net-worth",
    file: "networth-01.png",
    offset: 0,
    ratios: ["1200x1200"],
    eyebrow: "Net worth",
    headline: "Watch your net worth\ncompound.",
    // Square-only today, so this never renders -- kept inside the 27-char rule
    // anyway, so switching the ratio on later is a one-line change.
    wide: "Watch your net worth\ncompound.",
    sub: "Track what you own against what you owe, then project\nwhere your savings rate leads.",
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

const LOGO_URI = dataUri(LOGO, "image/png");

const esc = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// A gold tick drawn as a glyph-free path, so it renders identically without
// depending on an icon font being present.
const TICK = (px) =>
  `<svg width="${px}" height="${px}" viewBox="0 0 24 24" fill="none">
     <circle cx="12" cy="12" r="11" stroke="#C8A75E" stroke-width="1.6" opacity=".55"/>
     <path d="M7 12.4l3.3 3.3L17 9" stroke="#C8A75E" stroke-width="2.2"
           stroke-linecap="round" stroke-linejoin="round"/>
   </svg>`;

// The untexted concept: device art on the brand ground, nothing else. Two
// screens side by side on the wide canvas, one large screen on the tall ones.
function plainPage(concept, r) {
  const wide = r.layout === "side";
  // 340 is the narrowest the wide pair can be and still have the SECOND panel
  // reach the bottom edge: that capture is scrolled 560px in, so it runs out
  // sooner than the first, and any panel that stops short of the canvas reads
  // as a rendering bug rather than a crop.
  const deviceW = wide ? 340 : Math.round(r.w * 0.58);
  const scale = deviceW / SRC_W;
  const scaledH = Math.round(SRC_H * scale);
  const top = wide ? 44 : Math.round(r.h * 0.11);
  const shots = wide
    ? [
        { file: concept.file, offset: concept.offset ?? 0 },
        { file: concept.fileWide, offset: concept.offsetWide ?? 0 },
      ]
    : [{ file: concept.file, offset: concept.offset ?? 0 }];

  const panels = shots
    .map(
      (s) => `<div class="device"><img src="${dataUri(join(CAPS, s.file), "image/png")}"
      style="margin-top:${-Math.round(s.offset * scale)}px"></div>`,
    )
    .join("\n");

  return `<!doctype html><html><head><meta charset="utf-8"><style>
${FACES}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${r.w}px;height:${r.h}px;overflow:hidden}
body{
  font-family:Manrope,sans-serif;
  background:
    radial-gradient(${Math.round(r.w * 0.92)}px ${Math.round(r.h * 0.95)}px at 50% 106%, rgba(200,167,94,.32), transparent 63%),
    radial-gradient(${Math.round(r.w * 0.62)}px ${Math.round(r.h * 0.8)}px at 8% -8%, rgba(74,88,132,.34), transparent 66%),
    linear-gradient(168deg,#1a2036 0%,#141a2b 42%,#0b0e18 100%);
}
.stage{
  position:absolute;top:${top}px;left:0;right:0;
  display:flex;justify-content:center;align-items:flex-start;
  gap:${wide ? 34 : 0}px;
}
.device{
  width:${deviceW}px;height:${r.h - top + 40}px;
  border-radius:${Math.round(deviceW * 0.054)}px ${Math.round(deviceW * 0.054)}px 0 0;
  overflow:hidden;
  border:1.5px solid rgba(200,167,94,.42);
  border-bottom:none;
  box-shadow:
    0 -2px 0 rgba(255,255,255,.06) inset,
    0 34px 78px rgba(0,0,0,.55),
    0 0 110px rgba(200,167,94,.10);
}
.device img{display:block;width:${deviceW}px;height:${scaledH}px}
</style></head><body>
<div class="stage">
${panels}
</div>
</body></html>`;
}

function page(concept, r) {
  if (concept.plain) return plainPage(concept, r);
  const hasDevice = Boolean(concept.file);
  const scale = r.deviceW / SRC_W;
  const scaledH = Math.round(SRC_H * scale);
  const deviceLeft =
    r.layout === "side" ? r.deviceLeft : Math.round((r.w - r.deviceW) / 2);
  const headline = r.layout === "side" ? concept.wide : concept.headline;
  // The warm rise sits behind the device, so it follows the device across
  // layouts instead of being pinned to one corner of the canvas. With no
  // device it centres, and the statement sits inside the glow.
  const glowX = !hasDevice ? "50%" : r.layout === "side" ? "82%" : "50%";
  // The statement concept has no device to sit beside, so its copy column may
  // use the full width on landscape.
  const copyW =
    r.layout === "side" && hasDevice ? r.deviceLeft - r.padX - 44 : null;

  // With no device to occupy the lower canvas, the statement concept has to
  // carry the frame on type alone. It gets a larger headline than the device
  // concepts -- nothing is competing with it for attention -- and the warm
  // rise at the foot closes the composition instead of a phone. Pinning the
  // proof list to the bottom edge was tried first and opened a dead band
  // across the middle, which is worse than ending high on a full frame.
  const statement = !hasDevice;
  const h1Size = Math.round(r.h1 * (statement ? r.statementBump : 1));
  const proofSize = Math.round(r.proof * (statement ? r.statementProof : 1));
  // The taller the canvas, the less a headline and a checklist fill it. On the
  // stacked canvases the statement closes on the app's own motto -- real copy,
  // lifted from lib/l10n/app_strings.dart, not a line written for an ad.
  const footer =
    statement && r.layout === "stack"
      ? `<div class="footer">Your money, beautifully tracked.</div>`
      : "";

  const proof = concept.proof
    ? `<ul class="proof">${concept.proof
        .map((p) => `<li>${TICK(proofSize)}<span>${esc(p)}</span></li>`)
        .join("")}</ul>`
    : "";

  const device = hasDevice
    ? `<div class="device"><img src="${dataUri(join(CAPS, concept.file), "image/png")}"></div>`
    : "";

  return `<!doctype html><html><head><meta charset="utf-8"><style>
${FACES}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${r.w}px;height:${r.h}px;overflow:hidden}
body{
  font-family:Manrope,sans-serif;
  background:
    radial-gradient(${Math.round(r.w * 0.9)}px ${Math.round(r.h * 0.95)}px at ${glowX} 106%, rgba(200,167,94,.30), transparent 62%),
    radial-gradient(${Math.round(r.w * 0.62)}px ${Math.round(r.h * 0.8)}px at 8% -8%, rgba(74,88,132,.34), transparent 66%),
    linear-gradient(168deg,#1a2036 0%,#141a2b 42%,#0b0e18 100%);
  position:relative;
}

/* ONE flow column: wordmark, eyebrow, rule, headline, sub, proof.
   Every gap below is a multiple of this ratio's own type scale, so the
   rhythm holds no matter how long the eyebrow or headline runs. */
.copy{
  position:absolute;top:${r.padTop}px;left:${r.padX}px;
  ${copyW ? `width:${copyW}px;` : `right:${r.padX}px;`}
}
.brand{
  display:flex;align-items:center;gap:${Math.round(r.logoSize * 0.31)}px;
  margin-bottom:${Math.round(r.logoSize * GAP)}px;
}
.brand img{
  width:${r.logoSize}px;height:${r.logoSize}px;
  border-radius:${Math.round(r.logoSize * 0.24)}px;display:block;
}
.brand span{
  font-weight:800;font-size:${r.logoText}px;letter-spacing:-.018em;color:#fff;
}
.eyebrow{
  font-weight:700;font-size:${r.eyebrow}px;letter-spacing:.30em;
  text-transform:uppercase;color:#C8A75E;line-height:1;
}
.rule{
  width:${Math.round(r.h * 0.045)}px;height:${r.h > 800 ? 4 : 3}px;
  background:#C8A75E;border-radius:2px;
  margin:${Math.round(r.eyebrow * 1.0)}px 0 ${Math.round(r.eyebrow * 1.15)}px;
}
h1{
  font-weight:800;font-size:${h1Size}px;line-height:1.05;letter-spacing:-.030em;
  color:#fff;white-space:pre-line;
}
.sub{
  margin-top:${Math.round(r.sub * 0.92)}px;font-weight:500;font-size:${r.sub}px;
  line-height:1.42;color:#9aa4ba;white-space:pre-line;
}
.proof{
  list-style:none;margin-top:${Math.round(proofSize * 2.05)}px;
  display:flex;flex-direction:column;gap:${Math.round(proofSize * 0.86)}px;
}
.proof li{
  display:flex;align-items:center;gap:${Math.round(proofSize * 0.62)}px;
  font-weight:500;font-size:${Math.round(proofSize * 1.06)}px;color:#e8ecf5;
}
.proof svg{flex:none;display:block}
.footer{
  position:absolute;bottom:${r.padTop}px;left:${r.padX}px;right:${r.padX}px;
  padding-top:${Math.round(r.sub * 1.05)}px;
  border-top:1px solid rgba(200,167,94,.28);
  font-weight:700;font-size:${Math.round(r.sub * 1.02)}px;letter-spacing:.01em;
  color:#C8A75E;
}

.device{
  position:absolute;top:${r.deviceTop}px;left:${deviceLeft}px;
  width:${r.deviceW}px;height:${r.h - r.deviceTop + 40}px;
  border-radius:${Math.round(r.deviceW * 0.054)}px ${Math.round(r.deviceW * 0.054)}px 0 0;
  overflow:hidden;
  border:1.5px solid rgba(200,167,94,.42);
  border-bottom:none;
  box-shadow:
    0 -2px 0 rgba(255,255,255,.06) inset,
    0 34px 78px rgba(0,0,0,.55),
    0 0 110px rgba(200,167,94,.10);
}
.device img{
  display:block;width:${r.deviceW}px;height:${scaledH}px;
  margin-top:${-Math.round((concept.offset ?? 0) * scale)}px;
}
</style></head><body>
<div class="copy">
  <div class="head">
    <div class="brand"><img src="${LOGO_URI}"><span>Budgetify</span></div>
    <div class="eyebrow">${esc(concept.eyebrow)}</div>
    <div class="rule"></div>
    <h1>${esc(headline)}</h1>
    <div class="sub">${esc(concept.sub)}</div>
  </div>
  ${proof}
</div>
${device}
${footer}
</body></html>`;
}

mkdirSync(OUT, { recursive: true });
const tmp = mkdtempSync(join(tmpdir(), "budgetify-ads-"));
let n = 0;

for (const concept of CONCEPTS) {
  if (concept.file && !existsSync(join(CAPS, concept.file))) {
    console.error(`missing capture: ${join(CAPS, concept.file)}`);
    process.exit(1);
  }
  for (const r of RATIOS) {
    // A concept with no `ratios` renders in all three.
    if (concept.ratios && !concept.ratios.includes(r.id)) continue;
    const out = `${concept.id}-${r.id}.png`;
    const html = join(tmp, out.replace(/\.png$/, ".html"));
    writeFileSync(html, page(concept, r));
    execFileSync(
      CHROME,
      [
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--force-device-scale-factor=1",
        `--window-size=${r.w},${r.h}`,
        `--screenshot=${join(OUT, out)}`,
        `file://${html}`,
      ],
      { stdio: "ignore" },
    );
    console.log(`${out}  <-  ${concept.file ?? "statement"}`);
    n++;
  }
}
console.log(`\n${n} ad images in ${OUT}`);
