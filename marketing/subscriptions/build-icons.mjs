// Compose the Play Console product icons for the Budgetify Plus catalogue.
//
//   node build-icons.mjs
//
// Renders 1024x1024 PNGs via headless Chromium, so the output needs no image
// library -- the same trick as ../playstore/build-screenshots.mjs, but the
// browser is discovered rather than hardcoded, so this runs on Windows too.
// Override with CHROME=/path/to/chrome if the search misses.
//
// Play's constraints on a product icon (from the Console form):
//   * 32-bit PNG, 1:1, each side 512-1080px, under 8MB
//   * "Use a unique and accurate image for each product."
//   * "Don't include text, promotions or branding."
//
// That last rule is why every mark here is a drawn PATH, never a glyph or a
// wordmark: no "Budgetify", no rupee sign, no "SAVE 40%". The three marks read
// as one family on the app's ink ground, and differ in the one thing the buyer
// is actually choosing between -- how long it lasts.

import { execFileSync } from "node:child_process";
import {
  writeFileSync,
  mkdirSync,
  mkdtempSync,
  existsSync,
  readFileSync,
  statSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { inflateSync, deflateSync } from "node:zlib";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const SIZE = 1024;

// Brand palette, lifted from lib/providers/theme_provider.dart so the icons
// cannot drift from the app they sell.
const GOLD = "#C8A75E"; // AppColors.gold, champagne
const GOLD_DEEP = "#A8843C"; // AppColors.goldDeep
const INK_TOP = "#23273A"; // AppColors.heroGradient[0]
const INK_BOTTOM = "#131520"; // AppColors.heroGradient[1]

const CHROME_CANDIDATES = [
  process.env.CHROME,
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
].filter(Boolean);

function findChrome() {
  const hit = CHROME_CANDIDATES.find((p) => existsSync(p));
  if (!hit) {
    throw new Error(
      `No Chromium found. Tried:\n  ${CHROME_CANDIDATES.join("\n  ")}\n` +
        `Set CHROME=/path/to/chrome and re-run.`,
    );
  }
  return hit;
}

/** Shared ground: the app's hero gradient plus a soft gold bloom behind the mark. */
function ground() {
  return `
    <defs>
      <linearGradient id="ink" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${INK_TOP}"/>
        <stop offset="1" stop-color="${INK_BOTTOM}"/>
      </linearGradient>
      <radialGradient id="bloom" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${GOLD}" stop-opacity="0.20"/>
        <stop offset="1" stop-color="${GOLD}" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="mark" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${GOLD}"/>
        <stop offset="1" stop-color="${GOLD_DEEP}"/>
      </linearGradient>
    </defs>
    <rect width="1024" height="1024" fill="url(#ink)"/>
    <circle cx="512" cy="512" r="470" fill="url(#bloom)"/>`;
}

/** A lemniscate: the one mark that means "no end" without spelling it. */
const LIFETIME = `
  <path d="M 512,512
           C 470,428 408,388 358,388
           C 294,388 244,444 244,512
           C 244,580 294,636 358,636
           C 408,636 470,596 512,512
           C 554,428 616,388 666,388
           C 730,388 780,444 780,512
           C 780,580 730,636 666,636
           C 616,636 554,596 512,512 Z"
        fill="none" stroke="url(#mark)" stroke-width="54"
        stroke-linecap="round" stroke-linejoin="round"/>`;

// Geometry for the renewal loop. Everything is DERIVED from the circle rather
// than hand-placed: the first cut of this icon had the arrowhead typed in as
// literal coordinates, which left it floating off the stroke with the round cap
// poking out behind it.
const R = 226; // arc radius
const CX = 512;
const CY = 512;
const STROKE = 54;
const rad = (deg) => (deg * Math.PI) / 180;
const onArc = (deg) => [CX + R * Math.cos(rad(deg)), CY + R * Math.sin(rad(deg))];
const pt = ([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`;

/**
 * A renewal arrow: the loop that comes back around.
 *
 * Sweeps CLOCKWISE from [startDeg] to [endDeg] (screen coords, y down, 0deg =
 * east), leaving a gap at the top, with the head at the finishing end pointing
 * along the tangent — the direction of travel, so the loop reads as turning
 * rather than as a broken ring.
 */
function renewalArrow({ startDeg = 295, endDeg = 245 } = {}) {
  const start = onArc(startDeg);
  const end = onArc(endDeg);

  let sweep = endDeg - startDeg;
  while (sweep <= 0) sweep += 360;

  // Unit tangent (direction of clockwise travel) and outward radial at the end.
  const t = [-Math.sin(rad(endDeg)), Math.cos(rad(endDeg))];
  const n = [Math.cos(rad(endDeg)), Math.sin(rad(endDeg))];

  const HEAD = 78; // how far the tip runs past the arc's end
  const HALF = 52; // half the base width; wider than the stroke's half-width
  //                  (27) so the triangle hides the round cap underneath it

  const tip = [end[0] + t[0] * HEAD, end[1] + t[1] * HEAD];
  const left = [end[0] + n[0] * HALF, end[1] + n[1] * HALF];
  const right = [end[0] - n[0] * HALF, end[1] - n[1] * HALF];

  return `
  <path d="M ${pt(start)} A ${R},${R} 0 ${sweep > 180 ? 1 : 0} 1 ${pt(end)}"
        fill="none" stroke="url(#mark)" stroke-width="${STROKE}"
        stroke-linecap="round"/>
  <path d="M ${pt(tip)} L ${pt(left)} L ${pt(right)} Z" fill="url(#mark)"/>`;
}

/** Twelve marks around the loop -- a year of them, counted not written. */
function twelveTicks() {
  const ticks = [];
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2 - Math.PI / 2;
    const cx = 512 + Math.cos(a) * 336;
    const cy = 512 + Math.sin(a) * 336;
    ticks.push(
      `<circle cx="${cx.toFixed(1)}" cy="${cy.toFixed(1)}" r="17" fill="${GOLD}" opacity="0.78"/>`,
    );
  }
  return ticks.join("\n  ");
}

const ICONS = {
  plus_lifetime: LIFETIME,
  plus_monthly: renewalArrow(),
  plus_yearly: `${renewalArrow()}\n  ${twelveTicks()}`,
};

function html(markup) {
  return `<!doctype html><meta charset="utf-8">
<style>
  html,body{margin:0;padding:0;background:transparent}
  svg{display:block}
</style>
<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}"
     viewBox="0 0 1024 1024">
${ground()}
  ${markup}
</svg>`;
}

// ── RGB → RGBA re-encode ──────────────────────────────────────────────────
//
// Play asks for a 32-bit PNG, but Chromium encodes colour-type 2 (RGB, 24-bit)
// whenever the rendered page is fully opaque — which ours deliberately is. So
// re-encode with an opaque alpha channel rather than smuggling in a
// near-transparent pixel to trick the encoder. Pure zlib; no image library.

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
}

/** Take an 8-bit RGB PNG buffer, return an 8-bit RGBA one (alpha = 255). */
function toRgba(png) {
  const w = png.readUInt32BE(16);
  const h = png.readUInt32BE(20);
  if (png[24] !== 8 || png[25] !== 2) {
    throw new Error(`expected 8-bit RGB, got depth ${png[24]} type ${png[25]}`);
  }

  // Collect every IDAT payload, then inflate the concatenation.
  const parts = [];
  let off = 8;
  while (off < png.length) {
    const len = png.readUInt32BE(off);
    const type = png.toString("ascii", off + 4, off + 8);
    if (type === "IDAT") parts.push(png.subarray(off + 8, off + 8 + len));
    if (type === "IEND") break;
    off += 12 + len;
  }
  const raw = inflateSync(Buffer.concat(parts));

  const bpp = 3;
  const stride = w * bpp;
  const cur = Buffer.alloc(stride);
  const prev = Buffer.alloc(stride);
  const out = Buffer.alloc(h * (1 + w * 4));

  let src = 0;
  let dst = 0;
  for (let y = 0; y < h; y++) {
    const filter = raw[src++];
    raw.copy(cur, 0, src, src + stride);
    src += stride;

    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? cur[x - bpp] : 0;
      const b = prev[x];
      const c = x >= bpp ? prev[x - bpp] : 0;
      let recon;
      switch (filter) {
        case 0: recon = cur[x]; break;
        case 1: recon = cur[x] + a; break;
        case 2: recon = cur[x] + b; break;
        case 3: recon = cur[x] + ((a + b) >> 1); break;
        case 4: recon = cur[x] + paeth(a, b, c); break;
        default: throw new Error(`bad PNG filter ${filter} on row ${y}`);
      }
      cur[x] = recon & 0xff;
    }

    out[dst++] = 0; // emit unfiltered rows; zlib still compresses them well
    for (let x = 0; x < w; x++) {
      out[dst++] = cur[x * 3];
      out[dst++] = cur[x * 3 + 1];
      out[dst++] = cur[x * 3 + 2];
      out[dst++] = 255;
    }
    cur.copy(prev);
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // colour type 6 = truecolour + alpha = 32-bit
  return Buffer.concat([
    png.subarray(0, 8), // signature
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(out, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

function render(chrome, name, markup) {
  // Scratch markup goes to the OS temp dir, not next to the output: it is a
  // build intermediate, and leaving it here would mean committing three
  // regenerable HTML files or gitignoring them.
  const page = join(mkdtempSync(join(tmpdir(), "bg-icon-html-")), `${name}.html`);
  const out = join(HERE, `${name}.png`);
  writeFileSync(page, html(markup), "utf8");
  rmSync(out, { force: true });
  // Edge won't share the default profile, so hand it a scratch one.
  const profile = mkdtempSync(join(tmpdir(), "bg-icon-"));
  execFileSync(
    chrome,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-sandbox",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      `--user-data-dir=${profile}`,
      `--window-size=${SIZE},${SIZE}`,
      `--screenshot=${out}`,
      `file:///${page.replace(/\\/g, "/")}`,
    ],
    { stdio: "ignore" },
  );
  // Chromium returns before the PNG is flushed to disk, so wait for the file
  // to appear AND stop growing rather than racing it.
  const deadline = Date.now() + 20000;
  let last = -1;
  for (;;) {
    if (existsSync(out)) {
      const s = statSync(out).size;
      if (s > 0 && s === last) break;
      last = s;
    }
    if (Date.now() > deadline) throw new Error(`${name}.png never appeared`);
    execFileSync(process.execPath, ["-e", "setTimeout(() => {}, 250)"]);
  }
  // Chromium gives us 24-bit RGB; Play wants 32-bit. Re-encode in place.
  writeFileSync(out, toRgba(readFileSync(out)));
  const bytes = readFileSync(out);
  // PNG IHDR: width/height at 16..24, bit depth 24, colour type 25 (6 = RGBA).
  const w = bytes.readUInt32BE(16);
  const h = bytes.readUInt32BE(20);
  const depth = bytes[24];
  const colour = bytes[25];
  console.log(
    `${name}.png  ${w}x${h}  ${depth}-bit  colour-type ${colour}` +
      `${colour === 6 ? " (RGBA, 32-bit)" : ""}  ${(bytes.length / 1024).toFixed(0)} KB`,
  );
  return { w, h, colour };
}

const chrome = findChrome();
console.log(`Rendering with: ${chrome}\n`);
mkdirSync(HERE, { recursive: true });
let bad = 0;
for (const [name, markup] of Object.entries(ICONS)) {
  const { w, h, colour } = render(chrome, name, markup);
  if (w !== h || w < 512 || w > 1080 || colour !== 6) {
    console.error(`  ^ FAILS Play's spec`);
    bad++;
  }
}
process.exit(bad === 0 ? 0 : 1);
