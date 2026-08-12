/**
 * Render MusicXML first page(s) to SVG via verovio if available.
 * Usage: node scripts/render_musicxml_png.js <input.musicxml> <outDir>
 *
 * PNG conversion requires a local SVG→PNG tool; this script writes SVG.
 */
const fs = require('fs');
const path = require('path');

async function main() {
  const input = process.argv[2];
  const outDir = process.argv[3] || path.join('docs', 'omr_audit', '_render');
  if (!input) {
    console.error('Usage: node scripts/render_musicxml_png.js <musicxml> [outDir]');
    process.exit(2);
  }
  let verovio;
  try {
    verovio = require('verovio');
  } catch (e) {
    console.error(
      '[PianoFlow/omr] verovio npm package missing. Run: npm install verovio --save',
    );
    process.exit(1);
  }
  fs.mkdirSync(outDir, { recursive: true });
  const xml = fs.readFileSync(input, 'utf8');
  const toolkit = new verovio.toolkit();
  toolkit.setOptions({
    scale: 40,
    pageWidth: 2100,
    pageHeight: 2970,
    adjustPageHeight: true,
  });
  toolkit.loadData(xml);
  const pages = toolkit.getPageCount();
  for (let p = 1; p <= pages; p++) {
    const svg = toolkit.renderToSVG(p, {});
    const dest = path.join(outDir, `mxml_p${p}.svg`);
    fs.writeFileSync(dest, svg, 'utf8');
    console.log('[PianoFlow/omr] wrote', dest);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
