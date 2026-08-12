# -*- coding: utf-8 -*-
"""Rewrite ye_de_gang_qin_qu_5 from PDF jianpu (1=C 4/4 ♩=120).

Evidence: docs/omr_audit/_jianpu_proof/ye_de_gang_qin_qu_5/
  p1.png (9×4=36) + p2.png (≈12–13 ending) → full sheet.
Still omrDraft until SOP.
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

ASSET = ROOT / "assets" / "scores" / "musicxml" / "ye_de_gang_qin_qu_5.musicxml"
THIRD = ROOT / "third_party" / "scores_musicxml" / "ye_de_gang_qin_qu_5.musicxml"


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
            ET.SubElement(key_el, "fifths").text = "0"
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


# LH arpeggio: four eighths + half. octs for each of 4 eighths + sustain degree/oct
def lh_arp(a, ao, b, bo, c, co, d, do, sust, so):
    return [
        deg(a, ao, 0.5),
        deg(b, bo, 0.5),
        deg(c, co, 0.5),
        deg(d, do, 0.5),
        deg(sust, so, 2.0),
    ]


def lh_f():
    # 4̣̣1̣̣ 5̣̣6̣̣ 1̣—  (opening PDF / fix_ye: F2 C2 G2 A2 C3)
    return lh_arp(4, -2, 1, -2, 5, -2, 6, -2, 1, -1)


def lh_g():
    # 5̣̣2̣̣ 6̣̣7̣̣ 2̣—
    return lh_arp(5, -2, 2, -2, 6, -2, 7, -2, 2, -1)


def lh_g_alt():
    # 5̣̣2̣̣ 5̣̣7̣̣ 2̣—
    return lh_arp(5, -2, 2, -2, 5, -2, 7, -2, 2, -1)


def lh_am():
    # 6̣̣3̣̣ 7̣̣1̣ 3̣—  (A2 E2 B2 C3 E3)
    return lh_arp(6, -2, 3, -2, 7, -2, 1, -1, 3, -1)


def lh_am_alt():
    # 6̣̣3̣̣ 5̣̣6̣̣ 1̣—
    return lh_arp(6, -2, 3, -2, 5, -2, 6, -2, 1, -1)


def lh_e():
    # 3̣̣7̣̣ 3̣̣5̣̣ 7̣—
    return lh_arp(3, -2, 7, -2, 3, -2, 5, -2, 7, -1)


def lh_c_end():
    # 1̣5̣ 2̣3̣ 5̣— (p2; first often one-dot)
    return lh_arp(1, -1, 5, -1, 2, -1, 3, -1, 5, -1)


def pickup():
    # 0 0 6 7 1̇ 3̇
    return [
        rest(1.0),
        rest(1.0),
        deg(6, 0, 0.5),
        deg(7, 0, 0.5),
        deg(1, 1, 0.5),
        deg(3, 1, 0.5),
    ]


def theme_a():
    # 6̇ - 6 7 1̇ 3̇
    return [
        deg(6, 1, 2.0),
        deg(6, 0, 0.5),
        deg(7, 0, 0.5),
        deg(1, 1, 0.5),
        deg(3, 1, 0.5),
    ]


def theme_b():
    # 6̇ - 2̇ 1̇ 7 1̇
    return [
        deg(6, 1, 2.0),
        deg(2, 1, 0.5),
        deg(1, 1, 0.5),
        deg(7, 0, 0.5),
        deg(1, 1, 0.5),
    ]


def theme_hold():
    return [deg(6, 1, 4.0)]


def climb_a():
    # 6̇ - 3̇ 5̇ 6̇ 3̇
    return [
        deg(6, 1, 2.0),
        deg(3, 1, 0.5),
        deg(5, 1, 0.5),
        deg(6, 1, 0.5),
        deg(3, 1, 0.5),
    ]


def climb_b():
    # 2̇. 3̇ 2̇ 3̇ 2̇ 1̇  (dotted-q + 5×e = 1.5+2.5=4)
    return [
        deg(2, 1, 1.5),
        deg(3, 1, 0.5),
        deg(2, 1, 0.5),
        deg(3, 1, 0.5),
        deg(2, 1, 0.5),
        deg(1, 1, 0.5),
    ]


def climb_c():
    # 2̇ - 2̇ 3̇ 5̇ 3̇
    return [
        deg(2, 1, 2.0),
        deg(2, 1, 0.5),
        deg(3, 1, 0.5),
        deg(5, 1, 0.5),
        deg(3, 1, 0.5),
    ]


def climb_d():
    # 5̇. 3̇ 5̇ 3̇ 5̇ 2̇
    return [
        deg(5, 1, 1.5),
        deg(3, 1, 0.5),
        deg(5, 1, 0.5),
        deg(3, 1, 0.5),
        deg(5, 1, 0.5),
        deg(2, 1, 0.5),
    ]


def bridge_a():
    # 1̇ - 6 7 1̇ 3̇
    return [
        deg(1, 1, 2.0),
        deg(6, 0, 0.5),
        deg(7, 0, 0.5),
        deg(1, 1, 0.5),
        deg(3, 1, 0.5),
    ]


def bridge_b():
    # 6̇. 3̇ 3̇ 2̇ 3̇ 2̇
    return [
        deg(6, 1, 1.5),
        deg(3, 1, 0.5),
        deg(3, 1, 0.5),
        deg(2, 1, 0.5),
        deg(3, 1, 0.5),
        deg(2, 1, 0.5),
    ]


def bridge_c():
    # 7 - 2̇ 1̇ 7 1̇
    return [
        deg(7, 0, 2.0),
        deg(2, 1, 0.5),
        deg(1, 1, 0.5),
        deg(7, 0, 0.5),
        deg(1, 1, 0.5),
    ]


def main() -> None:
    rh: list[list] = []
    lh: list[list] = []

    # ===== p1 sys1 m1-4 =====
    rh += [pickup(), theme_a(), theme_b(), theme_hold()]
    lh += [[rest(4.0)], lh_f(), lh_g(), lh_am()]

    # ===== p1 sys2 m5-8 =====
    rh += [pickup(), theme_a(), theme_b(), theme_hold()]
    lh += [lh_am(), lh_f(), lh_g(), lh_am()]

    # ===== p1 sys3 m9-12 =====
    rh += [climb_a(), climb_b(), climb_c(), climb_d()]
    lh += [lh_am(), lh_f(), lh_g_alt(), lh_e()]

    # ===== p1 sys4 m13-16 =====
    rh += [bridge_a(), bridge_b(), bridge_c(), theme_hold()]
    lh += [lh_am_alt(), lh_f(), lh_g_alt(), lh_am()]

    # ===== p1 sys5 m17-20 =====
    rh += [
        pickup(),
        theme_a(),
        theme_b(),
        [deg(6, 1, 2.0), rest(1.0), rest(1.0)],  # 6̇ - 0 0
    ]
    lh += [lh_am(), lh_f(), lh_g_alt(), lh_am()]

    # ===== p1 sys6 m21-24 =====
    rh += [
        # 1̇ 7 6 7 1̇ 3̇
        [
            deg(1, 1, 1.0),
            deg(7, 0, 0.5),
            deg(6, 0, 0.5),
            deg(7, 0, 0.5),
            deg(1, 1, 0.5),
            deg(3, 1, 1.0),
        ],
        theme_a(),
        theme_b(),
        theme_hold(),
    ]
    # fix m21 rhythm to sum 4: 1 + 0.5*4 + 1 = 4? 1+0.5+0.5+0.5+0.5+1=4. Good.
    # Actually first page: 1̇ 7 6 7 1̇ 3̇ — likely 1̇ q, then four e, then 3̇ q? Or all e?
    # Existing opening style pickup uses e for 6713. Use: q + 4e + q already above.
    lh += [lh_am(), lh_f(), lh_g_alt(), lh_am()]

    # ===== p1 sys7 m25-28 =====
    rh += [
        # 1̇ 7 3̇ 5̇ 6̇ 3̇
        [
            deg(1, 1, 1.0),
            deg(7, 0, 1.0),
            deg(3, 1, 0.5),
            deg(5, 1, 0.5),
            deg(6, 1, 0.5),
            deg(3, 1, 0.5),
        ],
        climb_b(),
        climb_c(),
        climb_d(),
    ]
    lh += [lh_am(), lh_f(), lh_g(), lh_e()]

    # ===== p1 sys8 m29-32 =====
    rh += [
        # 1̇ - 1̇ 2̇ 3̇ 6̇
        [
            deg(1, 1, 2.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(6, 1, 0.5),
        ],
        bridge_b(),
        bridge_c(),
        theme_hold(),
    ]
    lh += [lh_am_alt(), lh_f(), lh_g_alt(), lh_am()]

    # ===== p1 sys9 m33-36 =====
    rh += [
        # 1̇ 7 1̇ 2̇ 3̇ 6̇
        [
            deg(1, 1, 1.0),
            deg(7, 0, 1.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(6, 1, 0.5),
        ],
        # 6̇ - 1̇ 2̇ 3̇ 6̇
        [
            deg(6, 1, 2.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(6, 1, 0.5),
        ],
        # 6̇ - 1̇ 2̇ 3̇ 1̈
        [
            deg(6, 1, 2.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(1, 2, 0.5),
        ],
        theme_hold(),
    ]
    lh += [lh_am(), lh_f(), lh_g(), lh_am()]

    # ===== p2 sys1 m37-40 (Y2s1) =====
    rh += [
        [
            deg(1, 1, 1.0),
            deg(7, 0, 1.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(6, 1, 0.5),
        ],
        [
            deg(6, 1, 2.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(6, 1, 0.5),
        ],
        [
            deg(6, 1, 2.0),
            deg(3, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(5, 1, 0.5),
        ],
        [deg(3, 1, 4.0)],
    ]
    lh += [lh_am(), lh_f(), lh_g_alt(), lh_c_end()]

    # ===== p2 sys2 m41-44 (Y2s2) =====
    rh += [
        [
            deg(2, 1, 1.0),
            deg(3, 1, 1.0),
            deg(6, 0, 0.5),
            deg(7, 0, 0.5),
            deg(1, 1, 0.5),
            deg(3, 1, 0.5),
        ],
        [
            deg(6, 1, 1.5),
            deg(3, 1, 0.5),
            deg(3, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(5, 1, 0.5),
        ],
        [
            deg(2, 1, 2.0),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(5, 1, 0.5),
            deg(3, 1, 0.5),
        ],
        [
            deg(5, 1, 1.5),
            deg(3, 1, 0.5),
            deg(5, 1, 0.5),
            deg(3, 1, 0.5),
            deg(5, 1, 0.5),
            deg(2, 1, 0.5),
        ],
    ]
    lh += [lh_c_end(), lh_f(), lh_g(), lh_e()]

    # ===== p2 sys3 m45-49 ending =====
    rh += [
        [
            deg(1, 1, 2.0),
            deg(1, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(6, 1, 0.5),
        ],
        [
            deg(6, 1, 1.5),
            deg(3, 1, 0.5),
            deg(3, 1, 0.5),
            deg(2, 1, 0.5),
            deg(3, 1, 0.5),
            deg(2, 1, 0.5),
        ],
        [
            deg(7, 0, 2.0),
            deg(2, 1, 0.5),
            deg(1, 1, 0.5),
            deg(7, 0, 0.5),
            deg(1, 1, 0.5),
        ],
        [deg(6, 1, 2.0), rest(1.0), rest(1.0)],
        # final Am chord 6̇ 3̇ 1̇
        [
            deg(6, 1, 4.0),
            (3, 1, 4.0, "chord"),
            (1, 1, 4.0, "chord"),
        ],
    ]
    lh += [lh_am_alt(), lh_f(), lh_g_alt(), lh_am(), [rest(4.0)]]

    xml = build(
        rh,
        lh,
        title="夜的钢琴曲五",
        artist="石进",
        key="C",
        tempo=120,
    )
    write(ASSET, xml)
    THIRD.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ASSET, THIRD)
    print(f"[PianoFlow/jianpu] ye_de_gang_qin_qu_5 wrote {len(rh)} measures")
    subprocess.check_call(
        [
            sys.executable,
            str(ROOT / "scripts" / "musicxml_to_score.py"),
            "--id",
            "ye_de_gang_qin_qu_5",
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
