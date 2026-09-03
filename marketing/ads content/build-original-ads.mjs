// Original animated ads, rendered from scratch. Supersedes build-zero-ad.mjs.
//
//   node build-original-ads.mjs [--fps 30] [--only zero] [--orient 9x16]
//
// These are NOT cuts of the launch film. The film is a 58s brand piece with its
// own scene grammar; each of these is shaped as an ad from the first frame --
// one idea, four beats, and a layout that reflows NATIVELY into every
// orientation rather than being cropped or composited into one.
//
// THEME IS TAKEN FROM THE APP, NOT EYEBALLED. Every colour below is a real
// token out of lib/providers/theme_provider.dart:
//
//   gold        #C8A75E   AppColors.gold ("champagne gold accent")
//   goldDeep    #A8843C   AppColors.goldDeep
//   heroTop     #23273A   AppColors.heroGradient[0]
//   heroBottom  #131520   AppColors.heroGradient[1]
//   ink         #0A0B0E   AppColors.dark.background
//   text        #F2F2EF   AppColors.dark.text
//   textDim     #9A9DA6   AppColors.dark.textSecondary
//
// EVERY CLAIM IS COUNTED FROM THE CODE, not from marketing memory:
//   12 streak rewards  streak_reward.dart -- 12 `days:` milestones
//                      (3,5,7,10,14,18,24,30,36,45,52,60), and the Settings
//                      screen itself reads "of 12 rewards"
//   8 themes           AppThemeVariant enum -- 8 variants
//   15 titles          achievement.dart -- 15 GamiTitle entries
//   6 languages        main.dart supportedLocales -- en,hi,mr,bn,te,ta
//   the motto          app_strings.dart onboardWelcomeDesc, in all six
//
// TIMING is the film's grid: the score is 96 BPM, so a bar is 2.5s, and every
// beat lands at 0 / 5.0 / 10.0 / 12.5. The audio bed is the film's own opening
// 15s, so an original ad still sounds like the brand.
//
// DETERMINISM: no CSS animations and no wall clock. The page exposes __seek(t)
// and every property is a pure function of t, so frame N is exactly t = N/fps
// and a re-render is byte-identical.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "video");
const WORK = join(tmpdir(), "budgetify-ad-frames");
const FONTS = resolve(HERE, "../../assets/fonts");
const LOGO = resolve(HERE, "../../assets/branding/logo.png");
const CAPS = resolve(HERE, "../playstore/captures");

const RENDER_ROOT = resolve(HERE, "../.render/node_modules");
const FF = join(RENDER_ROOT, "ffmpeg-static/ffmpeg");
const FILM = resolve(HERE, "../budgetify-launch-film-60fps.mp4");

const argv = process.argv.slice(2);
const arg = (k, d) => { const i = argv.indexOf("--" + k); return i >= 0 ? argv[i + 1] : d; };
const FPS = Number(arg("fps", 30));
const ONLY = arg("only", null);
const ORIENT = arg("orient", null);

const SIZES = {
  "9x16": { w: 1080, h: 1920 },
  "1x1": { w: 1080, h: 1080 },
  "16x9": { w: 1920, h: 1080 },
};

const dataUri = (p, mime) =>
  "data:" + mime + ";base64," + readFileSync(p).toString("base64");
const shot = (f) => dataUri(join(CAPS, f), "image/png");

// ------------------------------------------------------------------ the ads

