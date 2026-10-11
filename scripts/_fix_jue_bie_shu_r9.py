"""R9: 诀别书 m13 lower-staff A3 whole, tied into m14.

PDF p1 system (m13–14): lower staff is still treble. Under the quarter-rest
chords there is a whole note on the first ledger below the staff (A3), tied
into the same A3 whole in m14. The file had the m14 note and the bass clef
only after m14's notes (so m15 is bass). m13's A3 was missing.

Not a promotion to formal.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
ASSET = REPO / "assets/scores/musicxml/jue_bie_shu.musicxml"
SYNC_XML = [
    REPO / "third_party/scores_musicxml/jue_bie_shu.musicxml",
    REPO / "clients/web/scores/musicxml/jue_bie_shu.musicxml",
    REPO / "clients/android/app/src/main/assets/scores/musicxml/jue_bie_shu.musicxml",
]
SYNC_JSON = [
    REPO / "clients/web/scores/jue_bie_shu.json",
    REPO / "clients/android/app/src/main/assets/scores/jue_bie_shu.json",
]


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def is_a3_whole(note: ET.Element) -> bool:
    if local(note.tag) != "note":
        return False
    pitch = next((c for c in note if local(c.tag) == "pitch"), None)
    if pitch is None:
        return False
    step = next((c.text for c in pitch if local(c.tag) == "step"), None)
    octave = next((c.text for c in pitch if local(c.tag) == "octave"), None)
    voice = next((c.text for c in note if local(c.tag) == "voice"), None)
    ntype = next((c.text for c in note if local(c.tag) == "type"), None)
    return step == "A" and octave == "3" and voice == "6" and ntype == "whole"


def add_tie(note: ET.Element, kind: str) -> None:
    if any(local(c.tag) == "tie" and c.get("type") == kind for c in note):
        return
    tie = ET.Element("tie", type=kind)
    # before staff/notations if present; after type
    insert_at = len(list(note))
    for i, c in enumerate(list(note)):
        if local(c.tag) in ("staff", "notations"):
            insert_at = i
            break
    note.insert(insert_at, tie)
    notations = next((c for c in note if local(c.tag) == "notations"), None)
    if notations is None:
        notations = ET.Element("notations")
        note.append(notations)
    if not any(local(c.tag) == "tied" and c.get("type") == kind for c in notations):
        attrs = {"type": kind}
        if kind == "start":
            attrs["orientation"] = "under"
        ET.SubElement(notations, "tied", attrs)


def whole_a3(tie: str) -> ET.Element:
    note = ET.Element("note", {"default-x": "11"})
    pitch = ET.SubElement(note, "pitch")
    ET.SubElement(pitch, "step").text = "A"
    ET.SubElement(pitch, "octave").text = "3"
    ET.SubElement(note, "duration").text = "16"
    ET.SubElement(note, "tie", type=tie)
    ET.SubElement(note, "voice").text = "6"
    ET.SubElement(note, "type").text = "whole"
    ET.SubElement(note, "staff").text = "2"
    notations = ET.SubElement(note, "notations")
    tied_attrs = {"type": tie}
    if tie == "start":
        tied_attrs["orientation"] = "under"
    ET.SubElement(notations, "tied", tied_attrs)
    return note


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    part = next(el for el in root if local(el.tag) == "part")
    by_num = {int(m.get("number")): m for m in part if local(m.tag) == "measure"}

    m13 = by_num[13]
    if not any(is_a3_whole(n) for n in m13):
        ET.SubElement(m13, "backup").text = None
        backup = m13[-1]
        # backup needs a duration child
        dur = ET.SubElement(backup, "duration")
        dur.text = "16"
        m13.append(whole_a3("start"))
        print("added m13 A3 whole tie-start")
    else:
        print("m13 A3 already present")

    m14 = by_num[14]
    targets = [n for n in m14 if is_a3_whole(n)]
    if len(targets) != 1:
        print(f"expected one m14 A3 whole, found {len(targets)}", file=sys.stderr)
        return 1
    add_tie(targets[0], "stop")
    print("m14 A3 tie-stop")

    tree.write(ASSET, encoding="utf-8", xml_declaration=True)
    for dest in SYNC_XML:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ASSET, dest)
    r = subprocess.run(
        [sys.executable, "-u", str(REPO / "scripts/musicxml_to_score.py"), "--id", "jue_bie_shu"],
        cwd=REPO,
    )
    if r.returncode != 0:
        return r.returncode
    src_json = REPO / "assets/scores/jue_bie_shu.json"
    for dest in SYNC_JSON:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_json, dest)
    print("synced; still omrDraft")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
