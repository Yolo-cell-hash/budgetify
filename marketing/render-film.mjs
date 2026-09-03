// SUPERSEDED -- DOES NOT RUN. Kept for history only.
//
// Two reasons it cannot work as written:
//   1. S below points at a per-session scratchpad that no longer exists.
//      Scratchpads are wiped without warning; that is what destroyed this
//      film's source twice.
//   2. Its approach -- CDP virtual time + Page.captureScreenshot -- DEADLOCKS
//      on this page. The compositor stalls under paused virtual time because
//      the film has infinite CSS animations.
//
// The live renderer is .render/render.mjs, which plays the film in real time
// and passively receives composited frames via Page.startScreencast (which
// cannot deadlock), then resamples them to a constant 60fps. It lives inside
// .render/ because that is where the only node_modules is, and Node resolves
// bare imports by walking up from the importing file.
//
//   cd marketing/.render && node render.mjs
//
import { chromium } from 'playwright-core';
import { spawnSync } from 'child_process';
import ffmpeg from 'ffmpeg-static';
import fs from 'fs';
import path from 'path';

const S = '/private/tmp/claude-501/-Users-jaykeer-AndroidStudioProjects-budget-tracker/0f37b467-3e9b-45e5-820c-a4cb9d0a7a2d/scratchpad';
const FILM = 'file://' + S + '/budgetify-launch-film.html';
const FDIR = path.join(S, 'frames');
const FPS = 60, DUR = 58.4, NFRAMES = Math.round(DUR * FPS); // 3504
fs.rmSync(FDIR, { recursive: true, force: true }); fs.mkdirSync(FDIR, { recursive: true });

const browser = await chromium.launch({
  channel: 'chrome', headless: true,
  args: ['--autoplay-policy=no-user-gesture-required', '--mute-audio', '--disable-lcd-text'],
});

/* ── Pass A · audio (real-time, deterministic score) ───────────────────── */
console.log('pass A: audio…');
{
  const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
  await page.goto(FILM, { waitUntil: 'load' });
  await page.waitForSelector('#exportbtn');
  await page.evaluate(() => window.__exportLocal());
  await page.waitForTimeout(61500);
  let b64 = null;
  for (let i = 0; i < 30 && !b64; i++) { b64 = await page.evaluate(() => window.__audioB64 || null); if (!b64) await page.waitForTimeout(1000); }
  if (!b64) throw new Error('audio never materialized');
  fs.writeFileSync(path.join(S, 'film-audio.webm'), Buffer.from(b64.split(',')[1], 'base64'));
  console.log('audio:', (fs.statSync(path.join(S, 'film-audio.webm')).size / 1e6).toFixed(2), 'MB');
  await page.close();
}

/* ── Pass B · frames (virtual time, exactly 60 fps) ────────────────────── */
console.log('pass B: frames…');
const page = await browser.newPage({ viewport: { width: 1120, height: 1988 } });
await page.goto(FILM, { waitUntil: 'load' });
await page.waitForSelector('#exportbtn');
await page.waitForTimeout(600);
const cdp = await page.context().newCDPSession(page);

let expired;
const expiredP = () => new Promise(res => { expired = res; });
cdp.on('Emulation.virtualTimeBudgetExpired', () => expired && expired());

await cdp.send('Emulation.setVirtualTimePolicy', { policy: 'pause' });
const started = await page.evaluate(() => window.__renderStart());
if (started !== 'render-started') throw new Error('render start failed');
const rect = await page.evaluate(() => {
  const r = document.getElementById('frame').getBoundingClientRect();
  return { x: Math.ceil(r.x), y: Math.ceil(r.y), width: Math.floor(r.width / 2) * 2, height: Math.floor(r.height / 2) * 2 };
});
console.log('stage rect:', JSON.stringify(rect));

const t0 = Date.now();
for (let n = 1; n <= NFRAMES; n++) {
  const p = expiredP();
  await cdp.send('Emulation.setVirtualTimePolicy', { policy: 'advance', budget: 1000 / FPS, maxVirtualTimeTaskStarvationCount: 10000 });
  await p;
  const shot = await cdp.send('Page.captureScreenshot', {
    format: 'jpeg', quality: 92,
    clip: { x: rect.x, y: rect.y, width: rect.width, height: rect.height, scale: 1 },
  });
  fs.writeFileSync(path.join(FDIR, `f${String(n).padStart(5, '0')}.jpg`), Buffer.from(shot.data, 'base64'));
  if (n % 600 === 0) console.log(`  ${n}/${NFRAMES} frames (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
}
console.log(`frames done in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
await browser.close();

/* ── Mux · 60 fps H.264 + AAC ──────────────────────────────────────────── */
console.log('encoding…');
const out = path.join(S, 'budgetify-launch-film.mp4');
const enc = spawnSync(ffmpeg, [
  '-y',
  '-framerate', String(FPS), '-i', path.join(FDIR, 'f%05d.jpg'),
  '-i', path.join(S, 'film-audio.webm'),
  '-vf', 'scale=1080:1920:flags=lanczos',
  '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p',
  '-c:a', 'aac', '-b:a', '192k',
  '-t', String(DUR), '-movflags', '+faststart',
  out,
], { encoding: 'utf8', maxBuffer: 64e6 });
if (enc.status !== 0) { console.log(enc.stderr.slice(-1500)); throw new Error('encode failed'); }

const info = spawnSync(ffmpeg, ['-i', out], { encoding: 'utf8' }).stderr;
console.log('=== MASTER 60fps ===');
console.log('file:', out, (fs.statSync(out).size / 1e6).toFixed(1) + ' MB');
console.log('duration:', (info.match(/Duration: ([\d:.]+)/) || [])[1]);
console.log((info.match(/Stream .*Video.*/) || [])[0]);
console.log((info.match(/Stream .*Audio.*/) || [])[0]);