const ADS = [
  {
    id: "zero",
    orientations: ["9x16", "1x1", "16x9"],
    // Every number in it is zero -- typed, sign-ups, servers, trackers, ads --
    // which puts the automatic claim and the privacy claim on ONE spine. No cut
    // of the film does that; the film states them in two acts nine seconds apart.
    css: [
      "#s1 .cap{max-width:86%;font-weight:700;font-size:calc(var(--u)*1.9);letter-spacing:.26em;text-transform:uppercase;color:var(--dim);text-align:center}",
      "#s1 .big{font-weight:800;font-size:calc(var(--u)*34);line-height:.92;color:var(--gold);letter-spacing:-.04em}",
      "#s1 .sub{max-width:88%;font-weight:800;font-size:calc(var(--u)*5.0);letter-spacing:-.02em;text-align:center}",
    ],
    body: [
      '<div class="scene pad col" id="s1">',
      '  <div class="cap" id="z_cap">Transactions you typed last month</div>',
      '  <div class="big" id="z_big">0</div>',
      '  <div class="sub" id="z_sub">Budgetify read them instead.</div>',
      "</div>",
      PHONE("s2", "Automatic", "It reads the bank SMS<br>you already get.", "home-01-top.png"),
      CHIPS("s3", "And told nobody.", [
        ["0", "sign-ups"], ["0", "servers"], ["0", "trackers"], ["0", "ads"],
      ]),
      ENDCARD("s4"),
    ],
    seek: [
      "if (t < 5.0) {",
      "  $('s1').style.opacity = env(t, 0, 5.0, .45, .45);",
      "  var g = outBack(p(t, .15, 1.15));",
      "  set('z_big', { opacity: p(t, .15, .7), transform: 'scale(' + (0.4 + 0.6 * g) + ')' });",
      "  set('z_cap', { opacity: p(t, 0, .5) });",
      "  var s = outCubic(p(t, 1.5, 2.3));",
      "  set('z_sub', { opacity: p(t, 1.5, 2.1), transform: 'translateY(' + (18 * (1 - s)) + 'px)' });",
      "} else if (t < 10.0) { phone(t, 5.0, 10.0); }",
      "else if (t < 12.5) { chips(t, 10.0, 12.5); }",
      "else { endcard(t); }",
    ],
  },

  {
    id: "streak",
    orientations: ["9x16", "1x1", "16x9"],
    // The retention story. Counts are read out of the code, not invented:
    // 12 streak rewards, 8 AppThemeVariant values, 15 GamiTitle entries.
    css: [
      "#s1 .cap{max-width:86%;font-weight:700;font-size:calc(var(--u)*1.9);letter-spacing:.26em;text-transform:uppercase;color:var(--dim);text-align:center}",
      "#s1 .flamerow{display:flex;align-items:center;gap:calc(var(--u)*1.6)}",
      "#s1 .big{font-weight:800;font-size:calc(var(--u)*26);line-height:.94;color:var(--gold);letter-spacing:-.04em}",
      "#s1 .flame{font-size:calc(var(--u)*13);line-height:1}",
      "#s1 .sub{max-width:88%;font-weight:800;font-size:calc(var(--u)*4.6);letter-spacing:-.02em;text-align:center}",
    ],
    body: [
      '<div class="scene pad col" id="s1">',
      '  <div class="cap" id="k_cap">Your streak</div>',
      '  <div class="flamerow"><div class="big" id="k_big">0</div><div class="flame" id="k_flame">🔥</div></div>',
      '  <div class="sub" id="k_sub">A budget you come back to.</div>',
      "</div>",
      PHONE("s2", "Royalty", "Earn titles.<br>Crown a royal.", "royals.png", 200),
      CHIPS("s3", "Not a spreadsheet.<br>A game.", [
        ["12", "streak rewards"], ["15", "titles"], ["8", "themes"],
      ]),
      ENDCARD("s4"),
    ],
    seek: [
      "if (t < 5.0) {",
      "  $('s1').style.opacity = env(t, 0, 5.0, .45, .45);",
      "  set('k_cap', { opacity: p(t, 0, .5) });",
      // Counts to 47 -- the streak the film shows, so the two pieces agree.
      "  var c = outCubic(p(t, .3, 2.6));",
      "  $('k_big').textContent = Math.round(47 * c);",
      "  set('k_big', { opacity: p(t, .2, .6) });",
      "  var fl = outBack(p(t, .5, 1.4));",
      "  set('k_flame', { opacity: p(t, .5, 1.0), transform: 'scale(' + (0.5 + 0.5 * fl) + ')' });",
      "  var s = outCubic(p(t, 2.6, 3.4));",
      "  set('k_sub', { opacity: p(t, 2.6, 3.2), transform: 'translateY(' + (18 * (1 - s)) + 'px)' });",
      "} else if (t < 10.0) { phone(t, 5.0, 10.0); }",
      "else if (t < 12.5) { chips(t, 10.0, 12.5); }",
      "else { endcard(t); }",
    ],
  },

  {
    id: "language",
    orientations: ["9x16", "1x1", "16x9"],
    // The motto cycling through all six locales, lifted verbatim from
    // app_strings.dart onboardWelcomeDesc. Indic scripts fall back to the
    // system faces -- Manrope has no Devanagari, Bengali, Telugu or Tamil.
    css: [
      "#s1 .cap{max-width:86%;font-weight:700;font-size:calc(var(--u)*1.9);letter-spacing:.26em;text-transform:uppercase;color:var(--dim);text-align:center}",
      "#s1 .motto{max-width:86%;min-height:calc(var(--u)*22);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:calc(var(--u)*5.2);line-height:1.28;letter-spacing:-.02em;text-align:center}",
      "#s3 .chip span{font-size:calc(var(--u)*2.5)}",
    ],
    body: [
      '<div class="scene pad col" id="s1">',
      '  <div class="cap">Your money, beautifully tracked</div>',
      '  <div class="motto" id="l_motto"></div>',
      "</div>",
      PHONE("s2", "Six languages", "Every screen.<br>Not just the menu.", "localisation-hindi.png"),
      CHIPS("s3", "In your language.", [
        ["", "English"], ["", "हिन्दी"], ["", "मराठी"],
        ["", "বাংলা"], ["", "తెలుగు"], ["", "தமிழ்"],
      ]),
      ENDCARD("s4"),
    ],
    seek: [
      "if (t < 5.0) {",
      "  $('s1').style.opacity = env(t, 0, 5.0, .45, .45);",
      "  var MOTTO = window.__MOTTO;",
      // One language per 0.75s -- a beat-and-a-half at 96 BPM.
      "  var i = Math.min(MOTTO.length - 1, Math.floor(p(t, .3, 4.8) * MOTTO.length));",
      "  var el = $('l_motto');",
      "  if (el.dataset.i !== String(i)) { el.dataset.i = String(i); el.textContent = MOTTO[i]; }",
      // Each swap fades in on its own sub-window so the change reads as a beat.
      "  var local = (p(t, .3, 4.8) * MOTTO.length) % 1;",
      "  set('l_motto', { opacity: Math.min(1, local / 0.18) * p(t, .3, .6) });",
      "} else if (t < 10.0) { phone(t, 5.0, 10.0); }",
      "else if (t < 12.5) { chips(t, 10.0, 12.5); }",
      "else { endcard(t); }",
    ],
  },

  {
    id: "recurring",
    // Ships in two orientations, not three: the ad group caps at 20 videos and
    // this is the fourth original, so it takes the two that carry the most
    // video inventory (Shorts/portrait and in-stream) and skips square.
    orientations: ["9x16", "16x9"],
    css: [
      "#s1 .cap{max-width:86%;font-weight:700;font-size:calc(var(--u)*1.9);letter-spacing:.26em;text-transform:uppercase;color:var(--dim);text-align:center}",
      "#s1 .big{font-weight:800;font-size:calc(var(--u)*13);line-height:.98;color:var(--gold);letter-spacing:-.035em}",
      "#s1 .sub{max-width:88%;font-weight:800;font-size:calc(var(--u)*4.6);letter-spacing:-.02em;text-align:center}",
    ],
    body: [
      '<div class="scene pad col" id="s1">',
      '  <div class="cap">Leaves your account every month</div>',
      '  <div class="big" id="r_big">&#8377;0</div>',
      '  <div class="sub" id="r_sub">Do you know what is in there?</div>',
      "</div>",
      PHONE("s2", "Recurring", "It finds the ones<br>you forgot.", "recurring-01.png"),
      CHIPS("s3", "Nothing bills you by surprise.", [
        ["", "Subscriptions"], ["", "EMIs"], ["", "Rent"], ["", "Bills"],
      ]),
      ENDCARD("s4"),
    ],
    seek: [
      "if (t < 5.0) {",
      "  $('s1').style.opacity = env(t, 0, 5.0, .45, .45);",
      // 24,096 is the "Monthly commitment" total on the real Recurring screen
      // this ad shows in its next beat, so the number and the screenshot agree.
      "  var c = outCubic(p(t, .3, 2.8));",
      "  $('r_big').textContent = '\\u20B9' + Math.round(24096 * c).toLocaleString('en-IN');",
      "  set('r_big', { opacity: p(t, .2, .6) });",
      "  var s = outCubic(p(t, 2.8, 3.6));",
      "  set('r_sub', { opacity: p(t, 2.8, 3.4), transform: 'translateY(' + (18 * (1 - s)) + 'px)' });",
      "} else if (t < 10.0) { phone(t, 5.0, 10.0); }",
      "else if (t < 12.5) { chips(t, 10.0, 12.5); }",
      "else { endcard(t); }",
    ],
  },
];

