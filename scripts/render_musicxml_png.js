#!/usr/bin/env node
/** Render MusicXML first page(s) to PNG via Verovio + resvg for PDF proofread. */
const fs = require('fs');
const path = require('path');
const verovio = require('verovio');
const { Resvg } = require('@resvg/resvg-js');

const id = process.argv[2] || 'hisaishi_castle_in_the_sky';
const pages = Math.max(1, parseInt(process.argv[3] || '2', 10));
const repo = path.resolve(__dirname, '..');
const xmlPath = path.join(repo, 'assets', 'scores', 'musicxml', `${id}.musicxml`);
const outDir = path.join(repo, 'docs', 'omr_audit', '_render', id);

verovio.module.onRuntimeInitialized = () => {
  fs.mkdirSync(outDir, { recursive: true });
  const tk = new verovio.toolkit();
  const xml = fs.readFileSync(xmlPath, 'utf8');
  tk.setOptions({
    scale: 40,
    pageWidth: 2100,
    pageHeight: 2970,
    adjustPageHeight: true,
    breaks: 'auto',
    footer: 'none',
    header: 'none',
    svgViewBox: true,
    spacingNonLinear: 1.0,
    spacingLinear: 0.08,
  });
  if (!tk.loadData(xml)) {
    console.error('loadData failed', id);
    process.exit(1);
  }
  const n = Math.min(pages, tk.getPageCount());
    for (let i = 1; i <= n; i++) {
    let svg = tk.renderToSVG(i, {});
    // Ensure opaque white page (resvg treats transparent as black).
    if (!/fill\s*=\s*["']#fff/i.test(svg) && !/<rect[^>]*width=["']100%/.test(svg)) {
      svg = svg.replace(
        /<svg([^>]*)>/,
        '<svg$1><rect width="100%" height="100%" fill="#ffffff"/>',
      );
    }
    const svgPath = path.join(outDir, `mxml_p${i}.svg`);
    fs.writeFileSync(svgPath, svg);
    const resvg = new Resvg(svg, {
      fitTo: { mode: 'width', value: 1400 },
      background: 'white',
    });
    const png = resvg.render().asPng();
    const pngPath = path.join(outDir, `mxml_p${i}.png`);
    fs.writeFileSync(pngPath, png);
    console.log('OK', pngPath);
  }
  console.log('pages', n, 'of', tk.getPageCount());
};
