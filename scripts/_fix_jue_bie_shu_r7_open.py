"""Rewrite jue_bie_shu OPEN m1-8 from PDF p1 system evidence (R7). Not MIDI.

Evidence: docs/omr_audit/_jue_bie_shu_proof/r7_p1_s1_lines.png (m1-6),
r7_p1_s2.png (m7-8). Prior XML D5-C5-D5-F5 opening disagreed with PDF
F4-G4-A4 motif — rewrite with system-level consensus.
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


def note(
    step: str,
    octave: int,
    dur: int,
    typ: str,
    *,
    staff: int,
    voice: int,
    alter: int | None = None,
    chord: bool = False,
    dot: bool = False,
) -> ET.Element:
    n = ET.Element("note")
    if chord:
        ET.SubElement(n, "chord")
    p = ET.SubElement(n, "pitch")
    ET.SubElement(p, "step").text = step
    if alter is not None:
        ET.SubElement(p, "alter").text = str(alter)
    ET.SubElement(p, "octave").text = str(octave)
    ET.SubElement(n, "duration").text = str(dur)
    ET.SubElement(n, "voice").text = str(voice)
    ET.SubElement(n, "type").text = typ
    if dot:
        ET.SubElement(n, "dot")
    ET.SubElement(n, "staff").text = str(staff)
    return n


def backup(dur: int = 16) -> ET.Element:
    b = ET.Element("backup")
    ET.SubElement(b, "duration").text = str(dur)
    return b


def clear_notes(m: ET.Element) -> None:
    for el in list(m):
        if local(el.tag) in ("note", "backup", "forward"):
            m.remove(el)


def chord_notes(tones: list[tuple], dur: int, typ: str, *, staff: int, voice: int, dot: bool = False):
    out = []
    first = True
    for t in tones:
        step, octv = t[0], t[1]
        alt = t[2] if len(t) > 2 else None
        out.append(
            note(step, octv, dur, typ, staff=staff, voice=voice, alter=alt, chord=not first, dot=dot)
        )
        first = False
    return out


def motif(long_step: str, long_oct: int, long_alter: int | None = None):
    """F4 q + G4 A4 8ths + long half."""
    return [
        note("F", 4, 4, "quarter", staff=1, voice=1),
        note("G", 4, 2, "eighth", staff=1, voice=1),
        note("A", 4, 2, "eighth", staff=1, voice=1),
        note(long_step, long_oct, 8, "half", staff=1, voice=1, alter=long_alter),
    ]


def bass_q_then_chord(bass: tuple, tones: list[tuple]):
    """Bass quarter + dotted-half chord (beats 2-4)."""
    return [
        note(*bass, 4, "quarter", staff=2, voice=5),
        *chord_notes(tones, 12, "half", staff=2, voice=5, dot=True),
    ]


def build() -> dict[int, list[ET.Element]]:
    bbdf = [("B", 2, -1), ("D", 3), ("F", 3)]
    acf = [("A", 2), ("C", 3), ("F", 3)]
    gbbdf = [("G", 2), ("B", 2, -1), ("D", 3), ("F", 3)]

    m: dict[int, list[ET.Element]] = {}
    m[1] = motif("D", 5) + [backup()] + bass_q_then_chord(("F", 2), bbdf)
    m[2] = (
        [note("D", 5, 16, "whole", staff=1, voice=1)]
        + [backup()]
        + chord_notes(bbdf, 16, "whole", staff=2, voice=5)
    )
    m[3] = motif("C", 5) + [backup()] + bass_q_then_chord(("F", 2), acf)
    m[4] = (
        [note("C", 5, 16, "whole", staff=1, voice=1)]
        + [backup()]
        + chord_notes(acf, 16, "whole", staff=2, voice=5)
    )
    m[5] = motif("B", 4, -1) + [backup()] + bass_q_then_chord(("F", 2), gbbdf)
    m[6] = (
        [note("B", 4, 16, "whole", staff=1, voice=1, alter=-1)]
        + [backup()]
        + chord_notes(gbbdf, 16, "whole", staff=2, voice=5)
    )
    # m7-8 from p1 system 2
    m[7] = (
        [
            note("C", 6, 4, "quarter", staff=1, voice=1),
            note("A", 5, 2, "eighth", staff=1, voice=1),
            note("G", 5, 2, "eighth", staff=1, voice=1),
            note("F", 5, 8, "half", staff=1, voice=1),
        ]
        + [backup()]
        + [
            note("F", 2, 4, "quarter", staff=2, voice=5),
            note("C", 3, 4, "quarter", staff=2, voice=5),
            note("F", 3, 4, "quarter", staff=2, voice=5),
            note("G", 3, 4, "quarter", staff=2, voice=5),
        ]
    )
    m[8] = (
        [note("F", 5, 16, "whole", staff=1, voice=1)]
        + [backup()]
        + [note("G", 3, 16, "whole", staff=2, voice=5)]
    )
    return m


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    ns = root.tag.split("}")[0] + "}" if root.tag.startswith("{") else ""

    def q(name: str) -> str:
        return f"{ns}{name}" if ns else name

    part = root.find(q("part"))
    assert part is not None
    by_num = {int(m.get("number")): m for m in part.findall(q("measure"))}
    for num, els in build().items():
        m = by_num[num]
        clear_notes(m)
        for el in els:
            m.append(el)
        print(f"rewrote m{num}")

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
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