// -------------------------------------------------------- shared scene parts

// Scene 2 for every ad: words beside (or above) a real device capture, with a
// single gold sweep reading down the screen.
function PHONE(id, eyebrow, headline, file, offset) {
  return [
    '<div class="scene pad" id="' + id + '">',
    '  <div class="words">',
    '    <div class="eyebrow">' + eyebrow + "</div>",
    "    <h2>" + headline + "</h2>",
    "  </div>",
    '  <div class="phone"><img src="' + shot(file) + '"' +
      (offset ? ' style="margin-top:-' + offset + 'px"' : "") + '><div class="scan"></div></div>',
    "</div>",
  ].join("\n");
}

// Scene 3: a lead line and a row of chips that land one per eighth-note.
function CHIPS(id, lead, items) {
  return [
    '<div class="scene pad col" id="' + id + '">',
    '  <div class="lead">' + lead + "</div>",
    '  <div class="chips">',
    items.map(function (c) {
      return '    <div class="chip">' + (c[0] ? "<b>" + c[0] + "</b>" : "") +
        "<span>" + c[1] + "</span></div>";
    }).join("\n"),
    "  </div>",
    "</div>",
  ].join("\n");
}

function ENDCARD(id) {
  return [
    '<div class="scene pad col" id="' + id + '">',
    '  <img class="mark" src="' + dataUri(LOGO, "image/png") + '">',
    '  <div class="name">Budgetify</div>',
    '  <div class="tag">Your money, beautifully tracked</div>',
    '  <div class="cta">Get it free on Google Play</div>',
    "</div>",
  ].join("\n");
}

