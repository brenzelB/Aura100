import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(root, '../../../..');
const require = createRequire(import.meta.url);
const sharp = require('sharp');
const { chromium } = require('playwright');
const manifest = JSON.parse(await fs.readFile(path.join(root, 'manifest.json'), 'utf8'));
if (manifest.exports.length !== 28) throw new Error('Wrong export count');
if (manifest.ui_theme !== 'neoBrutalist' || manifest.decorative_3d_assets !== false) throw new Error('Wrong campaign constraints');
for (const source of manifest.sources) {
  const bytes = await fs.readFile(path.join(root, source.file));
  const original = await fs.readFile(path.join(repo, source.original));
  if (!bytes.equals(original)) throw new Error(`Source changed: ${source.file}`);
}
const browser = await chromium.launch({ headless: true, ...(process.env.AURA_STORE_CHROMIUM ? { executablePath: process.env.AURA_STORE_CHROMIUM } : {}) });
try {
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  const altSections = ['# Alt-Texte für Store-Bilder', '', 'Jeweils zum passenden Bild in der jeweiligen Sprache eintragen.', ''];
  for (const output of manifest.exports) {
    if (output.alt && output.ui_theme !== 'neoBrutalist') throw new Error(`Wrong UI theme: ${output.file}`);
    if (/editorial|artwork/.test(output.source)) throw new Error(`Disallowed source: ${output.file}`);
    const file = path.join(root, output.file);
    const bytes = await fs.readFile(file);
    const meta = await sharp(bytes).metadata();
    if (meta.width !== output.width || meta.height !== output.height || meta.channels !== 3 || meta.hasAlpha) throw new Error(`PNG format: ${output.file}`);
    if (bytes.length > 8 * 1024 * 1024 || createHash('sha256').update(bytes).digest('hex') !== output.sha256) throw new Error(`PNG integrity: ${output.file}`);
    await page.setViewportSize({ width: output.width, height: output.height });
    await page.goto(pathToFileURL(file.replace(/\.png$/, '.html')).href);
    await page.evaluate(async () => { await document.fonts.ready; await Promise.all([...document.images].map(img => img.decode())); });
    const issues = await page.evaluate(() => {
      const issues = [];
      for (const el of document.querySelectorAll('.headline h1,.headline p,.footer,.brand,.edition')) {
        const rect = el.getBoundingClientRect();
        if (rect.left < 0 || rect.right > innerWidth + 1 || rect.top < 0 || rect.bottom > innerHeight + 1 || el.scrollWidth > el.clientWidth + 2) issues.push(`${el.className || el.tagName}: text outside canvas`);
      }
      if (document.documentElement.scrollWidth > innerWidth || document.documentElement.scrollHeight > innerHeight) issues.push('Canvas overflow');
      if ([...document.images].some(img => !img.complete || !img.naturalWidth)) issues.push('Unloaded asset');
      if (document.querySelector('.art') || [...document.images].some(img => /artwork|editorial_light|editorial_dark/.test(img.src))) issues.push('Old theme or 3D decoration');
      return issues;
    });
    if (issues.length) throw new Error(`${output.file}: ${issues.join('; ')}`);
    if (output.alt) altSections.push(`## ${output.file}`, '', output.alt, '');
  }
  await fs.writeFile(path.join(root, 'ALT-TEXTE.md'), altSections.join('\n'));
  console.log(`PASS: 28 PNG exports; RGB, dimensions, hashes, size; ${manifest.sources.length} untouched Neo-Brutalist screenshot sources; no 3D decoration or other UI theme; loaded assets and unclipped marketing text in both languages.`);
} finally { await browser.close(); }
