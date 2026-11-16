// Turns the logo SVGs (see build_logo.py) into every PNG the app and the
// site need: Android launcher icons and adaptive layers, the iOS icon
// set, and the site's icons. Run from the repository root:
//
//     node design/logo/export.cjs
//
// Needs Playwright with Chromium, which draws the SVG filters faithfully.

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const logo = path.resolve('design/logo');
const res = 'android/app/src/main/res';
const iosSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

/** Every PNG to write: source SVG, size in pixels, whether it keeps alpha. */
function jobs() {
  const out = [];
  for (const [density, scale] of Object.entries(densities)) {
    const dir = `${res}/mipmap-${density}`;
    out.push({ svg: 'mark.svg', size: 48 * scale, alpha: true, to: `${dir}/ic_launcher.png` });
    out.push({
      svg: 'adaptive-foreground.svg',
      size: 108 * scale,
      alpha: true,
      to: `${dir}/ic_launcher_foreground.png`,
    });
    out.push({
      svg: 'adaptive-background.svg',
      size: 108 * scale,
      alpha: false,
      to: `${dir}/ic_launcher_background.png`,
    });
  }
  const catalogue = JSON.parse(fs.readFileSync(`${iosSet}/Contents.json`, 'utf8'));
  const seen = new Set();
  for (const image of catalogue.images) {
    if (seen.has(image.filename)) continue;
    seen.add(image.filename);
    const points = parseFloat(image.size);
    const scale = parseInt(image.scale, 10);
    // iOS rounds the corners itself and refuses transparency.
    out.push({
      svg: 'mark-square.svg',
      size: Math.round(points * scale),
      alpha: false,
      to: `${iosSet}/${image.filename}`,
    });
  }
  out.push({ svg: 'mark.svg', size: 512, alpha: true, to: 'design/logo/mark-512.png' });
  out.push({ svg: 'mark.svg', size: 180, alpha: true, to: 'site/icons/apple-touch-icon.png' });
  out.push({ svg: 'mark.svg', size: 32, alpha: true, to: 'site/icons/favicon-32.png' });
  return out;
}

(async () => {
  const browser = await chromium.launch();
  for (const job of jobs()) {
    const page = await browser.newPage({
      viewport: { width: job.size, height: job.size },
      deviceScaleFactor: 1,
    });
    const svg = fs.readFileSync(path.join(logo, job.svg), 'utf8');
    await page.setContent(
      `<style>html,body{margin:0;background:${job.alpha ? 'transparent' : '#EDF0F7'}}` +
        `svg{display:block;width:${job.size}px;height:${job.size}px}</style>${svg}`,
    );
    fs.mkdirSync(path.dirname(job.to), { recursive: true });
    await page.screenshot({ path: job.to, omitBackground: job.alpha });
    await page.close();
  }
  await browser.close();
  console.log(`wrote ${jobs().length} images`);
})();