const MOTTO = [
  "Your money, beautifully tracked — automatically, and always private.",
  "आपका पैसा, खूबसूरती से ट्रैक — अपने आप, और हमेशा निजी।",
  "तुमचा पैसा, सुंदरपणे ट्रॅक — आपोआप, आणि नेहमी खाजगी.",
  "আপনার টাকা, সুন্দরভাবে ট্র্যাক — স্বয়ংক্রিয়ভাবে, আর সবসময় ব্যক্তিগত।",
  "మీ డబ్బు, అందంగా ట్రాక్ — ఆటోమేటిక్‌గా, ఎప్పుడూ ప్రైవేట్‌గా.",
  "உங்கள் பணம், அழகாகக் கண்காணிப்பு — தானாக, எப்போதும் தனிப்பட்டதாக.",
];

const face = (w, f) =>
  "@font-face{font-family:Manrope;font-weight:" + w + ";font-style:normal;src:url(" +
  dataUri(join(FONTS, f), "font/ttf") + ') format("truetype");}';

function html(ad) {
  return [
    '<!doctype html><html><head><meta charset="utf-8"><style>',
    face(500, "manrope-500.ttf"), face(700, "manrope-700.ttf"), face(800, "manrope-800.ttf"),
    BASE_CSS,
    ad.css.join("\n"),
    "</style></head><body>",
    '<div id="bg"></div>',
    ad.body.join("\n"),
    "<script>",
    "window.__MOTTO = " + JSON.stringify(MOTTO) + ";",
    HELPERS,
    "window.__seek = function (t) {",
    "  ['s1','s2','s3','s4'].forEach(function (s) { var e = $(s); if (e) e.style.opacity = 0; });",
    ad.seek.join("\n"),
    "};",
    "window.__seek(0);",
    "</script>",
    "</body></html>",
  ].join("\n");
}

// ------------------------------------------------------------------ the shell

