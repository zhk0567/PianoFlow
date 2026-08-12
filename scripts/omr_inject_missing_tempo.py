# -*- coding: utf-8 -*-
"""Inject <sound tempo="..."/> into MusicXML measure 1 when missing; re-convert JSON."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets" / "scores" / "catalog.json"
XML_DIR = REPO / "assets" / "scores" / "musicxml"
TP_DIR = REPO / "third_party" / "scores_musicxml"

# Explicit PDF-verified overrides (otherwise use catalog bpm)
TEMPO_OVERRIDE = {
    "rush_e": 40,  # PDF marking at start (accelerando later)
}


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def has_tempo(root: ET.Element) -> bool:
    for el in root.iter():
        if local(el.tag) == "sound" and "tempo" in el.attrib:
            return True
        if local(el.tag) == "per-minute":
            return True
    return False


def inject_tempo(root: ET.Element, bpm: float) -> bool:
    if has_tempo(root):
        return False
    part = None
    for el in root:
        if local(el.tag) == "part":
            part = el
            break
    if part is None:
        return False
    measure = None
    for el in part:
        if local(el.tag) == "measure":
            measure = el
            break
    if measure is None:
        return False
    # Insert direction after attributes if present
    direction = ET.Element("direction", placement="above")
    dtype = ET.SubElement(direction, "direction-type")
    metro = ET.SubElement(dtype, "metronome")
    ET.SubElement(metro, "beat-unit").text = "quarter"
    ET.SubElement(metro, "per-minute").text = str(int(bpm))
    ET.SubElement(direction, "sound", tempo=str(bpm))
    # find insert index
    idx = 0
    for i, child in enumerate(list(measure)):
        if local(child.tag) == "attributes":
            idx = i + 1
            break
    measure.insert(idx, direction)
    return True


def main() -> int:
    songs = json.loads(CATALOG.read_text(encoding="utf-8"))["songs"]
    omr = [s for s in songs if s.get("scoreKind") == "omrDraft"]
    changed = []
    for s in omr:
        sid = s["id"]
        bpm = TEMPO_OVERRIDE.get(sid, s.get("bpm") or 100)
        xml_path = XML_DIR / f"{sid}.musicxml"
        if not xml_path.is_file():
            print("skip missing", sid)
            continue
        # Preserve namespaces roughly by parsing without ns strip issues
        tree = ET.parse(xml_path)
        root = tree.getroot()
        if not inject_tempo(root, float(bpm)):
            print("skip has-tempo-or-fail", sid)
            continue
        # write both asset + third_party
        tree.write(xml_path, encoding="utf-8", xml_declaration=True)
        tp = TP_DIR / f"{sid}.musicxml"
        if tp.is_file():
            tree.write(tp, encoding="utf-8", xml_declaration=True)
        print("injected", sid, "tempo", bpm)
        changed.append(sid)

    for sid in changed:
        cmd = [
            sys.executable,
            str(REPO / "scripts" / "musicxml_to_score.py"),
            "--id",
            sid,
            "--input",
            str(XML_DIR / f"{sid}.musicxml"),
            "--update-catalog",
            "--score-kind",
            "omrDraft",
        ]
        # keep title/artist from catalog by not overriding unless needed
        song = next(x for x in omr if x["id"] == sid)
        if song.get("title"):
            cmd += ["--title", song["title"]]
        if song.get("artist"):
            cmd += ["--artist", song["artist"]]
        if song.get("genre"):
            cmd += ["--genre", song["genre"]]
        if song.get("difficulty") is not None:
            cmd += ["--difficulty", str(song["difficulty"])]
        if song.get("description"):
            cmd += ["--description", song["description"]]
        print("+", " ".join(cmd))
        subprocess.run(cmd, cwd=str(REPO), check=True)

    print("changed", len(changed), changed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
