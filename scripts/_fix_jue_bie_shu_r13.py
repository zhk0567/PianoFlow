"""R13: more PDF-confirmed rewrites. Still omrDraft."""
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

# Reuse helpers by importing r12
sys.path.insert(0, str(REPO / "scripts"))
from _fix_jue_bie_shu_r12 import clear_music, emit, first_rh, local, pitch_of  # noqa: E402


def keep_lh(measure: ET.Element):
    lh = []
    for el in list(measure):
        if local(el.tag) != "note":
            continue
        staff = next((c.text for c in el if local(c.tag) == "staff"), "1")
        if staff != "2":
            continue
        p = pitch_of(el)
        if p is None:
            continue
        pitch = next(c for c in el if local(c.tag) == "pitch")
        alt = next((c.text for c in pitch if local(c.tag) == "alter"), None)
        tone = (p[0], p[1], int(alt)) if alt is not None else p
        typ = next((c.text for c in el if local(c.tag) == "type"), "eighth")
        dur = int(next(c.text for c in el if local(c.tag) == "duration"))
        if not any(local(c.tag) == "chord" for c in el):
            lh.append([[tone], dur, typ])
        else:
            lh[-1][0].append(tone)
    return lh


def main() -> int:
    tree = ET.parse(ASSET)
    part = next(el for el in tree.getroot() if local(el.tag) == "part")
    by_num = {m.get("number"): m for m in part if local(m.tag) == "measure"}
    done = []

    m = by_num["48"]
    if first_rh(m) == ("D", 6):
        lh = keep_lh(m)
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("C", 6)], 1, "16th"),
                    ([("D", 6)], 1, "16th"),
                    ([("C", 6)], 1, "16th"),
                    ([("D", 6)], 1, "16th"),
                    ([("C", 6)], 2, "eighth"),
                    ([("A", 5)], 2, "eighth"),
                    ([("C", 6)], 4, "quarter"),
                    ([("D", 5), ("D", 6)], 2, "eighth"),
                    ([("E", 5), ("E", 6)], 2, "eighth"),
                ],
                2: lh,
            },
        )
        done.append("48")

    m = by_num["50"]
    if first_rh(m) == ("A", 5):
        lh = keep_lh(m)
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("A", 5), ("E", 6)], 6, "quarter", {"dots": 1}),
                    ([("C", 5), ("E", 5), ("A", 5), ("C", 6)], 2, "eighth"),
                    ([("C", 5), ("E", 5), ("A", 5), ("C", 6)], 8, "half"),
                ],
                2: lh,
            },
        )
        done.append("50")

    m = by_num["51"]
    if first_rh(m) == ("E", 5):
        lh = keep_lh(m)
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("F", 5), ("C", 6)], 6, "quarter", {"dots": 1}),
                    ([("A", 4), ("C", 5), ("F", 5), ("A", 5)], 2, "eighth"),
                    ([("A", 4), ("C", 5), ("F", 5), ("A", 5)], 8, "half"),
                ],
                2: lh,
            },
        )
        done.append("51")

    m = by_num["76"]
    if first_rh(m) == ("G", 4) and any(pitch_of(n) == ("C", 2) for n in m if local(n.tag) == "note"):
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("G", 4)], 1, "16th"),
                    ([("F", 4)], 1, "16th"),
                    ([("E", 4)], 1, "16th"),
                    ([("D", 4)], 1, "16th"),
                    ([("F", 4)], 2, "eighth"),
                    ([("E", 4)], 2, "eighth"),
                    ([("G", 4)], 2, "eighth"),
                    ([("E", 4)], 2, "eighth"),
                    ([("C", 5)], 2, "eighth"),
                    ([("E", 4)], 2, "eighth"),
                ],
                2: [
                    ([("D", 3)], 4, "quarter"),
                    ([("D", 4), ("F", 4), ("A", 4)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 2, "eighth"),
                    ([("A", 3), ("C", 4)], 4, "quarter"),
                    ([("F", 3), ("A", 3), ("C", 4)], 4, "quarter"),
                ],
            },
        )
        done.append("76")

    m = by_num["87"]
    if first_rh(m) == ("F", 5):
        lh = keep_lh(m)
        # Raise chord tones that are F3+A3+C4 stay; only rewrite RH from scan.
        clear_music(m)
        emit(
            m,
            {
                1: [
                    ([("D", 5)], 1, "16th"),
                    ([("E", 5)], 1, "16th"),
                    ([("F", 5)], 1, "16th"),
                    ([("G", 5)], 1, "16th"),
                    ([("A", 5)], 1, "16th"),
                    ([("G", 5)], 1, "16th"),
                    ([("F", 5)], 1, "16th"),
                    ([("G", 5)], 1, "16th"),
                    ([("A", 5)], 1, "16th"),
                    ([("C", 6)], 1, "16th"),
                    ([("A", 5)], 1, "16th"),
                    ([("G", 5)], 1, "16th"),
                    ([("C", 6)], 1, "16th"),
                    ([("C", 6)], 1, "16th"),
                    ([("E", 6)], 1, "16th"),
                    ([("C", 6)], 1, "16th"),
                ],
                2: lh,
            },
        )
        done.append("87")

    print("rewrote", ",".join(done) if done else "nothing")
    if done:
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
    src = REPO / "assets/scores/jue_bie_shu.json"
    for dest in SYNC_JSON:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
    print("synced; still omrDraft")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