// Colours below are the real tokens from lib/providers/theme_provider.dart --
// see the header. --u is driven by frame HEIGHT with a width guard: tying it to
// min(W,H) made a PORTRAIT frame size its type off its width, which put a hero
// numeral at 17% of frame height instead of a third.
const BASE_CSS = `
:root{
  --gold:#C8A75E; --gold-deep:#A8843C;
  --hero-top:#23273A; --hero-bottom:#131520; --ink:#0A0B0E;
  --text:#F2F2EF; --dim:#9A9DA6;
  --u:10px;
}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:100%;height:100%;overflow:hidden;background:var(--ink)}
body{
  font-family:Manrope,"Noto Sans Devanagari","Noto Sans Bengali","Noto Sans Telugu",
    "Noto Sans Tamil","Kohinoor Devanagari","Bangla MN","Telugu MN","Tamil MN",
    -apple-system,sans-serif;
  color:var(--text);
}
#bg{
  position:fixed;inset:0;
  background:
    radial-gradient(120vmax 90vmax at 50% 112%, rgba(200,167,94,.26), transparent 62%),
    radial-gradient(80vmax 70vmax at 6% -12%, rgba(74,88,132,.30), transparent 66%),
    linear-gradient(168deg,var(--hero-top) 0%,var(--hero-bottom) 46%,var(--ink) 100%);
}
.scene{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;opacity:0}
.scene.col{flex-direction:column}
.pad{padding:0 calc(var(--u)*6)}

/* scene 2 -- words + device */
#s2{gap:calc(var(--u)*5)}
#s2.port{flex-direction:column}
#s2 .words{max-width:calc(var(--u)*46)}
#s2.port .words{text-align:center;max-width:92%}
#s2 .eyebrow{
  font-weight:700;font-size:calc(var(--u)*1.7);letter-spacing:.28em;
  text-transform:uppercase;color:var(--gold);
}
#s2 h2{
  font-weight:800;font-size:calc(var(--u)*4.2);line-height:1.08;
  letter-spacing:-.03em;margin-top:calc(var(--u)*1.6);
}
#s2 .phone{
  position:relative;width:calc(var(--u)*28);flex:none;overflow:hidden;
  border:1.5px solid rgba(200,167,94,.42);border-radius:calc(var(--u)*1.6);
  box-shadow:0 calc(var(--u)*3) calc(var(--u)*8) rgba(0,0,0,.55);
}
#s2 .phone img{display:block;width:100%}
#s2 .scan{
  position:absolute;left:0;right:0;height:calc(var(--u)*9);
  background:linear-gradient(180deg,transparent,rgba(200,167,94,.30),transparent);
  border-bottom:2px solid rgba(200,167,94,.85);
}

/* scene 3 -- lead + chips */
#s3{gap:calc(var(--u)*3.4)}
#s3 .lead{
  max-width:88%;font-weight:800;font-size:calc(var(--u)*5.0);
  letter-spacing:-.03em;text-align:center;
}
#s3 .chips{display:flex;flex-wrap:wrap;gap:calc(var(--u)*1.6);justify-content:center;max-width:88%}
#s3 .chip{
  display:flex;align-items:baseline;gap:calc(var(--u)*.9);
  border:1px solid rgba(200,167,94,.38);border-radius:999px;
  padding:calc(var(--u)*1.1) calc(var(--u)*2.4);background:rgba(200,167,94,.07);
}
#s3 .chip b{font-weight:800;font-size:calc(var(--u)*3.4);color:var(--gold)}
#s3 .chip span{font-weight:500;font-size:calc(var(--u)*2.3);color:var(--text)}

/* scene 4 -- end card */
#s4 .mark{
  width:calc(var(--u)*11);height:calc(var(--u)*11);
  border-radius:calc(var(--u)*2.6);display:block;
}
#s4 .name{font-weight:800;font-size:calc(var(--u)*7.5);letter-spacing:-.03em;margin-top:calc(var(--u)*2.4)}
#s4 .tag{
  font-weight:700;font-size:calc(var(--u)*1.8);letter-spacing:.22em;text-transform:uppercase;
  color:var(--gold);margin-top:calc(var(--u)*1.2);text-align:center;
}
#s4 .cta{
  margin-top:calc(var(--u)*3.4);background:var(--gold);color:#15110A;
  font-weight:800;font-size:calc(var(--u)*2.3);
  padding:calc(var(--u)*1.5) calc(var(--u)*3.4);border-radius:999px;
}
`;

