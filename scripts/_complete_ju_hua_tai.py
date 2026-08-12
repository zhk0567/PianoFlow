# -*- coding: utf-8 -*-
"""Rewrite ju_hua_tai from PDF jianpu (1=F 4/4 ♩=76), still omrDraft until SOP.

Evidence: docs/omr_audit/_jianpu_proof/ju_hua_tai/pair_01..05.png
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from jianpu_to_musicxml import (  # noqa: E402
    DEGREE,
    dur_to_type,
    tonic_midi,
    write,
)
import xml.etree.ElementTree as ET

ASSET = ROOT / "assets" / "scores" / "musicxml" / "ju_hua_tai.musicxml"
THIRD = ROOT / "third_party" / "scores_musicxml" / "ju_hua_tai.musicxml"

# Events: (degree 1-7 or 0 rest, oct_shift, duration_quarters)
# oct_shift: 0=middle, -1=low dot, -2=two dots, +1=high dot


def deg(d: int, octs: int = 0, dur: float = 1.0):
    return (d, octs, dur)


def rest(dur: float = 1.0):
    return (0, 0, dur)


def to_midi(d: int, octs: int, key_midi: int) -> int | None:
    if d == 0:
        return None
    return key_midi + DEGREE[d] + 12 * octs


def pitch_flat_spell(midi: int) -> tuple[str, int, int]:
    """Prefer flats (F major: Bb not A#)."""
    pc = midi % 12
    octave = midi // 12 - 1
    mapping = {
        0: ("C", 0),
        1: ("D", -1),
        2: ("D", 0),
        3: ("E", -1),
        4: ("E", 0),
        5: ("F", 0),
        6: ("G", -1),
        7: ("G", 0),
        8: ("A", -1),
        9: ("A", 0),
        10: ("B", -1),
        11: ("B", 0),
    }
    step, alter = mapping[pc]
    return step, alter, octave


def build(rh_bars, lh_bars, *, title, artist, key, tempo) -> str:
    key_midi = tonic_midi(key)
    score = ET.Element("score-partwise", version="3.1")
    work = ET.SubElement(score, "work")
    ET.SubElement(work, "work-title").text = title
    ident = ET.SubElement(score, "identification")
    ET.SubElement(ident, "creator", type="composer").text = artist
    enc = ET.SubElement(ident, "encoding")
    ET.SubElement(enc, "software").text = "PianoFlow jianpu PDF proof"
    ET.SubElement(enc, "encoding-description").text = (
        "Transcribed from jianpu PDF (not Audiveris)."
    )
    pl = ET.SubElement(score, "part-list")
    sp = ET.SubElement(pl, "score-part", id="P1")
    ET.SubElement(sp, "part-name").text = "Piano"
    part = ET.SubElement(score, "part", id="P1")
    divisions = 4
    fifths = {"C": 0, "G": 1, "F": -1, "Bb": -2, "D": 2, "A": 3, "E": 4}.get(key, 0)

    def emit(measure, events, staff, voice):
        for d, octs, dur_q in events:
            dur = int(round(dur_q * divisions))
            if dur <= 0:
                continue
            note = ET.SubElement(measure, "note")
            midi = to_midi(d, octs, key_midi)
            if midi is None:
                ET.SubElement(note, "rest")
            else:
                step, alter, octave = pitch_flat_spell(midi)
                pitch = ET.SubElement(note, "pitch")
                ET.SubElement(pitch, "step").text = step
                if alter:
                    ET.SubElement(pitch, "alter").text = str(alter)
                ET.SubElement(pitch, "octave").text = str(octave)
            ET.SubElement(note, "duration").text = str(dur)
            ET.SubElement(note, "voice").text = str(voice)
            typ, dots, _ = dur_to_type(dur_q)
            ET.SubElement(note, "type").text = typ
            for _ in range(dots):
                ET.SubElement(note, "dot")
            ET.SubElement(note, "staff").text = str(staff)

    assert len(rh_bars) == len(lh_bars)
    for mi, (rh, lh) in enumerate(zip(rh_bars, lh_bars), start=1):
        m = ET.SubElement(part, "measure", number=str(mi))
        if mi == 1:
            attr = ET.SubElement(m, "attributes")
            ET.SubElement(attr, "divisions").text = str(divisions)
            key_el = ET.SubElement(attr, "key")
            ET.SubElement(key_el, "fifths").text = str(fifths)
            time_el = ET.SubElement(attr, "time")
            ET.SubElement(time_el, "beats").text = "4"
            ET.SubElement(time_el, "beat-type").text = "4"
            ET.SubElement(attr, "staves").text = "2"
            for n, sign, line in ((1, "G", 2), (2, "F", 4)):
                clef = ET.SubElement(attr, "clef", number=str(n))
                ET.SubElement(clef, "sign").text = sign
                ET.SubElement(clef, "line").text = str(line)
            direction = ET.SubElement(m, "direction", placement="above")
            dtype = ET.SubElement(direction, "direction-type")
            metro = ET.SubElement(dtype, "metronome")
            ET.SubElement(metro, "beat-unit").text = "quarter"
            ET.SubElement(metro, "per-minute").text = str(tempo)
            ET.SubElement(direction, "sound", tempo=str(tempo))
        emit(m, rh, 1, 1)
        backup = ET.SubElement(m, "backup")
        ET.SubElement(backup, "duration").text = str(4 * divisions)
        emit(m, lh, 2, 5)

    import xml.dom.minidom as minidom

    rough = ET.tostring(score, encoding="utf-8")
    return minidom.parseString(rough).toprettyxml(indent="  ", encoding="utf-8").decode(
        "utf-8"
    )


def lh_half(a: int, a_low_dots: int, b: int, b_low_dots: int):
    """LH half+half. low_dots: 1→oct−1, 2→oct−2 (vs middle 1=F4)."""
    return [deg(a, -a_low_dots, 2.0), deg(b, -b_low_dots, 2.0)]


def lh_whole(a: int, a_low_dots: int):
    return [deg(a, -a_low_dots, 4.0)]


def main() -> None:
    rh: list[list] = []
    lh: list[list] = []

    # --- pair_01 m1-4 (opening; LH dots from PDF: 1̣ 7̣̣ | 6̣̣ 5̣̣ | 4̣̣ 3̣̣ | 2̣̣ 5̣̣) ---
    rh += [
        [deg(3, 0, 1), deg(3, 0, 0.5), deg(2, 0, 0.5), deg(3, 0, 2)],
        [deg(3, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 0.5), deg(2, 0, 0.5), deg(3, 0, 2)],
        [deg(1, 0, 1), deg(1, 0, 0.5), deg(2, 0, 0.5), deg(3, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 1)],
        [deg(2, 0, 1), deg(2, 0, 0.5), deg(1, 0, 0.5), deg(2, 0, 2)],
    ]
    lh += [
        lh_half(1, 1, 7, 2),
        lh_half(6, 2, 5, 2),
        lh_half(4, 2, 3, 2),
        lh_half(2, 2, 5, 2),
    ]

    # --- pair_02 m5-9 (LH: 6̣̣3̣ | 4̣3̣ | 2̣2̣ | 5̣̣5̣̣ | 1̣7̣̣) ---
    # m5 RH: 3.(1.5) 5// 3// 6/ 5.(1.5)
    rh.append(
        [deg(3, 0, 1.5), deg(5, 0, 0.25), deg(3, 0, 0.25), deg(6, 0, 0.5), deg(5, 0, 1.5)]
    )
    lh.append(lh_half(6, 2, 3, 1))
    # m6: 65 53 5 —
    rh.append([deg(6, 0, 0.5), deg(5, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 0.5), deg(5, 0, 2)])
    lh.append(lh_half(4, 1, 3, 1))
    # m7: 3 23 5 32
    rh.append(
        [deg(3, 0, 1), deg(2, 0, 0.5), deg(3, 0, 0.5), deg(5, 0, 1), deg(3, 0, 0.5), deg(2, 0, 0.5)]
    )
    lh.append(lh_half(2, 1, 2, 1))
    # m8: 2 21 2 —
    rh.append([deg(2, 0, 1), deg(2, 0, 0.5), deg(1, 0, 0.5), deg(2, 0, 2)])
    lh.append(lh_half(5, 2, 5, 2))
    # m9: 3 32 3 —
    rh.append([deg(3, 0, 1), deg(3, 0, 0.5), deg(2, 0, 0.5), deg(3, 0, 2)])
    lh.append(lh_half(1, 1, 7, 2))

    # --- pair_03 m10-14 (LH: 6̣̣5̣̣ | 4̣3̣ | 2̣5̣ | 6̣̣3̣ | 4̣3̣) ---
    rh += [
        [deg(3, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 0.5), deg(2, 0, 0.5), deg(3, 0, 2)],
        [deg(1, 0, 1), deg(1, 0, 0.5), deg(2, 0, 0.5), deg(3, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 1)],
        [deg(2, 0, 1), deg(2, 0, 0.5), deg(1, 0, 0.5), deg(2, 0, 2)],
        [deg(3, 0, 1.5), deg(5, 0, 0.25), deg(3, 0, 0.25), deg(6, 0, 0.5), deg(5, 0, 1.5)],
        [deg(6, 0, 0.5), deg(5, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 0.5), deg(5, 0, 2)],
    ]
    lh += [
        lh_half(6, 2, 5, 2),
        lh_half(4, 1, 3, 1),
        lh_half(2, 1, 5, 1),
        lh_half(6, 2, 3, 1),
        lh_half(4, 1, 3, 1),
    ]

    # --- pair_04 m15-19 (LH all one-dot; m16 RH locked from zoom_m16) ---
    rh += [
        [deg(3, 0, 1), deg(2, 0, 0.5), deg(3, 0, 0.5), deg(5, 0, 1), deg(3, 0, 0.5), deg(2, 0, 0.5)],
        # m16: 2_(0.5) 1.(1.5) 0(1.0) 12_(0.5+0.5) = 4
        [deg(2, 0, 0.5), deg(1, 0, 1.5), rest(1.0), deg(1, 0, 0.5), deg(2, 0, 0.5)],
        [deg(3, 0, 1), deg(3, 0, 0.5), deg(5, 0, 0.5), deg(6, 0, 1), deg(6, 0, 0.5), deg(3, 1, 0.5)],
        [deg(2, 1, 0.5), deg(1, 1, 0.5), deg(1, 1, 0.5), deg(6, 0, 0.5), deg(5, 0, 2)],
        [deg(6, 0, 0.5), deg(5, 0, 0.5), deg(3, 0, 0.5), deg(2, 0, 0.5), deg(1, 0, 1), deg(6, -1, 0.5), deg(1, 0, 0.5)],
    ]
    lh += [
        lh_half(2, 1, 5, 1),
        lh_whole(1, 1),
        lh_half(1, 1, 4, 1),
        lh_half(2, 1, 3, 1),
        lh_half(4, 1, 3, 1),
    ]

    # --- pair_05 m20-24 (LH all one-dot) ---
    rh += [
        [deg(2, 0, 1), deg(2, 0, 0.5), deg(1, 0, 0.5), deg(2, 0, 1), deg(1, 0, 0.5), deg(2, 0, 0.5)],
        [deg(3, 0, 1), deg(3, 0, 0.5), deg(5, 0, 0.5), deg(6, 0, 1), deg(6, 0, 0.5), deg(3, 1, 0.5)],
        [deg(2, 1, 0.5), deg(1, 1, 0.5), deg(1, 1, 0.5), deg(2, 1, 0.5), deg(1, 1, 2)],
        [deg(5, 0, 1), deg(5, 0, 0.5), deg(3, 0, 0.5), deg(7, 0, 0.5), deg(1, 1, 0.5), deg(1, 0, 0.5), deg(2, 0, 0.5)],
        [deg(3, 0, 2), deg(2, 0, 2)],
    ]
    lh += [
        lh_half(2, 1, 5, 1),
        lh_half(1, 1, 4, 1),
        lh_half(4, 1, 4, 1),
        lh_half(3, 1, 6, 1),
        lh_half(2, 1, 5, 1),
    ]

    xml = build(
        rh,
        lh,
        title="菊花台",
        artist="周杰伦",
        key="F",
        tempo=76,
    )
    write(ASSET, xml)
    THIRD.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ASSET, THIRD)
    print(f"[PianoFlow/jianpu] ju_hua_tai wrote {len(rh)} measures")
    subprocess.check_call(
        [
            sys.executable,
            str(ROOT / "scripts" / "musicxml_to_score.py"),
            "--id",
            "ju_hua_tai",
            "--input",
            str(ASSET),
            "--update-catalog",
            "--score-kind",
            "omrDraft",
        ],
        cwd=str(ROOT),
    )


if __name__ == "__main__":
    main()
