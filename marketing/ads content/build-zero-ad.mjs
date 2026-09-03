// "Zero" -- an original 15s ad, animated and rendered from scratch.
//
//   node build-zero-ad.mjs [--fps 30] [--only 9x16]
//
// NOT a cut of the launch film. The film is a 58s brand piece with its own
// scene grammar; this is built as an ad from the first frame: one idea, four
// beats, and a layout that reflows NATIVELY into all three orientations rather
// than being cropped or composited into them.
//
// THE IDEA: every number in it is zero -- zero typed, zero sign-ups, zero
// servers, zero trackers, zero ads -- until the one number that is not, which
// is the money it tracked while you did nothing. That lands the automatic claim
// and the privacy claim on a single spine, which no cut of the film does.
//
// TIMING is on the film's grid: the score is 96 BPM, so a bar is 2.5s, and the
// four beats land at 0 / 5.0 / 10.0 / 12.5 -- all bar boundaries. The audio bed
// is the film's own opening 15s, so the ad sounds like the brand.
//
// DETERMINISM: nothing here uses CSS animations or the wall clock. The page
// exposes __seek(t) and every property is a pure function of t, so frame N is
// exactly t = N/fps and a re-render is byte-identical. That is what makes the
// output reproducible and the render resumable.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "video");
const WORK = join(tmpdir(), "budgetify-zero-frames");
const FONTS = resolve(HERE, "../../assets/fonts");
const LOGO = resolve(HERE, "../../assets/branding/logo.png");
const SHOT = resolve(HERE, "../playstore/captures/home-01-top.png");

const RENDER_ROOT = resolve(HERE, "../.render/node_modules");
const FF = join(RENDER_ROOT, "ffmpeg-static/ffmpeg");
const FILM = resolve(HERE, "../budgetify-launch-film-60fps.mp4");

const argv = process.argv.slice(2);
const arg = (k, d) => {
  const i = argv.indexOf(`--${k}`);
  return i >= 0 ? argv[i + 1] : d;
};
const FPS = Number(arg("fps", 30));
const ONLY = arg("only", null);
const DUR = 15;

const ORIENTATIONS = [
  { id: "9x16", w: 1080, h: 1920 },
  { id: "1x1", w: 1080, h: 1080 },
  { id: "16x9", w: 1920, h: 1080 },
].filter((o) => !ONLY || o.id === ONLY);

const dataUri = (p, mime) =>
  `data:${mime};base64,${readFileSync(p).toString("base64")}`;

const face = (w, f) =>
  "@font-face{font-family:Manrope;font-weight:" + w + ";font-style:normal;" +
  "src:url(" + dataUri(join(FONTS, f), "font/ttf") + ") format(\"truetype\");}";

