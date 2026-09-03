// Play Store feature graphic (1024x500) -- three variants to choose between.
//
//   node build-feature-graphic.mjs
//
// This is the single highest-traffic image the brand has: Play puts it at the
// top of the store listing, AND a Google App campaign pulls it into ad
// placements automatically -- which is why an App campaign preview shows a
// banner before a single image asset has been uploaded. It is ad creative
// whether or not you treat it as such.
//
// Replaces a version that used the WRONG LOGO (a generic card glyph in a
// circle, not the app's wallet-and-sprout mark) over a stock-looking gold bar
// chart. The chart was the real problem: rising bars say "finance app" the way
// clip-art says "business", and it showed nothing this app does.
//
// THEME IS TAKEN FROM THE APP, NOT EYEBALLED. Every colour is a real token out
// of lib/providers/theme_provider.dart:
//   gold #C8A75E · goldDeep #A8843C · heroGradient #23273A -> #131520
//   dark.background #0A0B0E · dark.text #F2F2EF · dark.textSecondary #9A9DA6
//
// PLAY CROPPING: Play may overlay a play button dead centre when a promo video
// is attached, and crops edges on some surfaces. Nothing load-bearing sits in
// the centre band or within ~50px of an edge, in any variant.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const FONTS = resolve(HERE, "../../assets/fonts");
const LOGO = resolve(HERE, "../../assets/branding/logo.png");
const CAPS = join(HERE, "captures");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const W = 1024, H = 500;
const SRC_W = 1080, SRC_H = 2424;

// Which variant is copied to feature-graphic.png -- the file you upload.
// Change this one word to switch; all three are always rendered.
//
// "product" is the default because the feature graphic is frequently shown
// SMALL, and it is the only one of the three that survives that: the device
// anchors the frame and the real UI stays legible as texture even when the
// type does not. "transform" makes the better argument -- it is the only one
// that explains the mechanism -- but its SMS body copy is unreadable at
// thumbnail size, which is where the graphic does most of its work.
const CHOSEN = "product";

const dataUri = (p, m) => "data:" + m + ";base64," + readFileSync(p).toString("base64");
const shot = (f) => dataUri(join(CAPS, f), "image/png");
const face = (w, f) => "@font-face{font-family:Manrope;font-weight:" + w +
  ";font-style:normal;src:url(" + dataUri(join(FONTS, f), "font/ttf") + ') format("truetype");}';

const TICK = (px) => '<svg width="' + px + '" height="' + px + '" viewBox="0 0 24 24" fill="none">' +
  '<circle cx="12" cy="12" r="11" stroke="#C8A75E" stroke-width="1.7" opacity=".6"/>' +
  '<path d="M7 12.4l3.3 3.3L17 9" stroke="#C8A75E" stroke-width="2.4" ' +
  'stroke-linecap="round" stroke-linejoin="round"/></svg>';

const CLAIMS = [
  "100% offline — no internet permission",
  "Auto-tracks your bank & UPI SMS",
  "No ads. No cloud. No sign-up.",
];

const LOCKUP = (nameSize) =>
  '<div class="brand"><img src="' + dataUri(LOGO, "image/png") + '">' +
  '<div class="name" style="font-size:' + nameSize + 'px">Budgetify</div></div>';

