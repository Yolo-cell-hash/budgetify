// Real-time 60fps render of the Budgetify launch film.
// Virtual-time + captureScreenshot deadlocks on this page (the compositor stalls
// under paused virtual time with the film's infinite CSS animations), so instead
// we play the film in real time and passively receive composited frames via CDP
// Page.startScreencast — which cannot deadlock. Each frame carries a timestamp,
// so ffmpeg resamples them to a perfectly even 60fps constant-rate video.
import { chromium } from 'playwright-core';
import { spawnSync } from 'child_process';
import ffmpeg from 'ffmpeg-static';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const DIR = path.dirname(fileURLToPath(import.meta.url));
const FILM = 'file://' + path.join(DIR, '..', 'budgetify-launch-film.html');
const FDIR = path.join(DIR, 'frames');
const AUDIO = path.join(DIR, 'film-audio.webm');
const OUT_REPO = path.join(DIR, '..', 'budgetify-launch-film-60fps.mp4');
const OUT_DESK = path.join(process.env.HOME, 'Desktop', 'budgetify-launch-film.mp4');
const FPS = 60, DUR = 58.0, CAPTURE_MS = 60000;
fs.rmSync(FDIR, { recursive: true, force: true }); fs.mkdirSync(FDIR, { recursive: true });

const browser = await chromium.launch({
  channel: 'chrome', headless: true,
  args: ['--autoplay-policy=no-user-gesture-required', '--mute-audio',
    '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
    '--disable-backgrounding-occluded-windows', '--disable-features=CalculateNativeWinOcclusion'],
});

// ── Pass A · audio (real-time, deterministic score) ─────────────────────
if (fs.existsSync(AUDIO) && fs.statSync(AUDIO).size > 800000) {
  console.log('pass A: audio already present, skipping');
} else {
  console.log('pass A: recording audio (~62s)…');
  const ap = await browser.newPage({ viewport: { width: 800, height: 600 } });
  await ap.goto(FILM, { waitUntil: 'load' });
  await ap.waitForSelector('#exportbtn');
  await ap.evaluate(() => window.__exportLocal());
  await ap.waitForTimeout(61500);
  let b64 = null;
  for (let i = 0; i < 30 && !b64; i++) { b64 = await ap.evaluate(() => window.__audioB64 || null); if (!b64) await ap.waitForTimeout(1000); }
  if (!b64) throw new Error('audio never materialized');
  fs.writeFileSync(AUDIO, Buffer.from(b64.split(',')[1], 'base64'));
  await ap.close();
  console.log('audio:', (fs.statSync(AUDIO).size / 1e6).toFixed(2), 'MB');
}

// ── Pass B · frames via real-time screencast ────────────────────────────
console.log('pass B: real-time screencast capture…');
const page = await browser.newPage({ viewport: { width: 1120, height: 1988 } });
await page.goto(FILM, { waitUntil: 'load' });
await page.waitForSelector('#exportbtn');
await page.waitForTimeout(500);
const cdp = await page.context().newCDPSession(page);

const frames = []; // { ts, buf }
let seq = 0;
cdp.on('Page.screencastFrame', async e => {
  frames.push({ ts: e.metadata.timestamp, buf: Buffer.from(e.data, 'base64') });
  try { await cdp.send('Page.screencastFrameAck', { sessionId: e.sessionId }); } catch {}
});

const rect = await page.evaluate(() => { const b = document.getElementById('frame').getBoundingClientRect();
  return { w: Math.floor(b.width / 2) * 2, h: Math.floor(b.height / 2) * 2 }; });

await page.evaluate(() => window.__renderStart());          // begin real-time playback
await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 90, everyNthFrame: 1 });
const tStart = Date.now();
while (Date.now() - tStart < CAPTURE_MS) {
  await page.waitForTimeout(1000);
  if ((Date.now() - tStart) % 10000 < 1000) console.log(`  captured ${frames.length} frames (${((Date.now() - tStart) / 1000).toFixed(0)}s)`);
}
await cdp.send('Page.stopScreencast');
await page.waitForTimeout(300);
await browser.close();

if (frames.length < 2) throw new Error('no screencast frames');
const t0 = frames[0].ts;
let filmFrames = frames.map(f => ({ t: f.ts - t0, buf: f.buf })).filter(f => f.t >= 0 && f.t <= DUR);
console.log(`captured ${frames.length} frames; ${filmFrames.length} within [0,${DUR}]s`);
const capFps = filmFrames.length / (filmFrames[filmFrames.length - 1].t || DUR);
console.log(`effective capture rate: ${capFps.toFixed(1)} fps`);

// write frames + a concat list carrying each frame's true on-screen duration,
// so ffmpeg CFR-resamples to an even 60fps (smooth even if capture was uneven).
const list = [];
for (let i = 0; i < filmFrames.length; i++) {
  const name = `f${String(i + 1).padStart(5, '0')}.jpg`;
  fs.writeFileSync(path.join(FDIR, name), filmFrames[i].buf);
  const dur = (i < filmFrames.length - 1 ? filmFrames[i + 1].t - filmFrames[i].t : 1 / FPS);
  list.push(`file '${name}'`, `duration ${Math.max(dur, 0.0001).toFixed(6)}`);
}
list.push(`file 'f${String(filmFrames.length).padStart(5, '0')}.jpg'`); // concat demuxer needs last file repeated
fs.writeFileSync(path.join(FDIR, 'list.txt'), list.join('\n'));

// ── Mux · resample to constant 60 fps, H.264 + AAC ──────────────────────
console.log('encoding to constant 60fps…');
const enc = spawnSync(ffmpeg, [
  '-y',
  '-f', 'concat', '-safe', '0', '-i', path.join(FDIR, 'list.txt'),
  '-i', AUDIO,
  '-vf', `scale=1080:1920:flags=lanczos,fps=${FPS}`,
  '-fps_mode', 'cfr',
  '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p',
  '-c:a', 'aac', '-b:a', '192k',
  '-t', String(DUR), '-movflags', '+faststart',
  OUT_REPO,
], { encoding: 'utf8', maxBuffer: 128e6 });
if (enc.status !== 0) { console.log(enc.stderr.slice(-1800)); throw new Error('encode failed'); }
fs.copyFileSync(OUT_REPO, OUT_DESK);

// ── Validate ────────────────────────────────────────────────────────────
const info = spawnSync(ffmpeg, ['-i', OUT_REPO], { encoding: 'utf8' }).stderr;
const stats = spawnSync(ffmpeg, ['-ss', '20', '-i', OUT_REPO, '-frames:v', '1', '-vf', 'signalstats,metadata=print', '-f', 'null', '-'],
  { encoding: 'utf8', maxBuffer: 32e6 }).stderr;
console.log('=== MASTER ===');
console.log('repo :', OUT_REPO, (fs.statSync(OUT_REPO).size / 1e6).toFixed(1) + ' MB');
console.log('desk :', OUT_DESK);
console.log('duration:', (info.match(/Duration: ([\d:.]+)/) || [])[1], '| fps:', (info.match(/([\d.]+) fps/) || [])[1], '| YAVG@20s:', (stats.match(/YAVG=([\d.]+)/) || [])[1]);
console.log((info.match(/Stream .*Video.*/) || [])[0]);
console.log((info.match(/Stream .*Audio.*/) || [])[0]);
