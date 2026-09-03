// Generate the 1920x1080 background plates the 16:9 videos are composited onto.
//
//   node build-video-plates.mjs
//
// WHY A PLATE INSTEAD OF A CROP OR A LETTERBOX. The launch film is natively
// 1080x1920. Letterboxing it into 16:9 leaves two-thirds of the frame as empty
// bars, and a centre crop severs the captions, which sit low in nearly every
// beat. Re-animating the whole film for a landscape canvas is a rebuild, not an
// export.
//
// So the 16:9 asset is a DESIGNED landscape frame: brand copy holds the left,
// and the untouched 9:16 film plays inside a bordered panel on the right. The
// film is never cropped or squeezed -- it keeps its own aspect ratio, and the
// space beside it does real work instead of sitting black.
//
// The slot geometry here is the contract with build-ad-videos.sh. If SLOT_*
// changes, change it there too.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "plates");
const FONTS = resolve(HERE, "../../assets/fonts");
const LOGO = resolve(HERE, "../../assets/branding/logo.png");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const W = 1920;
const H = 1080;

// The video slot. 9:16 at 980 tall is 551.25 wide -> 552, kept even because
// H.264 chroma subsampling needs even dimensions.
export const SLOT_H = 980;
export const SLOT_W = 552;
export const SLOT_X = 1208;
export const SLOT_Y = 50;

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

const TICK = `<svg width="26" height="26" viewBox="0 0 24 24" fill="none">
  <circle cx="12" cy="12" r="11" stroke="#C8A75E" stroke-width="1.6" opacity=".55"/>
  <path d="M7 12.4l3.3 3.3L17 9" stroke="#C8A75E" stroke-width="2.2"
        stroke-linecap="round" stroke-linejoin="round"/>
</svg>`;

// One plate per story. The copy has to hold for the WHOLE cut, since it is
// static while the film plays beside it -- so it states the campaign's claim
// rather than narrating whichever beat is on screen.
const PLATES = [
  {
    id: "product",
    eyebrow: "Automatic",
    headline: "Every rupee tracked.\nZero typing.",
    claims: [
      "Reads your bank & UPI SMS for you",
      "Budgets, net worth, recurring bills",
      "No account. No cloud. No ads.",
    ],
  },
  {
    id: "privacy",
    eyebrow: "Private by design",
    headline: "No internet\npermission.",
    claims: [
      "Your money data cannot leave the phone",
      "No sign-up, no servers, no trackers",
      "Works fully in airplane mode",
    ],
  },
];

const page = (p) => `<!doctype html><html><head><meta charset="utf-8"><style>
${FACES}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden}
body{
  font-family:Manrope,sans-serif;
  background:
    radial-gradient(900px 900px at 68% 106%, rgba(200,167,94,.30), transparent 62%),
    radial-gradient(700px 620px at 4% -10%, rgba(74,88,132,.34), transparent 66%),
    linear-gradient(168deg,#1a2036 0%,#141a2b 42%,#0b0e18 100%);
  position:relative;
}
/* Same one-flow column as the still ad images, so a landscape video frame and
   a landscape image asset share a rhythm. */
.copy{position:absolute;left:132px;top:50%;transform:translateY(-50%);width:960px}
.brand{display:flex;align-items:center;gap:22px;margin-bottom:76px}
.brand img{width:72px;height:72px;border-radius:18px;display:block}
.brand span{font-weight:800;font-size:40px;letter-spacing:-.022em;color:#fff}
.eyebrow{
  font-weight:700;font-size:21px;letter-spacing:.30em;text-transform:uppercase;
  color:#C8A75E;line-height:1;
}
.rule{width:68px;height:4px;background:#C8A75E;border-radius:2px;margin:22px 0 26px}
h1{
  font-weight:800;font-size:92px;line-height:1.05;letter-spacing:-.030em;
  color:#fff;white-space:pre-line;
}
.claims{list-style:none;margin-top:52px;display:flex;flex-direction:column;gap:22px}
.claims li{display:flex;align-items:center;gap:17px;font-weight:500;font-size:27px;color:#e8ecf5}
.claims svg{flex:none;display:block}

/* The panel the film is composited into. Drawn as a border box whose INNER
   area is exactly SLOT_W x SLOT_X -- build-ad-videos.sh overlays there. */
.slot{
  position:absolute;left:${SLOT_X - 2}px;top:${SLOT_Y - 2}px;
  width:${SLOT_W + 4}px;height:${SLOT_H + 4}px;
  border:2px solid rgba(200,167,94,.45);
  background:#05070d;
  box-shadow:0 40px 90px rgba(0,0,0,.55), 0 0 130px rgba(200,167,94,.12);
}
</style></head><body>
<div class="copy">
  <div class="brand"><img src="${dataUri(LOGO, "image/png")}"><span>Budgetify</span></div>
  <div class="eyebrow">${p.eyebrow}</div>
  <div class="rule"></div>
  <h1>${p.headline}</h1>
  <ul class="claims">
    ${p.claims.map((c) => `<li>${TICK}<span>${c}</span></li>`).join("\n    ")}
  </ul>
</div>
<div class="slot"></div>
</body></html>`;

mkdirSync(OUT, { recursive: true });
const tmp = mkdtempSync(join(tmpdir(), "budgetify-plate-"));
for (const p of PLATES) {
  const f = join(tmp, `${p.id}.html`);
  writeFileSync(f, page(p));
  execFileSync(
    CHROME,
    [
      "--headless",
      "--disable-gpu",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      `--window-size=${W},${H}`,
      `--screenshot=${join(OUT, `plate-${p.id}.png`)}`,
      `file://${f}`,
    ],
    { stdio: "ignore" },
  );
  console.log(`plates/plate-${p.id}.png  ${W}x${H}`);
}
