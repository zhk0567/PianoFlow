# -*- coding: utf-8 -*-
"""Force MusicXML + catalog BPM to PDF-verified metronome marks (omrDraft only)."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets" / "scores" / "catalog.json"
XML_DIR = REPO / "assets" / "scores" / "musicxml"
TP_DIR = REPO / "third_party" / "scores_musicxml"

# PDF header consensus (multiple crops agree). Values are MusicXML sound tempo /
# catalog bpm as used by practice (written metronome number).
PDF_TEMPO = {
    "sawano_call_of_silence": 60,  # quarter=60
    "ru_yuan": 66,  # quarter=66
    "jay_chou_qing_tian": 68,  # quarter=68
    "christina_perri_a_thousand_years": 50,  # dotted-quarter=50
    "radwimps_suzume": 80,  # quarter=80
    "rush_e": 40,  # quarter=40
}


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def set_tempo_xml(root: ET.Element, bpm: int, *, dotted: bool = False) -> bool:
    changed = False
    for el in root.iter():
        if local(el.tag) == "per-minute" and el.text and el.text.strip() != str(bpm):
            el.text = str(bpm)
            changed = True
        if local(el.tag) == "sound" and "tempo" in el.attrib:
            if el.attrib.get("tempo") != str(float(bpm)) and el.attrib.get("tempo") != str(bpm):
                el.attrib["tempo"] = str(float(bpm))
                changed = True
        if dotted and local(el.tag) == "metronome":
            # ensure beat-unit is dotted quarter when PDF says so
            units = [c for c in list(el) if local(c.tag) == "beat-unit"]
            dots = [c for c in list(el) if local(c.tag) == "beat-unit-dot"]
            if units and (units[0].text or "").strip() != "quarter":
                units[0].text = "quarter"
                changed = True
            if not dots and units:
                idx = list(el).index(units[0]) + 1
                el.insert(idx, ET.Element("beat-unit-dot"))
                changed = True
    return changed


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in catalog["songs"]}
    for sid, bpm in PDF_TEMPO.items():
        xml_path = XML_DIR / f"{sid}.musicxml"
        if not xml_path.is_file():
            print("[skip]", sid)
            continue
        tree = ET.parse(xml_path)
        root = tree.getroot()
        dotted = sid == "christina_perri_a_thousand_years"
        xml_changed = set_tempo_xml(root, bpm, dotted=dotted)
        if xml_changed:
            tree.write(xml_path, encoding="utf-8", xml_declaration=True)
            TP_DIR.mkdir(parents=True, exist_ok=True)
            shutil.copy2(xml_path, TP_DIR / f"{sid}.musicxml")
            print(f"[xml] {sid} -> {bpm}")
        else:
            print(f"[xml] {sid} already {bpm} (or no tempo node)")
        song = by_id.get(sid)
        if song is not None and song.get("bpm") != bpm:
            song["bpm"] = bpm
            print(f"[catalog] {sid} bpm -> {bpm}")
        # re-convert to sync JSON bpm from MusicXML
        cmd = [
            sys.executable,
            str(REPO / "scripts" / "musicxml_to_score.py"),
            "--id",
            sid,
            "--input",
            str(xml_path),
            "--update-catalog",
            "--score-kind",
            "omrDraft",
        ]
        subprocess.check_call(cmd, cwd=str(REPO))
        # musicxml_to_score may overwrite catalog bpm from XML; force again
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        for s in catalog["songs"]:
            if s["id"] == sid:
                s["bpm"] = bpm
        CATALOG.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        # also patch score JSON bpm if present
        score_path = REPO / "assets" / "scores" / f"{sid}.json"
        if score_path.is_file():
            data = json.loads(score_path.read_text(encoding="utf-8"))
            if data.get("bpm") != bpm:
                data["bpm"] = bpm
                score_path.write_text(
                    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8",
                )
                print(f"[json] {sid} bpm -> {bpm}")
    print("[PianoFlow/omr] PDF tempos forced for", ", ".join(PDF_TEMPO))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