const BASE = `
:root{
  --gold:#C8A75E; --gold-deep:#A8843C;
  --hero-top:#23273A; --hero-bottom:#131520; --ink:#0A0B0E;
  --text:#F2F2EF; --dim:#9A9DA6;
}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:${W}px;height:${H}px;overflow:hidden}
body{
  font-family:Manrope,sans-serif;color:var(--text);
  background:
    radial-gradient(760px 520px at 78% 108%, rgba(200,167,94,.28), transparent 64%),
    radial-gradient(520px 380px at 6% -12%, rgba(74,88,132,.34), transparent 68%),
    linear-gradient(168deg,var(--hero-top) 0%,var(--hero-bottom) 46%,var(--ink) 100%);
  display:flex;align-items:center;gap:44px;padding:0 56px;
}
.brand{display:flex;align-items:center;gap:15px}
.brand img{width:56px;height:56px;border-radius:14px;display:block}
.brand .name{font-weight:800;letter-spacing:-.026em;line-height:1}
.tagline{
  margin-top:13px;font-weight:700;font-size:12px;letter-spacing:.24em;
  text-transform:uppercase;color:var(--gold);
}
.rule{width:52px;height:3px;background:var(--gold);border-radius:2px;margin:15px 0 19px}
.claims{list-style:none;display:flex;flex-direction:column;gap:13px}
.claims li{display:flex;align-items:center;gap:11px;font-weight:500;font-size:16px}
.claims svg{flex:none;display:block}
.device{
  border:1.5px solid rgba(200,167,94,.42);border-radius:22px;overflow:hidden;
  box-shadow:0 26px 60px rgba(0,0,0,.55), 0 0 90px rgba(200,167,94,.09);
}
.device img{display:block}
`;

