#!/usr/bin/env python3
"""Install Megalovania MusicXML into PianoFlow formal-score paths.

CRITICAL — score accuracy is the #1 priority for shipped formal scores.
Do NOT convert from MIDI (music21 / converter.parse on .mid). MIDI loses
voices, staves, accidental spelling, and beams; Verovio then shows colliding
noteheads and redundant accidentals. That path is forbidden for formal scores.

Canonical musical source must match the user PDF:
  third_party/scores_musicxml/_omr_work/megalovania/source.pdf
  (Megalovania — Toby Fox — q=120 — D minor — 4/4 — piano, 8vb clefs, 4 pages)

Place a matching notation file here first:
  third_party/scores_musicxml/_omr_work/megalovania/megalovania_piano.musicxml
  (or .mxl — extracted automatically)

Then:
  python .\\scripts\\build_megalovania.py
  python .\\scripts\\musicxml_to_score.py --id toby_fox_megalovania --update-catalog

See _omr_work/megalovania/README_SOURCE.txt for PDF ID and blocked download notes.
"""

from __future__ import annotations

import shutil
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
WORK = REPO / "third_party" / "scores_musicxml" / "_omr_work" / "megalovania"
OUT_ID = "toby_fox_megalovania"
SRC_XML = REPO / "third_party" / "scores_musicxml" / f"{OUT_ID}.musicxml"
ASSET_XML = REPO / "assets" / "scores" / "musicxml" / f"{OUT_ID}.musicxml"

TITLE = "Megalovania"
COMPOSER = "Toby Fox"
BPM_FALLBACK = 120  # PDF marks quarter = 120


def _strip_ns(root: ET.Element) -> None:
    for el in root.iter():
        if "}" in el.tag:
            el.tag = el.tag.split("}", 1)[1]


def _ensure_child(
    parent: ET.Element, tag: str, *, text: str | None = None, index: int = 0
) -> ET.Element:
    for c in parent:
        if c.tag == tag:
            if text is not None:
                c.text = text
            return c
    el = ET.Element(tag)
    if text is not None:
        el.text = text
    parent.insert(index, el)
    return el


def _patch_metadata(root: ET.Element) -> None:
    work = root.find("work")
    if work is None:
        work = ET.Element("work")
        root.insert(0, work)
    _ensure_child(work, "work-title", text=TITLE)

    ident = root.find("identification")
    if ident is None:
        ident = ET.Element("identification")
        root.insert(1, ident)

    creator = None
    for c in ident.findall("creator"):
        if c.get("type") == "composer":
            creator = c
            break
    if creator is None:
        creator = ET.Element("creator", {"type": "composer"})
        ident.insert(0, creator)
    creator.text = COMPOSER

    rights = ident.find("rights")
    if rights is None:
        rights = ET.Element("rights")
        ident.append(rights)
    rights.text = (
        "Undertale © Toby Fox. Arrangement for local PianoFlow practice; "
        "not Public Domain. Keep attribution. Do not ship MIDI→MusicXML."
    )

    encoding = ident.find("encoding")
    if encoding is None:
        encoding = ET.Element("encoding")
        ident.append(encoding)
    soft = encoding.find("software")
    if soft is None:
        soft = ET.Element("software")
        encoding.insert(0, soft)
    soft.text = "PianoFlow build_megalovania.py (notation MusicXML; NOT from MIDI)"

    # Ensure a tempo sound exists somewhere in first measure if missing
    part = root.find("part")
    if part is not None:
        m0 = next(iter(part.findall("measure")), None)
        if m0 is not None:
            has_tempo = False
            for d in m0.findall("direction"):
                sound = d.find("sound")
                if sound is not None and "tempo" in sound.attrib:
                    has_tempo = True
                    break
            if not has_tempo:
                direction = ET.Element("direction", {"placement": "above"})
                dt = ET.SubElement(direction, "direction-type")
                metro = ET.SubElement(dt, "metronome")
                bu = ET.SubElement(metro, "beat-unit")
                bu.text = "quarter"
                pm = ET.SubElement(metro, "per-minute")
                pm.text = str(BPM_FALLBACK)
                sound = ET.SubElement(direction, "sound", {"tempo": str(BPM_FALLBACK)})
                # Insert after attributes if present
                attrs = m0.find("attributes")
                if attrs is not None:
                    idx = list(m0).index(attrs) + 1
                    m0.insert(idx, direction)
                else:
                    m0.insert(0, direction)


def _load_canonical() -> Path:
    candidates = [
        WORK / "megalovania_piano.musicxml",
        WORK / "megalovania_piano.xml",
        WORK / "megalovania_piano.mxl",
        WORK / "score.musicxml",
        WORK / "score.mxl",
    ]
    for p in candidates:
        if p.exists():
            return p
    raise FileNotFoundError(
        "No matching MusicXML in _omr_work/megalovania/.\n"
        "Place megalovania_piano.musicxml (PDF-matched, NOT from MIDI) then re-run.\n"
        "See README_SOURCE.txt — MuseScore 1352796 does not match this PDF."
    )


def _read_xml(path: Path) -> ET.Element:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path, "r") as zf:
            names = [
                n
                for n in zf.namelist()
                if n.lower().endswith((".xml", ".musicxml"))
                and not n.startswith("META-INF")
            ]
            if not names:
                raise ValueError(f"No MusicXML inside {path}")
            data = zf.read(names[0])
        return ET.fromstring(data)
    return ET.parse(path).getroot()


def main() -> int:
    WORK.mkdir(parents=True, exist_ok=True)
    try:
        src = _load_canonical()
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 2

    root = _read_xml(src)
    _strip_ns(root)
    if "score-partwise" not in root.tag:
        print("Expected score-partwise MusicXML", file=sys.stderr)
        return 1
    _patch_metadata(root)

    # Pretty-ish write
    try:
        ET.indent(root, space="  ")
    except AttributeError:
        pass
    xml_bytes = ET.tostring(root, encoding="utf-8", xml_declaration=True)

    canonical = WORK / "megalovania_piano.musicxml"
    if src.resolve() != canonical.resolve():
        canonical.write_bytes(xml_bytes)
    else:
        canonical.write_bytes(xml_bytes)

    SRC_XML.parent.mkdir(parents=True, exist_ok=True)
    ASSET_XML.parent.mkdir(parents=True, exist_ok=True)
    SRC_XML.write_bytes(xml_bytes)
    shutil.copy2(SRC_XML, ASSET_XML)
    print(f"Installed {OUT_ID} from {src.name}")
    print(f"  -> {SRC_XML}")
    print(f"  -> {ASSET_XML}")
    print("Next: python .\\scripts\\musicxml_to_score.py --id toby_fox_megalovania --update-catalog")
    return 0


if __name__ == "__main__":
    sys.exit(main())
