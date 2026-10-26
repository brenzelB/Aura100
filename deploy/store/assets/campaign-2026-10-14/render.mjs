// Offline artifact rendering: no user browser profile, logins or network access.
// NODE_PATH may point at the Codex bundled modules; alternatively install
// playwright and sharp in a separate build environment and set NODE_PATH.
import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import { formats, cardsFor, campaignHtml, featureHtml } from './campaign.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const sharp = require('sharp');
const root = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(root, '../../../..');
const languages = ['de', 'en'];
const generated = [];
await fs.mkdir(path.join(root, 'sources/fonts'), { recursive: true });
for (const name of ['Inter-Regular.ttf', 'Inter-Bold.ttf', 'Inter-Black.ttf']) {
  await fs.copyFile(path.join(repo, 'assets/google_fonts', name), path.join(root, 'sources/fonts', name));
}
await fs.copyFile(path.join(repo, 'assets/editorial/fonts/DMSerifDisplay-Regular.ttf'), path.join(root, 'sources/fonts/DMSerifDisplay-Regular.ttf'));
await fs.copyFile(path.join(repo, 'assets/google_fonts/OFL-Inter.txt'), path.join(root, 'sources/fonts/OFL-Inter.txt'));
await fs.copyFile(path.join(repo, 'assets/editorial/fonts/OFL.txt'), path.join(root, 'sources/fonts/OFL-DMSerifDisplay.txt'));
await fs.copyFile(path.join(repo, 'deploy/store/assets/icon_512.png'), path.join(root, 'sources/icon.png'));
const mappings = {
  android: { home: 'store_01_home_progress_raw', progress: 'store_03_progress_detail_raw', quests: 'store_02_quests_overview_raw', create: 'store_04_new_quest_modes_raw', perks: 'store_05_perks_raw' },
  iphone: { home_neo: 'iphone_01_home_neo', quests_neo: 'iphone_02_quests_neo' },
  ipad: { home_neo: 'ipad_01_home_neo', quests_neo: 'ipad_02_quests_neo' },
};
const sources = [];
for (const [device, entries] of Object.entries(mappings)) {
  await fs.mkdir(path.join(root, 'sources', device), { recursive: true });
  for (const [name, original] of Object.entries(entries)) {
    const input = path.join(repo, 'deploy/store/assets/screenshots', device === 'android' ? 'raw' : 'apple', `${original}.png`);
    const target = path.join(root, 'sources', device, `${name}.png`);
    await fs.copyFile(input, target);
    const data = await fs.readFile(target);
    const meta = await sharp(data).metadata();
    sources.push({ file: path.relative(root, target).replaceAll('\\', '/'), original: path.relative(repo, input).replaceAll('\\', '/'), width: meta.width, height: meta.height, sha256: createHash('sha256').update(data).digest('hex'), unchanged: true });
  }
}
const browser = await chromium.launch({ headless: true, ...(process.env.AURA_STORE_CHROMIUM ? { executablePath: process.env.AURA_STORE_CHROMIUM } : {}) });
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.route('**/*', route => /^https?:/.test(route.request().url()) ? route.abort() : route.continue());
  async function render(html, rel, dimensions, details) {
    const target = path.join(root, rel);
    await fs.mkdir(path.dirname(target), { recursive: true });
    const htmlPath = target.replace(/\.png$/, '.html');
    await fs.writeFile(htmlPath, html);
    await page.setViewportSize(dimensions);
    await page.goto(pathToFileURL(htmlPath).href);
    await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map(img => img.decode())); });
    const failures = await page.evaluate(() => [...document.images].filter(img => !img.naturalWidth).map(img => img.src));
    if (failures.length) throw new Error(`Missing images: ${failures}`);
    const png = await page.screenshot({ type: 'png', animations: 'disabled' });
    // RGB PNG export required by Stores; no resampling or UI retouching.
    const data = await sharp(png).removeAlpha().png({ compressionLevel: 9 }).toBuffer();
    const meta = await sharp(data).metadata();
    if (meta.width !== dimensions.width || meta.height !== dimensions.height || meta.hasAlpha || meta.channels !== 3) throw new Error(`Invalid export ${rel}`);
    if (data.length > 8 * 1024 * 1024) throw new Error(`Oversized export ${rel}`);
    await fs.writeFile(target, data);
    generated.push({ file: rel, width: meta.width, height: meta.height, bytes: data.length, channels: meta.channels, sha256: createHash('sha256').update(data).digest('hex'), ...details });
  }
  for (const [platform, format] of Object.entries(formats)) {
    const cards = cardsFor(platform);
    for (const lang of languages) for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      await render(campaignHtml(platform, lang, i, '../../'), `${platform}/${lang}/${card.id}.png`, { width: format.width, height: format.height }, { platform, language: lang, source: card.source, ui_theme: 'neoBrutalist', title: card[lang].title, alt: card[lang].alt });
    }
    console.log(`Rendered ${platform}: ${cards.length} images per language`);
  }
  for (const lang of languages) await render(featureHtml(lang, '../../'), `Feature_Graphic/${lang}/feature_1024x500.png`, { width: 1024, height: 500 }, { platform: 'Google_Play_Feature', language: lang, source: 'sources/icon.png' });
  const cards = generated.filter(file => file.platform === 'Apple_iPhone' && file.language === 'de');
  const thumbs = await Promise.all(cards.map(card => sharp(path.join(root, card.file)).resize(360, 783).toBuffer()));
  const overview = await sharp({ create: { width: 1600, height: 945, channels: 3, background: '#fffcf5' } }).composite(thumbs.map((input, i) => ({ input, left: 50 + i * 390, top: 100 }))).png().toBuffer();
  await fs.writeFile(path.join(root, 'Vorschau_Apple.png'), overview);
  const android = generated.filter(file => file.platform === 'Google_Play' && file.language === 'de');
  const androidThumbs = await Promise.all(android.map(card => sharp(path.join(root, card.file)).resize(288, 512).toBuffer()));
  await sharp({ create: { width: 1600, height: 670, channels: 3, background: '#fffcf5' } }).composite(androidThumbs.map((input, i) => ({ input, left: 32 + i * 312, top: 85 }))).png().toFile(path.join(root, 'Vorschau_Google_Play.png'));
  await fs.writeFile(path.join(root, 'manifest.json'), JSON.stringify({ created: '2026-10-14', revision: 2, app: 'Aura Quest', campaign: 'Weniger morgen. Mehr machen.', ui_theme: 'neoBrutalist', decorative_3d_assets: false, generated_artwork: 'None used in revision 2. Original flat app logo retained.', layout: 'Native HTML/CSS layout using unchanged real Neo-Brutalist UI screenshot inputs', app_code_changed: false, store_uploaded: false, source_note: 'Android: existing Neo-Brutalist test-emulator captures. Apple: reviewed Neo-Brutalist Light simulator captures from production widgets with illustrative local fixtures. Cards 3 and 4 reuse the genuine Quests and Home views; the dark poster backdrop is not an in-app Dark Mode claim.', sources, exports: generated }, null, 2) + '\n');
  const gallery = `<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Aura Quest — neue Store-Bilder</title><style>body{font-family:system-ui;margin:40px;background:#fffaf0;color:#241d2c}h1{font-size:clamp(28px,5vw,54px);letter-spacing:-2px}p{line-height:1.6;max-width:850px}.grid{display:flex;gap:22px;overflow-x:auto;padding:25px 8px 40px}.card{min-width:230px;width:230px}.card img{width:100%;border-radius:20px;box-shadow:0 14px 26px #241d2c24}a{color:#6032a1}figcaption{font-size:14px;margin-top:12px}section{margin:45px 0}details{margin:20px 0}footer{margin-top:60px}</style></head><body><h1>Weniger morgen. Mehr machen.</h1><p>Revision 2: warme Farben, große Serifenschrift und echte Neo-Brutalist-Ansichten. Ohne zusätzliche 3D-Motive.</p>${Object.keys(formats).map(platform => `<section><h2>${platform.replaceAll('_', ' ')}</h2>${languages.map(lang => `<details ${lang === 'de' ? 'open' : ''}><summary>${lang === 'de' ? 'Deutsch' : 'English'}</summary><div class="grid">${generated.filter(e => e.platform === platform && e.language === lang).map(e => `<figure class="card"><a href="${e.file}"><img src="${e.file}" alt="${e.alt}"></a><figcaption>${e.width} × ${e.height} · <a href="${e.file}" download>PNG</a></figcaption></figure>`).join('')}</div></details>`).join('')}</section>`).join('')}<section><h2>Google Play Feature-Grafik</h2>${languages.map(lang => `<p>${lang.toUpperCase()}: <a href="Feature_Graphic/${lang}/feature_1024x500.png"><img style="width:min(100%,800px);display:block;border-radius:20px" src="Feature_Graphic/${lang}/feature_1024x500.png" alt="Aura Quest Feature-Grafik"></a></p>`).join('')}</section><footer><a href="README.md">Anleitung & Bildreihenfolge</a> · <a href="manifest.json">Maße, Quellen & Prüfsummen</a></footer></body></html>`;
  await fs.writeFile(path.join(root, 'index.html'), gallery);
  if (new Set(generated.map(file => file.sha256)).size !== generated.length) throw new Error('Duplicate exports');
  console.log(`Verified ${generated.length} unique, opaque RGB PNG exports.`);
} finally { await browser.close(); }
