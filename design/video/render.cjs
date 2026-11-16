// Renders design/video/moment.html to site/media/: the film as MP4 and
// WebM, a poster frame, and a short silent loop for the README.
//
//     node design/video/render.cjs            # the whole film
//     node design/video/render.cjs 12.5       # one frame, to check a moment
//
// Needs Playwright with Chromium, and ffmpeg. Each frame is drawn by
// setting every CSS animation's clock to that frame's time, so the result
// is exact however long a frame takes to draw.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const FPS = 30;
const SECONDS = 44;
const page_url = 'file://' + path.resolve('design/video/moment.html');
const out = path.resolve('site/media');

async function open() {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
  });
  await page.goto(page_url);
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map((image) => image.decode()));
    for (const animation of document.getAnimations()) animation.pause();
  });
  return { browser, page };
}

async function seek(page, seconds) {
  await page.evaluate((ms) => {
    for (const animation of document.getAnimations()) animation.currentTime = ms;
  }, seconds * 1000);
}

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const { browser, page } = await open();
  const stage = page.locator('.stage');

  const only = process.argv[2];
  if (only !== undefined) {
    await seek(page, parseFloat(only));
    const file = path.join(os.tmpdir(), `moment-frame-${only}.png`);
    await stage.screenshot({ path: file });
    console.log(file);
    await browser.close();
    return;
  }

  const frames = fs.mkdtempSync(path.join(os.tmpdir(), 'moment-film-'));
  const total = FPS * SECONDS;
  for (let frame = 0; frame < total; frame++) {
    await seek(page, frame / FPS);
    await stage.screenshot({
      path: path.join(frames, `${String(frame).padStart(5, '0')}.jpg`),
      type: 'jpeg',
      quality: 96,
    });
    if (frame % 150 === 0) console.log(`frame ${frame} of ${total}`);
  }
  await seek(page, 3.6);
  await stage.screenshot({ path: path.join(out, 'moment-poster.jpg'), type: 'jpeg', quality: 90 });
  await browser.close();

  const input = ['-y', '-framerate', String(FPS), '-i', path.join(frames, '%05d.jpg')];
  const quiet = ['-loglevel', 'error'];
  execFileSync('ffmpeg', [
    ...quiet, ...input,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart', path.join(out, 'moment.mp4'),
  ]);
  execFileSync('ffmpeg', [
    ...quiet, ...input,
    '-c:v', 'libvpx-vp9', '-crf', '34', '-b:v', '0', '-row-mt', '1',
    path.join(out, 'moment.webm'),
  ]);
  // The first eleven seconds, small, as a loop a README can show inline.
  execFileSync('ffmpeg', [
    ...quiet, ...input, '-t', '11.2',
    '-vf', 'fps=15,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4',
    path.join(out, 'moment-preview.gif'),
  ]);
  fs.rmSync(frames, { recursive: true });
  for (const name of fs.readdirSync(out)) {
    const size = fs.statSync(path.join(out, name)).size;
    console.log(`${name}  ${(size / 1e6).toFixed(2)} MB`);
  }
})();
