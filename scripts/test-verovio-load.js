const fs = require("fs");
const path = require("path");
const verovio = require("../third_party/omr/verovio_npm/node_modules/verovio");

const xml = fs.readFileSync(
  path.join(__dirname, "..", "assets", "scores", "musicxml", "fur_elise_woo59.musicxml"),
  "utf8",
);
console.log("xml", xml.length, "noteTags", (xml.match(/<note/g) || []).length);

const toolkit = new verovio.toolkit();
const cases = [
  { name: "wide-none", scale: 95, pageWidth: 16000, pageHeight: 500, breaks: "none" },
  { name: "capped-none", scale: 95, pageWidth: 8000, pageHeight: 500, breaks: "none" },
  { name: "safe-auto", scale: 55, pageWidth: 2400, pageHeight: 600, breaks: "auto" },
  { name: "defaultish", scale: 40, pageWidth: 2000, pageHeight: 800, breaks: "auto" },
];

for (const o of cases) {
  toolkit.setOptions({
    scale: o.scale,
    pageWidth: o.pageWidth,
    pageHeight: o.pageHeight,
    breaks: o.breaks,
    adjustPageHeight: true,
    adjustPageWidth: true,
    footer: "none",
    header: "none",
    svgViewBox: true,
  });
  const ok = toolkit.loadData(xml);
  const pages = toolkit.getPageCount();
  const svg = toolkit.renderToSVG(1, {});
  const classNote = (svg.match(/class="note"/g) || []).length;
  console.log(
    o.name,
    "loadOk=" + ok,
    "pages=" + pages,
    "svgLen=" + svg.length,
    "classNote=" + classNote,
  );
}
