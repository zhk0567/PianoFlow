/**
 * Compare Verovio page-1 staff spacing / note size across scores at fixed scale.
 * Expectation: definition-scale staff spacing identical; CSS px identical when
 * outer viewBox is shown 1:1 (viewer sizeEngravingFixedScale).
 */
import createVerovioModule from "../third_party/omr/verovio_npm/node_modules/verovio/dist/verovio-module.mjs";
import { VerovioToolkit } from "../third_party/omr/verovio_npm/node_modules/verovio/dist/verovio.mjs";
import fs from "node:fs";

const SCALE = 60;
const Module = await createVerovioModule();

const opts = {
  scale: SCALE,
  pageWidth: 4000,
  pageHeight: 500,
  adjustPageHeight: true,
  adjustPageWidth: true,
  breaks: "none",
  footer: "none",
  header: "none",
  svgViewBox: true,
  pageMarginTop: 40,
  pageMarginBottom: 40,
  pageMarginLeft: 50,
  pageMarginRight: 20,
  spacingStaff: 14,
  spacingSystem: 2,
  spacingLinear: 0.4,
  spacingNonLinear: 0.55,
  unit: 9,
  justifyVertically: false,
};

function staffSpacingVu(svg) {
  const idx = svg.indexOf('class="staff"');
  if (idx < 0) return null;
  const chunk = svg.slice(idx, idx + 400);
  const ys = [...chunk.matchAll(/M[\d.]+ ([\d.]+)/g)].map((m) => Number(m[1]));
  if (ys.length < 2) return null;
  return ys[1] - ys[0];
}

function analyze(name, file) {
  const xml = fs.readFileSync(file, "utf8");
  const tk = new VerovioToolkit(Module);
  tk.setOptions(opts);
  tk.loadData(xml);
  const svg = tk.renderToSVG(1, {});
  const vb = (svg.match(/viewBox="([^"]+)"/) || [])[1];
  const [, , vbW, vbH] = vb.split(/\s+/).map(Number);
  const def = (svg.match(/class="definition-scale"[^>]*viewBox="([^"]+)"/) ||
    [])[1];
  const spVu = staffSpacingVu(svg);
  const ratio = vbH / Number(def.split(/\s+/)[3]);
  const spCssFixed = spVu * ratio; // 1:1 outer viewBox
  const spCssFit288 = spVu * (288 / Number(def.split(/\s+/)[3]));
  // Wrong old path used outer vb: sp * (288/vbH) in page units...
  const spCssOldFit = spVu * ratio * (288 / vbH);
  console.log(
    [
      name,
      `vbH=${vbH.toFixed(1)}`,
      `cssH_1to1=${vbH.toFixed(1)}`,
      `staffVu=${spVu}`,
      `staffCss_fixed=${spCssFixed.toFixed(3)}`,
      `staffCss_oldFitLane=${spCssOldFit.toFixed(3)}`,
      `notes=${(svg.match(/class="note"/g) || []).length}`,
    ].join("  "),
  );
  return { spCssFixed, spCssOldFit, vbH };
}

const a = analyze(
  "fur_elise",
  "assets/scores/musicxml/fur_elise_woo59.musicxml",
);
const b = analyze(
  "castle",
  "assets/scores/musicxml/hisaishi_castle_in_the_sky.musicxml",
);
const dFixed = Math.abs(a.spCssFixed - b.spCssFixed);
const dOld = Math.abs(a.spCssOldFit - b.spCssOldFit);
console.log(
  `delta staffCss fixed=${dFixed.toFixed(4)} (want ~0)  oldFitLane=${dOld.toFixed(4)}`,
);
if (dFixed > 0.05) {
  console.error("FAIL: fixed-scale staff spacing differs across scores");
  process.exit(1);
}
console.log("OK: fixed 1:1 display keeps staff spacing consistent");