const VARIANTS = [
  // ------------------------------------------------------------------ A
  // The app's own story: the bank SMS everyone in India already gets, becoming
  // a categorised row. Shows the product in one glance without a screenshot.
  {
    id: "transform",
    css: `
.left{width:452px;flex:none}
.flow{flex:1;display:flex;flex-direction:column;gap:15px}
.sms{background:#191d2b;border:1px solid rgba(255,255,255,.08);
     border-radius:16px 16px 16px 5px;padding:17px 19px}
.sms .from{font-weight:700;font-size:10px;letter-spacing:.16em;text-transform:uppercase;
           color:#6f7b95;margin-bottom:6px}
.sms .body{font-weight:500;font-size:15.5px;line-height:1.5;color:#c3cbdb}
.sms .body b{font-weight:800;color:#fff}
.arrow{display:flex;align-items:center;justify-content:center;gap:9px}
.arrow .line{height:1px;flex:1;background:linear-gradient(90deg,transparent,rgba(200,167,94,.5))}
.arrow .line.r{background:linear-gradient(90deg,rgba(200,167,94,.5),transparent)}
.arrow .label{font-weight:700;font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--gold)}
.row{display:flex;align-items:center;gap:13px;
     background:linear-gradient(180deg,#1d2233,#171b28);
     border:1px solid rgba(200,167,94,.34);border-radius:16px;padding:17px 19px;
     box-shadow:0 14px 34px rgba(0,0,0,.45), 0 0 44px rgba(200,167,94,.09)}
.row .dot{width:42px;height:42px;border-radius:13px;flex:none;
          background:rgba(200,167,94,.14);border:1px solid rgba(200,167,94,.3);
          display:flex;align-items:center;justify-content:center;font-size:20px}
.row .who{flex:1;min-width:0}
.row .who .n{font-weight:800;font-size:19px;line-height:1.2}
.row .who .m{font-weight:500;font-size:11.5px;color:#8d97ad;margin-top:3px}
.row .amt{font-weight:800;font-size:21px;color:#F08A8A;white-space:nowrap}`,
    body: `
<div class="left">
  ${LOCKUP(42)}
  <div class="tagline">Your money, beautifully tracked</div>
  <div class="rule"></div>
  <ul class="claims">${CLAIMS.map((c) => "<li>" + TICK(17) + "<span>" + c + "</span></li>").join("")}</ul>
</div>
<div class="flow">
  <div class="sms">
    <div class="from">AD-ICICIB</div>
    <div class="body">Rs <b>450.00</b> debited from A/c XX3417 on 18-Jul at <b>SWIGGY</b>. Avl bal Rs 12,304.55</div>
  </div>
  <div class="arrow"><div class="line"></div><div class="label">Read automatically</div><div class="line r"></div></div>
  <div class="row">
    <div class="dot">🍔</div>
    <div class="who"><div class="n">Swiggy</div><div class="m">Food &amp; Dining · auto-tracked from SMS</div></div>
    <div class="amt">−₹450</div>
  </div>
</div>`,
  },

  // ------------------------------------------------------------------ B
  // Product-forward: two real screens off a seeded emulator. The safest kind of
  // feature graphic -- it shows what you actually get, with no illustration to
  // mistrust.
  {
    id: "product",
    css: `
.left{width:560px;flex:none}
.left h1{font-weight:800;font-size:40px;line-height:1.08;letter-spacing:-.03em;margin-top:16px}
/* ONE screen, not two. At 1024x500 a two-up needs each phone under ~223px
   wide, and below that the scaled capture is SHORTER than the canvas -- the
   device frame then shows empty ground under the screenshot, which reads as a
   broken image. One phone at 250px is 561px tall, so it bleeds off the bottom
   the way the ad images do. */
.screens{flex:1;display:flex;align-items:flex-start;justify-content:flex-end}
.screens .device{width:250px;height:${H - 30}px;border-bottom:none;border-radius:22px 22px 0 0}
.screens .device img{width:250px;height:${Math.round(SRC_H * (250 / SRC_W))}px}`,
    body: `
<div class="left">
  ${LOCKUP(34)}
  <h1>Every rupee tracked.<br>Zero typing.</h1>
  <div class="rule"></div>
  <ul class="claims">${CLAIMS.slice(0, 2).map((c) => "<li>" + TICK(17) + "<span>" + c + "</span></li>").join("")}</ul>
</div>
<div class="screens">
  <div class="device"><img src="${shot("home-01-top.png")}"></div>
</div>`,
  },

  // ------------------------------------------------------------------ C
  // The campaign's "Zero" idea, so the store page and the video ads argue the
  // same thing in the same words. Every number on it is zero.
  {
    id: "zero",
    css: `
.left{width:486px;flex:none}
.left h1{font-weight:800;font-size:40px;line-height:1.08;letter-spacing:-.03em;margin-top:16px}
.left .note{margin-top:16px;display:flex;align-items:center;gap:10px;
            font-weight:500;font-size:15px;color:var(--dim)}
.grid{flex:1;display:grid;grid-template-columns:1fr 1fr;gap:16px}
.cell{border:1px solid rgba(200,167,94,.34);border-radius:16px;
      background:rgba(200,167,94,.06);padding:22px 24px}
.cell b{display:block;font-weight:800;font-size:48px;line-height:1;color:var(--gold)}
.cell span{display:block;margin-top:5px;font-weight:500;font-size:14px;color:var(--text)}`,
    body: `
<div class="left">
  ${LOCKUP(34)}
  <div class="tagline">Your money, beautifully tracked</div>
  <h1>Your money never<br>leaves your phone.</h1>
  <div class="rule"></div>
  <div class="note">${TICK(17)}<span>100% offline — no internet permission</span></div>
</div>
<div class="grid">
  <div class="cell"><b>0</b><span>sign-ups</span></div>
  <div class="cell"><b>0</b><span>servers</span></div>
  <div class="cell"><b>0</b><span>trackers</span></div>
  <div class="cell"><b>0</b><span>ads</span></div>
</div>`,
  },
];

const tmp = mkdtempSync(join(tmpdir(), "budgetify-fg-"));
for (const v of VARIANTS) {
  const page = '<!doctype html><html><head><meta charset="utf-8"><style>' +
    [face(500, "manrope-500.ttf"), face(700, "manrope-700.ttf"), face(800, "manrope-800.ttf")].join("\n") +
    BASE + v.css + "</style></head><body>" + v.body + "</body></html>";
  const f = join(tmp, v.id + ".html");
  writeFileSync(f, page);
  const out = join(HERE, "feature-graphic-" + v.id + ".png");
  execFileSync(CHROME, ["--headless", "--disable-gpu", "--hide-scrollbars",
    "--force-device-scale-factor=1", `--window-size=${W},${H}`,
    "--screenshot=" + out, "file://" + f], { stdio: "ignore" });
  console.log("feature-graphic-" + v.id + ".png  " + W + "x" + H);
}
copyFileSync(join(HERE, "feature-graphic-" + CHOSEN + ".png"), join(HERE, "feature-graphic.png"));
console.log("\nfeature-graphic.png  <-  " + CHOSEN + "  (the one to upload)");