const HELPERS = `
var W = innerWidth, H = innerHeight, LAND = W > H * 1.2;
document.documentElement.style.setProperty("--u", Math.min(H / 100, W / 56) + "px");
if (!LAND) { var s2 = document.getElementById("s2"); if (s2) s2.classList.add("port"); }

var $ = function (id) { return document.getElementById(id); };
var clamp = function (x) { return x < 0 ? 0 : x > 1 ? 1 : x; };
var p = function (t, a, b) { return clamp((t - a) / (b - a)); };
var outCubic = function (x) { return 1 - Math.pow(1 - x, 3); };
var outBack = function (x) { var c = 2.70158; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); };
var env = function (t, a, b, fi, fo) {
  if (t < a || t > b) return 0;
  return Math.min(p(t, a, a + fi), 1 - p(t, b - fo, b));
};
var set = function (id, props) {
  var el = $(id); if (!el) return;
  for (var k in props) el.style[k] = props[k];
};

// Scene 2: device rises, words rise, one gold sweep reads down the screen.
var phone = function (t, a, b) {
  var sc = $("s2"); if (!sc) return;
  sc.style.opacity = env(t, a, b, .45, .45);
  var r = outCubic(p(t, a + .1, a + 1.2));
  sc.querySelector(".phone").style.transform = "translateY(" + (60 * (1 - r)) + "px)";
  var w = outCubic(p(t, a + .3, a + 1.3));
  var words = sc.querySelector(".words");
  words.style.transform = "translateY(" + (22 * (1 - w)) + "px)";
  words.style.opacity = p(t, a + .3, a + 1.0);
  var s = p(t, a + .9, a + 3.4);
  var scan = sc.querySelector(".scan");
  scan.style.top = (s * 100) + "%";
  scan.style.opacity = (s > 0 && s < 1) ? 1 : 0;
};

// Scene 3: chips land one per eighth-note, so the row ticks with the beat.
var chips = function (t, a, b) {
  var sc = $("s3"); if (!sc) return;
  sc.style.opacity = env(t, a, b, .3, .35);
  sc.querySelector(".lead").style.opacity = p(t, a + .05, a + .5);
  var cs = sc.querySelector(".chips").children;
  var step = 1.25 / cs.length;
  for (var i = 0; i < cs.length; i++) {
    var st = a + .25 + i * step;
    var e = outBack(p(t, st, st + 0.5));
    cs[i].style.opacity = p(t, st, st + 0.22);
    cs[i].style.transform = "scale(" + (0.72 + 0.28 * e) + ")";
  }
};

var endcard = function (t) {
  var sc = $("s4"); if (!sc) return;
  sc.style.opacity = env(t, 12.5, 15.0, .35, .0001);
  var l = outBack(p(t, 12.6, 13.4));
  sc.querySelector(".mark").style.transform = "scale(" + (0.6 + 0.4 * l) + ")";
  sc.querySelector(".name").style.opacity = p(t, 12.9, 13.4);
  sc.querySelector(".tag").style.opacity = p(t, 13.1, 13.6);
  var c = outCubic(p(t, 13.4, 14.0));
  var cta = sc.querySelector(".cta");
  cta.style.opacity = p(t, 13.4, 13.8);
  cta.style.transform = "translateY(" + (16 * (1 - c)) + "px)";
};
`;

// ---------------------------------------------------------------- the render

// playwright-core is CJS, and importing it by absolute path hands back a module
// whose only named export is `default` -- destructuring chromium straight off
// the namespace yields undefined.
const { chromium } = (await import(join(RENDER_ROOT, "playwright-core/index.js"))).default;

const DUR = 15;
mkdirSync(OUT, { recursive: true });
rmSync(WORK, { recursive: true, force: true });
mkdirSync(WORK, { recursive: true });

// Audio bed: the film's own opening 15s, so every original still sounds like
// the brand and the bar grid the scenes were cut to is the one playing.
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

for (const ad of ADS) {
  if (ONLY && ad.id !== ONLY) continue;
  const pageFile = join(WORK, ad.id + ".html");
  writeFileSync(pageFile, html(ad));

  for (const oid of ad.orientations) {
    if (ORIENT && oid !== ORIENT) continue;
    const size = SIZES[oid];
    const dir = join(WORK, ad.id + "-" + oid);
    mkdirSync(dir, { recursive: true });

    const page = await browser.newPage({
      viewport: { width: size.w, height: size.h },
      deviceScaleFactor: 1,
    });
    await page.goto("file://" + pageFile);
    await page.waitForTimeout(300); // embedded + fallback faces settle

    const t0 = Date.now();
    for (let n = 0; n < total; n++) {
      await page.evaluate((t) => window.__seek(t), n / FPS);
      await page.screenshot({
        path: join(dir, String(n).padStart(5, "0") + ".jpg"),
        type: "jpeg", quality: 94,
      });
    }
    await page.close();

    const out = join(OUT, "budgetify-" + ad.id + "-15s-" + oid + ".mp4");
    const args = ["-hide_banner", "-loglevel", "error", "-y",
      "-framerate", String(FPS), "-i", join(dir, "%05d.jpg")];
    if (existsSync(audio)) args.push("-i", audio);
    args.push("-c:v", "libx264", "-preset", "slow", "-crf", "19",
      "-pix_fmt", "yuv420p", "-r", String(FPS));
    if (existsSync(audio)) args.push("-c:a", "aac", "-b:a", "192k", "-shortest");
    args.push("-movflags", "+faststart", out);
    execFileSync(FF, args);

    console.log(ad.id + " " + oid + ": " + total + " frames in " +
      ((Date.now() - t0) / 1000).toFixed(0) + "s");
    rmSync(dir, { recursive: true, force: true });
  }
}

await browser.close();
rmSync(WORK, { recursive: true, force: true });