// The page is assembled here so the fonts, logo and screenshot ride along as
// base64 -- a file:// page with external refs races the screenshot loop.
function html() {
  return [
    "<!doctype html><html><head><meta charset=\"utf-8\"><style>",
    face(500, "manrope-500.ttf"),
    face(700, "manrope-700.ttf"),
    face(800, "manrope-800.ttf"),
    `
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;overflow:hidden;background:#0b0e18}
body{font-family:Manrope,sans-serif;color:#fff}

/* One unit scale drives every size, so the same markup composes at 1080x1920,
   1080x1080 and 1920x1080 without a separate stylesheet per canvas. */
:root{--u:10px}

#bg{
  position:fixed;inset:0;
  background:
    radial-gradient(120vmax 90vmax at 50% 112%, rgba(200,167,94,.28), transparent 62%),
    radial-gradient(80vmax 70vmax at 6% -12%, rgba(74,88,132,.32), transparent 66%),
    linear-gradient(168deg,#1a2036 0%,#141a2b 44%,#0b0e18 100%);
}
.scene{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;opacity:0}
.pad{padding:0 calc(var(--u)*6)}

/* --- 1. the hook --- */
#s1{flex-direction:column}
#s1 .cap{
  max-width:86%;
  font-weight:700;font-size:calc(var(--u)*1.9);letter-spacing:.26em;
  text-transform:uppercase;color:#9aa4ba;text-align:center;
}
#s1 .zero{
  font-weight:800;font-size:calc(var(--u)*34);line-height:.92;color:#C8A75E;
  letter-spacing:-.04em;
}
#s1 .sub{
  max-width:88%;
  font-weight:800;font-size:calc(var(--u)*5.0);letter-spacing:-.02em;
  text-align:center;color:#fff;
}

/* --- 2. the proof --- */
#s2{gap:calc(var(--u)*5)}
#s2.port{flex-direction:column}
#s2 .words{max-width:calc(var(--u)*46)}
#s2.port .words{text-align:center;max-width:92%}
#s2 .eyebrow{
  font-weight:700;font-size:calc(var(--u)*1.7);letter-spacing:.28em;
  text-transform:uppercase;color:#C8A75E;
}
#s2 h2{
  font-weight:800;font-size:calc(var(--u)*4.2);line-height:1.08;
  letter-spacing:-.03em;margin-top:calc(var(--u)*1.6);
}
#s2 .phone{
  position:relative;width:calc(var(--u)*28);flex:none;
  border:1.5px solid rgba(200,167,94,.42);border-radius:calc(var(--u)*1.6);
  overflow:hidden;box-shadow:0 calc(var(--u)*3) calc(var(--u)*8) rgba(0,0,0,.55);
}
#s2 .phone img{display:block;width:100%}
/* The gold sweep is the "reading" gesture -- one pass, top to bottom. */
#s2 .scan{
  position:absolute;left:0;right:0;height:calc(var(--u)*9);
  background:linear-gradient(180deg,transparent,rgba(200,167,94,.30),transparent);
  border-bottom:2px solid rgba(200,167,94,.85);
}

/* --- 3. the zeros --- */
#s3{flex-direction:column;gap:calc(var(--u)*3.4)}
#s3 .lead{
  max-width:88%;
  font-weight:800;font-size:calc(var(--u)*5.6);letter-spacing:-.03em;text-align:center;
}
#s3 .chips{display:flex;flex-wrap:wrap;gap:calc(var(--u)*1.6);justify-content:center;max-width:88vw}
#s3 .chip{
  display:flex;align-items:baseline;gap:calc(var(--u)*.9);
  border:1px solid rgba(200,167,94,.38);border-radius:999px;
  padding:calc(var(--u)*1.1) calc(var(--u)*2.4);background:rgba(200,167,94,.07);
}
#s3 .chip b{font-weight:800;font-size:calc(var(--u)*3.4);color:#C8A75E}
#s3 .chip span{font-weight:500;font-size:calc(var(--u)*2.3);color:#e8ecf5}

/* --- 4. end card --- */
#s4{flex-direction:column}
#s4 img{width:calc(var(--u)*11);height:calc(var(--u)*11);border-radius:calc(var(--u)*2.6);display:block}
#s4 .name{font-weight:800;font-size:calc(var(--u)*7.5);letter-spacing:-.03em;margin-top:calc(var(--u)*2.4)}
#s4 .tag{
  font-weight:700;font-size:calc(var(--u)*1.8);letter-spacing:.22em;text-transform:uppercase;
  color:#C8A75E;margin-top:calc(var(--u)*1.2);text-align:center;
}
#s4 .cta{
  margin-top:calc(var(--u)*3.4);background:#C8A75E;color:#141a2b;
  font-weight:800;font-size:calc(var(--u)*2.3);
  padding:calc(var(--u)*1.5) calc(var(--u)*3.4);border-radius:999px;
}
</style></head><body>
<div id="bg"></div>

<div class="scene pad" id="s1">
  <div class="cap" id="s1cap">Transactions you typed last month</div>
  <div class="zero" id="s1zero">0</div>
  <div class="sub" id="s1sub">Budgetify read them instead.</div>
</div>

<div class="scene pad" id="s2">
  <div class="words">
    <div class="eyebrow">Automatic</div>
    <h2>It reads the bank SMS<br>you already get.</h2>
  </div>
  <div class="phone"><img src="` + dataUri(SHOT, "image/png") + `"><div class="scan" id="scan"></div></div>
</div>

<div class="scene pad" id="s3">
  <div class="lead" id="s3lead">And told nobody.</div>
  <div class="chips" id="chips">
    <div class="chip"><b>0</b><span>sign-ups</span></div>
    <div class="chip"><b>0</b><span>servers</span></div>
    <div class="chip"><b>0</b><span>trackers</span></div>
    <div class="chip"><b>0</b><span>ads</span></div>
  </div>
</div>

<div class="scene pad" id="s4">
  <img src="` + dataUri(LOGO, "image/png") + `">
  <div class="name">Budgetify</div>
  <div class="tag">Your money, beautifully tracked</div>
  <div class="cta">Get it free on Google Play</div>
</div>

<script>
var W = innerWidth, H = innerHeight, LAND = W > H * 1.2;
// The unit is tied to the SHORT edge so type never outgrows a landscape frame.
document.documentElement.style.setProperty(
  "--u", Math.min(H / 100, W / 56) + "px");
if (!LAND) document.getElementById("s2").classList.add("port");

var $ = function (id) { return document.getElementById(id); };
var clamp = function (x) { return x < 0 ? 0 : x > 1 ? 1 : x; };
// Normalised progress across [a,b].
var p = function (t, a, b) { return clamp((t - a) / (b - a)); };
var outCubic = function (x) { return 1 - Math.pow(1 - x, 3); };
var outBack = function (x) { var c = 1.70158 + 1; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); };
// Scene envelope: fades in over fi, holds, then fades out over fo.
var env = function (t, a, b, fi, fo) {
  if (t < a || t > b) return 0;
  return Math.min(p(t, a, a + fi), 1 - p(t, b - fo, b));
};

var scenes = ["s1", "s2", "s3", "s4"];

window.__seek = function (t) {
  scenes.forEach(function (s) { $(s).style.opacity = 0; });

  // 1. hook -- 0 to 5.0
  if (t < 5.0) {
    var o = env(t, 0, 5.0, .45, .45);
    $("s1").style.opacity = o;
    var g = outBack(p(t, .15, 1.15));
    $("s1zero").style.transform = "scale(" + (0.4 + 0.6 * g) + ")";
    $("s1zero").style.opacity = p(t, .15, .7);
    $("s1cap").style.opacity = p(t, 0, .5);
    var s = outCubic(p(t, 1.5, 2.3));
    $("s1sub").style.opacity = p(t, 1.5, 2.1);
    $("s1sub").style.transform = "translateY(" + (18 * (1 - s)) + "px)";
  }

  // 2. proof -- 5.0 to 10.0
  else if (t < 10.0) {
    $("s2").style.opacity = env(t, 5.0, 10.0, .45, .45);
    var r = outCubic(p(t, 5.1, 6.2));
    $("s2").querySelector(".phone").style.transform =
      "translateY(" + (60 * (1 - r)) + "px)";
    // One sweep down the screen, then it parks off the bottom.
    var sc = p(t, 5.9, 8.4);
    $("scan").style.top = (sc * 100) + "%";
    $("scan").style.opacity = (sc > 0 && sc < 1) ? 1 : 0;
    var w = outCubic(p(t, 5.3, 6.3));
    $("s2").querySelector(".words").style.transform =
      "translateY(" + (22 * (1 - w)) + "px)";
    $("s2").querySelector(".words").style.opacity = p(t, 5.3, 6.0);
  }

  // 3. the zeros -- 10.0 to 12.5
  else if (t < 12.5) {
    $("s3").style.opacity = env(t, 10.0, 12.5, .3, .35);
    $("s3lead").style.opacity = p(t, 10.05, 10.5);
    var chips = $("chips").children;
    for (var i = 0; i < chips.length; i++) {
      // Chips land one per eighth-note, so the row ticks with the beat.
      var a = 10.25 + i * 0.3125;
      var e = outBack(p(t, a, a + 0.5));
      chips[i].style.opacity = p(t, a, a + 0.22);
      chips[i].style.transform = "scale(" + (0.72 + 0.28 * e) + ")";
    }
  }

  // 4. end card -- 12.5 to 15.0
  else {
    $("s4").style.opacity = env(t, 12.5, 15.0, .35, .0001);
    var l = outBack(p(t, 12.6, 13.4));
    $("s4").querySelector("img").style.transform = "scale(" + (0.6 + 0.4 * l) + ")";
    $("s4").querySelector(".name").style.opacity = p(t, 12.9, 13.4);
    $("s4").querySelector(".tag").style.opacity = p(t, 13.1, 13.6);
    var c = outCubic(p(t, 13.4, 14.0));
    var cta = $("s4").querySelector(".cta");
    cta.style.opacity = p(t, 13.4, 13.8);
    cta.style.transform = "translateY(" + (16 * (1 - c)) + "px)";
  }
};
window.__seek(0);
</script>
</body></html>`,
  ].join("\n");
}

