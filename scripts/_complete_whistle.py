# -*- coding: utf-8 -*-
"""Rewrite whistle from PDF jianpu (1=C 4/4 ♩=120), still omrDraft until SOP.

Evidence: docs/omr_audit/_jianpu_proof/whistle/p1.png + _zoom/W*.png
PDF: 7 systems ≈28 measures (XML was 16).
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from jianpu_to_musicxml import DEGREE, dur_to_type, tonic_midi, write  # noqa: E402
import xml.etree.ElementTree as ET

ASSET = ROOT / "assets" / "scores" / "musicxml" / "whistle.musicxml"
THIRD = ROOT / "third_party" / "scores_musicxml" / "whistle.musicxml"


def deg(d: int, octs: int = 0, dur: float = 1.0):
    return (d, octs, dur)


def rest(dur: float = 1.0):
    return (0, 0, dur)


def to_midi(d: int, octs: int, key_midi: int) -> int | None:
    if d == 0:
        return None
    return key_midi + DEGREE[d] + 12 * octs


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
    fifths = 0

    def emit(measure, events, staff, voice):
        for item in events:
            if len(item) == 4 and item[3] == "chord":
                d, octs, dur_q, _ = item
                chord = True
            else:
                d, octs, dur_q = item[:3]
                chord = False
            dur = int(round(dur_q * divisions))
            if dur <= 0:
                continue
            note = ET.SubElement(measure, "note")
            midi = to_midi(d, octs, key_midi)
            if midi is None:
                ET.SubElement(note, "rest")
            else:
                if chord:
                    ET.SubElement(note, "chord")
                step_alter = {
                    0: ("C", 0),
                    1: ("C", 1),
                    2: ("D", 0),
                    3: ("D", 1),
                    4: ("E", 0),
                    5: ("F", 0),
                    6: ("F", 1),
                    7: ("G", 0),
                    8: ("G", 1),
                    9: ("A", 0),
                    10: ("A", 1),
                    11: ("B", 0),
                }
                step, alter = step_alter[midi % 12]
                octave = midi // 12 - 1
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


def lh_dot(root: int, fifth: int, root_oct: int, fifth_oct: int):
    """q q dotted-q e-rest (intro bass)."""
    return [
        deg(root, root_oct, 1.0),
        deg(fifth, fifth_oct, 1.0),
        deg(root, root_oct, 1.5),
        rest(0.5),
    ]


def lh_pulse(root: int, fifth: int, root_oct: int, fifth_oct: int):
    return [
        deg(root, root_oct, 1.0),
        deg(fifth, fifth_oct, 1.0),
        deg(root, root_oct, 1.0),
        deg(fifth, fifth_oct, 1.0),
    ]


def lh_am_dot():
    return lh_dot(6, 3, -2, -2)


def lh_f_dot():
    return lh_dot(4, 1, -2, -2)


def lh_c_dot():
    return lh_dot(1, 5, -1, -2)


def lh_g_dot():
    return lh_dot(5, 2, -2, -2)


def lh_am_pulse():
    return lh_pulse(6, 3, -2, -2)


def lh_f_pulse():
    # PDF chorus: 4̣̣ 1̣ 4̣ 1̣ (F2 C3)
    return lh_pulse(4, 1, -2, -1)


def lh_c_pulse():
    return lh_pulse(1, 5, -1, -2)


def lh_g_pulse():
    return lh_pulse(5, 2, -2, -2)


def rh_rest():
    return [rest(4.0)]


def rh_hook_a():
    # 6̇ 5̇ 3̇ 5̇ 3̇
    return [deg(6, 1, 1), deg(5, 1, 1), deg(3, 1, 1), deg(5, 1, 0.5), deg(3, 1, 0.5)]


def rh_hook_b():
    # 3̇ 2̇ 1̇ 2̇ 3̇
    return [deg(3, 1, 1), deg(2, 1, 1), deg(1, 1, 1), deg(2, 1, 0.5), deg(3, 1, 0.5)]


def rh_fill_7():
    # 0 7 7 7 0 7 7
    return [
        rest(1.0),
        deg(7, 0, 0.5),
        deg(7, 0, 0.5),
        deg(7, 0, 0.5),
        rest(0.5),
        deg(7, 0, 0.5),
        deg(7, 0, 0.5),
    ]


def rh_chorus():
    # 1̇ 1̇ 6 5 (W3: high 1s only; 6/5 middle)
    return [deg(1, 1, 1), deg(1, 1, 1), deg(6, 0, 1), deg(5, 0, 1)]


def rh_sync_a():
    # 1̇ 0 2̇ 0 0 2̇ 0  (q + 6 eighths)
    return [
        deg(1, 1, 1),
        rest(0.5),
        deg(2, 1, 0.5),
        rest(0.5),
        rest(0.5),
        deg(2, 1, 0.5),
        rest(0.5),
    ]


def rh_sync_b():
    # 1̇ 0 2̇ 0 2̇ 0 — alternate reading for m11; use same as sync_a with middle 00
    return rh_sync_a()


def main() -> None:
    rh: list[list] = []
    lh: list[list] = []

    # --- sys1 m1-4 ---
    rh += [rh_rest(), rh_hook_a(), rh_rest(), rh_hook_b()]
    lh += [lh_am_dot(), lh_f_dot(), lh_c_dot(), lh_g_dot()]

    # --- sys2 m5-8 ---
    rh += [rh_rest(), rh_hook_a(), rh_rest(), rh_fill_7()]
    lh += [lh_am_dot(), lh_f_dot(), lh_c_dot(), lh_g_dot()]

    # --- sys3 m9-12 chorus ---
    rh += [
        rh_chorus(),
        rh_chorus(),
        # m11: 1̇ 0 2̇ | 0 | 2̇ 0  (from zoom: q + e pairs)
        [
            deg(1, 1, 1),
            rest(0.5),
            deg(2, 1, 0.5),
            rest(1.0),
            deg(2, 1, 0.5),
            rest(0.5),
        ],
        # m12: 0 7 7 7 7 → q rest + q + q + two e  OR 0 77 77
        [rest(1.0), deg(7, 0, 1), deg(7, 0, 1), deg(7, 0, 0.5), deg(7, 0, 0.5)],
    ]
    lh += [lh_am_pulse(), lh_f_pulse(), lh_c_pulse(), lh_g_pulse()]

    # --- sys4 m13-16 ---
    rh += [
        rh_chorus(),
        rh_chorus(),
        rh_sync_a(),
        [rest(1.0), rest(1.0), deg(7, 0, 1), deg(7, 0, 1)],
    ]
    lh += [lh_am_pulse(), lh_f_pulse(), lh_c_pulse(), lh_g_pulse()]

    # --- sys5 m17-20 bridge ---
    rh += [
        [deg(6, 1, 1), deg(6, 1, 1), deg(5, 1, 1), deg(5, 1, 1)],
        [deg(3, 1, 1), deg(3, 1, 1), deg(2, 1, 1), deg(1, 1, 1)],
        # m19: 3̇ 0 5̇ 0 3̇
        [deg(3, 1, 1), rest(0.5), deg(5, 1, 0.5), rest(1.0), deg(3, 1, 1)],
        rh_fill_7(),
    ]
    lh += [lh_am_dot(), lh_f_dot(), lh_c_dot(), lh_g_dot()]

    # --- sys6 m21-25 ---
    rh += [
        rh_chorus(),
        rh_chorus(),
        rh_rest(),
        [deg(2, 1, 1), rest(1.0), deg(7, 0, 1), deg(1, 1, 1)],
        rh_rest(),
    ]
    lh += [
        lh_am_pulse(),
        lh_f_pulse(),
        # m23: LH 1̣ + 5 held whole (chord)
        [deg(1, -1, 4.0), (5, -1, 4.0, "chord")],
        lh_g_dot(),
        lh_am_dot(),
    ]

    # --- sys7 m26-28 ending (double bar after hook_b; no empty coda bar) ---
    rh += [rh_hook_a(), rh_rest(), rh_hook_b()]
    lh += [lh_f_dot(), lh_c_dot(), rh_rest()]  # LH silent on final RH hook

    xml = build(
        rh,
        lh,
        title="Whistle",
        artist="Flo Rida",
        key="C",
        tempo=120,
    )
    write(ASSET, xml)
    THIRD.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ASSET, THIRD)
    print(f"[PianoFlow/jianpu] whistle wrote {len(rh)} measures")
    subprocess.check_call(
        [
            sys.executable,
            str(ROOT / "scripts" / "musicxml_to_score.py"),
            "--id",
            "whistle",
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
