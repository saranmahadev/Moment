// Renders design/video/moment.html to site/media/: the narrated film as
// MP4 and WebM, a poster frame, and a short silent loop for the README.
//
//     python3 design/video/voice.py           # first: narration and timing
//     node design/video/render.cjs            # then: the whole film
//     node design/video/render.cjs 12.5       # or one frame, to check it
//
// Needs Playwright with Chromium, and ffmpeg. Each frame is drawn by
// setting every CSS animation's clock to that frame's time, so the result
// is exact however long a frame takes to draw. The film's length and the
// soundtrack (build/film/soundtrack.wav) come from voice.py.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const FPS = 30;
const soundtrack = path.resolve('build/film/soundtrack.wav');
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
  const timeline = await page.evaluate(() => window.MOMENT_TIMELINE);
  if (!timeline) throw new Error('No timeline: run design/video/voice.py first.');
  return { browser, page, timeline };
}

async function seek(page, seconds) {
  await page.evaluate((ms) => {
    for (const animation of document.getAnimations()) animation.currentTime = ms;
  }, seconds * 1000);
}

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const { browser, page, timeline } = await open();
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

  if (!fs.existsSync(soundtrack)) throw new Error('No soundtrack: run design/video/voice.py first.');
  const frames = fs.mkdtempSync(path.join(os.tmpdir(), 'moment-film-'));
  const total = Math.ceil(FPS * timeline.total);
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
  const sound = ['-i', soundtrack, '-shortest'];
  const quiet = ['-loglevel', 'error'];
  execFileSync('ffmpeg', [
    ...quiet, ...input, ...sound,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '160k',
    '-movflags', '+faststart', path.join(out, 'moment.mp4'),
  ]);
  execFileSync('ffmpeg', [
    ...quiet, ...input, ...sound,
    '-c:v', 'libvpx-vp9', '-crf', '34', '-b:v', '0', '-row-mt', '1',
    '-c:a', 'libopus', '-b:a', '96k',
    path.join(out, 'moment.webm'),
  ]);
  // The opening, up to the end of the six kinds, small and silent, as a
  // loop a README can show inline.
  const opening = timeline.scenes.find((scene) => scene.id === 'kinds').end;
  execFileSync('ffmpeg', [
    ...quiet, ...input, '-t', String(opening),
    '-vf', 'fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4',
    path.join(out, 'moment-preview.gif'),
  ]);
  fs.rmSync(frames, { recursive: true });
  for (const name of fs.readdirSync(out)) {
    const size = fs.statSync(path.join(out, name)).size;
    console.log(`${name}  ${(size / 1e6).toFixed(2)} MB`);
  }
})();