// ---------------------------------------------------------------- render

// playwright-core is CJS, and importing it by absolute path hands back a
// module whose only named export is `default` -- destructuring `chromium`
// straight off it yields undefined.
const { chromium } = (await import(join(RENDER_ROOT, "playwright-core/index.js"))).default;

mkdirSync(OUT, { recursive: true });
rmSync(WORK, { recursive: true, force: true });
mkdirSync(WORK, { recursive: true });

const pageFile = join(WORK, "zero.html");
writeFileSync(pageFile, html());

// Audio bed: the film's own opening 15s, so the ad sounds like the brand and
// the beat grid the scenes were cut to is the one actually playing.
const audio = join(WORK, "bed.m4a");
if (existsSync(FILM)) {
  execFileSync(FF, ["-hide_banner", "-loglevel", "error", "-y", "-i", FILM,
    "-t", String(DUR), "-vn", "-c:a", "aac", "-b:a", "192k",
    "-af", "afade=t=out:st=" + (DUR - 0.6) + ":d=0.6", audio]);
} else {
  console.log("! launch film not found -- rendering silent");
}

const browser = await chromium.launch({ channel: "chrome" });
const total = Math.round(DUR * FPS);

for (const o of ORIENTATIONS) {
  const dir = join(WORK, o.id);
  mkdirSync(dir, { recursive: true });
  const page = await browser.newPage({
    viewport: { width: o.w, height: o.h },
    deviceScaleFactor: 1,
  });
  await page.goto("file://" + pageFile);
  await page.waitForTimeout(250); // let the embedded fonts settle

  const t0 = Date.now();
  for (let n = 0; n < total; n++) {
    await page.evaluate((t) => window.__seek(t), n / FPS);
    await page.screenshot({
      path: join(dir, String(n).padStart(5, "0") + ".jpg"),
      type: "jpeg",
      quality: 94,
    });
  }
  await page.close();
  const secs = ((Date.now() - t0) / 1000).toFixed(0);
  console.log(`${o.id}: ${total} frames in ${secs}s`);

  const out = join(OUT, `budgetify-zero-15s-${o.id}.mp4`);
  const args = ["-hide_banner", "-loglevel", "error", "-y",
    "-framerate", String(FPS), "-i", join(dir, "%05d.jpg")];
  if (existsSync(audio)) args.push("-i", audio);
  args.push("-c:v", "libx264", "-preset", "slow", "-crf", "19",
    "-pix_fmt", "yuv420p", "-r", String(FPS));
  if (existsSync(audio)) args.push("-c:a", "aac", "-b:a", "192k", "-shortest");
  args.push("-movflags", "+faststart", out);
  execFileSync(FF, args);
  console.log(`  -> ${out}`);
}

await browser.close();
rmSync(WORK, { recursive: true, force: true });
