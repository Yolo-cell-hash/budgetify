// Compose the Play Store feature graphic (1024x500).
//
//   node build-feature-graphic.mjs
//
// This is the single highest-traffic image the brand has: Play shows it at the
// top of the store listing, and a Google App campaign pulls it into ad
// placements automatically -- which is why an App campaign preview shows a
// banner before you have uploaded a single image asset. Fixing it here fixes
// both surfaces at once.
//
// Replaces a version that used the WRONG LOGO (a generic card glyph, not the
// app's wallet-and-sprout mark) over a stock-looking gold bar chart. The chart
// was the real problem: a rising-bars illustration says "finance app" the way
// clip-art says "business", and it showed nothing this app actually does.
//
// What replaced it is the app's own story -- the bank SMS everyone in India
// already gets, becoming a categorised row. That is the product in one glance,
// and the SMS text and parsed row are the same ones the launch film uses.
//
// PLAY CROPPING: Play may overlay a play button dead centre when a promo video
// is attached, and crops the edges on some surfaces. Nothing load-bearing sits
// in the centre band or within ~50px of any edge.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "feature-graphic.png");
const FONTS = resolve(HERE, "../../assets/fonts");
const LOGO = resolve(HERE, "../../assets/branding/logo.png");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const W = 1024;
const H = 500;

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

const TICK = `<svg width="17" height="17" viewBox="0 0 24 24" fill="none">
  <circle cx="12" cy="12" r="11" stroke="#C8A75E" stroke-width="1.7" opacity=".6"/>
  <path d="M7 12.4l3.3 3.3L17 9" stroke="#C8A75E" stroke-width="2.4"
        stroke-linecap="round" stroke-linejoin="round"/>
</svg>`;

// The three claims from the previous graphic, kept because all three are true
// and all three are the reason someone picks this app.
const CLAIMS = [
  "100% offline — no internet permission",
  "Auto-tracks your bank & UPI SMS",
  "No ads. No cloud. No sign-up.",
];

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
${FACES}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden}
body{
  font-family:Manrope,sans-serif;
  background:
    radial-gradient(760px 520px at 78% 108%, rgba(200,167,94,.30), transparent 64%),
    radial-gradient(520px 380px at 6% -12%, rgba(74,88,132,.36), transparent 68%),
    linear-gradient(168deg,#1a2036 0%,#141a2b 44%,#0b0e18 100%);
  display:flex;align-items:center;gap:44px;padding:0 56px;
}

/* ---- left: the brand lockup and the three claims ---- */
.left{width:452px;flex:none}
.brand{display:flex;align-items:center;gap:15px}
.brand img{width:56px;height:56px;border-radius:14px;display:block}
.brand .name{font-weight:800;font-size:42px;letter-spacing:-.026em;color:#fff;line-height:1}
.tagline{
  margin-top:13px;font-weight:700;font-size:12px;letter-spacing:.24em;
  text-transform:uppercase;color:#C8A75E;
}
.rule{width:52px;height:3px;background:#C8A75E;border-radius:2px;margin:15px 0 19px}
.claims{list-style:none;display:flex;flex-direction:column;gap:13px}
.claims li{
  display:flex;align-items:center;gap:11px;
  font-weight:500;font-size:16px;color:#e8ecf5;
}
.claims svg{flex:none;display:block}

/* ---- right: one bank SMS becoming one tracked row ---- */
.flow{flex:1;display:flex;flex-direction:column;align-items:stretch;gap:11px}
.sms{
  background:#191d2b;border:1px solid rgba(255,255,255,.08);
  border-radius:14px 14px 14px 4px;padding:13px 15px;
}
.sms .from{
  font-weight:700;font-size:10px;letter-spacing:.16em;text-transform:uppercase;
  color:#6f7b95;margin-bottom:6px;
}
.sms .body{font-weight:500;font-size:14px;line-height:1.45;color:#c3cbdb}
.sms .body b{font-weight:800;color:#fff}

.arrow{display:flex;align-items:center;justify-content:center;gap:9px}
.arrow .line{height:1px;flex:1;background:linear-gradient(90deg,transparent,rgba(200,167,94,.5))}
.arrow .line.r{background:linear-gradient(90deg,rgba(200,167,94,.5),transparent)}
.arrow .label{
  font-weight:700;font-size:10px;letter-spacing:.18em;text-transform:uppercase;
  color:#C8A75E;
}

.row{
  display:flex;align-items:center;gap:13px;
  background:linear-gradient(180deg,#1d2233,#171b28);
  border:1px solid rgba(200,167,94,.34);border-radius:14px;padding:13px 15px;
  box-shadow:0 14px 34px rgba(0,0,0,.45), 0 0 44px rgba(200,167,94,.09);
}
.row .dot{
  width:36px;height:36px;border-radius:11px;flex:none;
  background:rgba(200,167,94,.14);border:1px solid rgba(200,167,94,.3);
  display:flex;align-items:center;justify-content:center;font-size:17px;
}
.row .who{flex:1;min-width:0}
.row .who .n{font-weight:800;font-size:17px;color:#fff;line-height:1.2}
.row .who .m{font-weight:500;font-size:11.5px;color:#8d97ad;margin-top:3px}
.row .amt{font-weight:800;font-size:19px;color:#F08A8A;white-space:nowrap}
</style></head><body>

<div class="left">
  <div class="brand">
    <img src="${dataUri(LOGO, "image/png")}">
    <div class="name">Budgetify</div>
  </div>
  <div class="tagline">Your money, beautifully tracked</div>
  <div class="rule"></div>
  <ul class="claims">
    ${CLAIMS.map((c) => `<li>${TICK}<span>${c}</span></li>`).join("\n    ")}
  </ul>
</div>

<div class="flow">
  <div class="sms">
    <div class="from">AD-ICICIB</div>
    <div class="body">Rs <b>450.00</b> debited from A/c XX3417 on 18-Jul at
      <b>SWIGGY</b>. Avl bal Rs 12,304.55</div>
  </div>
  <div class="arrow">
    <div class="line"></div>
    <div class="label">Read automatically</div>
    <div class="line r"></div>
  </div>
  <div class="row">
    <div class="dot">🍔</div>
    <div class="who">
      <div class="n">Swiggy</div>
      <div class="m">Food &amp; Dining · auto-tracked from SMS</div>
    </div>
    <div class="amt">−₹450</div>
  </div>
</div>

</body></html>`;

const tmp = mkdtempSync(join(tmpdir(), "budgetify-fg-"));
const file = join(tmp, "fg.html");
writeFileSync(file, html);
execFileSync(
  CHROME,
  [
    "--headless",
    "--disable-gpu",
    "--hide-scrollbars",
    "--force-device-scale-factor=1",
    `--window-size=${W},${H}`,
    `--screenshot=${OUT}`,
    `file://${file}`,
  ],
  { stdio: "ignore" },
);
console.log(`${OUT}  ${W}x${H}`);
