"""R10: 诀别书 m70–m71 left hand up a fourth.

PDF page 3, the m70 bass chord sits at C3 / C4+E4+G4, not the file's
F2 / F3+A3+C4. m71 is the same pattern and the same staff-position
offset. No printed accidentals. Not a promotion to formal.
"""
from __future__ import annotations

import shutil
import subprocess
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


def fix_top_c(measure: ET.Element) -> int:
    """The original C4 was skipped because it was already C. It is the
    chord tone after E4 and should be G4."""
    n = 0
    prev_was_e = False
    for note in measure:
        if local(note.tag) != "note":
            prev_was_e = False
            continue
        staff = next((c.text for c in note if local(c.tag) == "staff"), "1")
        if staff != "2":
            prev_was_e = False
            continue
        pitch = next((c for c in note if local(c.tag) == "pitch"), None)
        if pitch is None:
            prev_was_e = False
            continue
        step = next(c.text for c in pitch if local(c.tag) == "step")
        octave = next(c.text for c in pitch if local(c.tag) == "octave")
        is_chord = any(local(c.tag) == "chord" for c in note)
        if is_chord and prev_was_e and step == "C" and octave == "4":
            step_el = next(c for c in pitch if local(c.tag) == "step")
            step_el.text = "G"
            n += 1
        prev_was_e = step == "E" and octave == "4"
    return n


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    part = next(el for el in root if local(el.tag) == "part")
    changed = 0
    for measure in part:
        if local(measure.tag) != "measure":
            continue
        if measure.get("number") not in ("70", "71"):
            continue
        changed += fix_top_c(measure)
    if changed == 0:
        print("top Gs already in place")
    else:
        print(f"corrected {changed} chord tones to G4")
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
