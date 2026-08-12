# -*- coding: utf-8 -*-
"""Fix clear jianpu-draft openings against PDF (still omrDraft)."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets" / "scores" / "musicxml"
THIRD = ROOT / "third_party" / "scores_musicxml"
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import (  # noqa: E402
    append_backup,
    clear_notes,
    convert,
    load,
    make_note,
    measures,
    save,
    set_key,
)


def set_tempo(measure: ET.Element, ns: str, bpm: int) -> None:
    q = (lambda n: f"{ns}{n}" if ns else n)
    for el in measure.iter():
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag == "per-minute":
            el.text = str(bpm)
        if tag == "sound" and "tempo" in el.attrib:
            el.attrib["tempo"] = str(float(bpm))


def fix_xiao() -> None:
    sid = "xiao_xing_xing"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_tempo(ms[0], ns, 68)
    save(sid, tree)
    convert(sid)


def fix_fen() -> None:
    """PDF: 1=C 4/4 ♩=120; RH high 5-3-5-3 / 5-3-1-; LH 1— + 5/3—."""
    sid = "fen_shua_jiang"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_tempo(ms[0], ns, 120)
    D = 4  # quarter

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for s in lh:
            m.append(make_note(ns, **s, staff=2, voice=5))

    def lh_c():
        return [
            dict(step="C", octave=3, dur=2 * D, typ="half"),
            dict(step="G", octave=3, dur=2 * D, typ="half"),
            dict(step="E", octave=4, dur=2 * D, typ="half", chord=True),
        ]

    def lh_g7():
        return [
            dict(step="B", octave=2, dur=2 * D, typ="half"),
            dict(step="G", octave=3, dur=2 * D, typ="half"),
            dict(step="D", octave=4, dur=2 * D, typ="half", chord=True),
        ]

    # m1: G5 E5 G5 E5
    rewrite(
        ms[0],
        [
            dict(step="G", octave=5, dur=D, typ="quarter"),
            dict(step="E", octave=5, dur=D, typ="quarter"),
            dict(step="G", octave=5, dur=D, typ="quarter"),
            dict(step="E", octave=5, dur=D, typ="quarter"),
        ],
        lh_c(),
    )
    # m2: G5 E5 C5 half
    rewrite(
        ms[1],
        [
            dict(step="G", octave=5, dur=D, typ="quarter"),
            dict(step="E", octave=5, dur=D, typ="quarter"),
            dict(step="C", octave=5, dur=2 * D, typ="half"),
        ],
        lh_c(),
    )
    # m3: D5 F5 E5 D5
    rewrite(
        ms[2],
        [
            dict(step="D", octave=5, dur=D, typ="quarter"),
            dict(step="F", octave=5, dur=D, typ="quarter"),
            dict(step="E", octave=5, dur=D, typ="quarter"),
            dict(step="D", octave=5, dur=D, typ="quarter"),
        ],
        lh_g7(),
    )
    # m4: G5 whole
    rewrite(ms[3], [dict(step="G", octave=5, dur=4 * D, typ="whole")], lh_c())
    # m5-8 reprise with m8 = C5 whole
    for src, dst in ((0, 4), (1, 5), (2, 6)):
        clear_notes(ms[dst], ns)
        for el in list(ms[src]):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag in ("note", "backup", "forward"):
                import copy

                ms[dst].append(copy.deepcopy(el))
    rewrite(ms[7], [dict(step="C", octave=5, dur=4 * D, typ="whole")], lh_c())
    save(sid, tree)
    convert(sid)


def fix_bella() -> None:
    """PDF: 1=G 2/4 ♩=120; pickup-like 0 3 6 7 | 1. 6 — 6 | …"""
    sid = "bella_ciao"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_key(ms[0], ns, 1)
    set_tempo(ms[0], ns, 120)
    D = 4  # divisions likely 4; 2/4 bar = 8

    # detect divisions
    attr = ms[0].find(f"{'{'}{ns[1:-1]}{'}'}attributes" if ns else "attributes")
    if attr is None:
        for el in ms[0]:
            if (el.tag.replace(ns, "") if ns else el.tag) == "attributes":
                attr = el
                break
    div_el = None
    if attr is not None:
        for el in attr:
            if (el.tag.replace(ns, "") if ns else el.tag) == "divisions":
                div_el = el
                break
    divisions = int(div_el.text) if div_el is not None and div_el.text else 4
    e = divisions // 2  # eighth
    q = divisions  # quarter
    bar = 2 * q

    def rewrite(m, rh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, bar)
        m.append(
            make_note(
                ns,
                step=None,
                octave=None,
                dur=bar,
                typ="half",
                staff=2,
                voice=5,
                rest=True,
            )
        )

    # In G: 3=B4, 6=E5, 7=F#5, 1.=G5
    pattern_a = [
        dict(step=None, octave=None, dur=e, typ="eighth", rest=True),
        dict(step="B", octave=4, dur=e, typ="eighth"),
        dict(step="E", octave=5, dur=e, typ="eighth"),
        dict(step="F", octave=5, alter=1, dur=e, typ="eighth"),
    ]
    pattern_b = [
        dict(step="G", octave=5, dur=e, typ="eighth"),
        dict(step="E", octave=5, dur=e, typ="eighth"),
        dict(step="E", octave=5, dur=q, typ="quarter"),
    ]
    for i in range(0, 6, 2):
        if i < len(ms):
            rewrite(ms[i], pattern_a)
        if i + 1 < len(ms):
            rewrite(ms[i + 1], pattern_b)
    # m6 variant from PDF: 1. 7 6
    if len(ms) > 5:
        rewrite(
            ms[5],
            [
                dict(step="G", octave=5, dur=q, typ="quarter"),
                dict(step="F", octave=5, alter=1, dur=e, typ="eighth"),
                dict(step="E", octave=5, dur=e, typ="eighth"),
            ],
        )
    save(sid, tree)
    convert(sid)


def fix_ju_hua() -> None:
    """PDF: 1=F 4/4 ♩=76; m1 3 3 2 3— / LH 1̣— 7̣—."""
    sid = "ju_hua_tai"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_key(ms[0], ns, -1)
    set_tempo(ms[0], ns, 76)
    D = 4

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for s in lh:
            m.append(make_note(ns, **s, staff=2, voice=5))

    # F major: 1=F4, 2=G4, 3=A4, 5=C5; low 1=F3, low 7=E3, low 6=D3, low 5=C3, low 4=Bb2, low 3=A2, low 2=G2
    rewrite(
        ms[0],
        [
            dict(step="A", octave=4, dur=D, typ="quarter"),
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=2 * D, typ="half"),
        ],
        [
            dict(step="F", octave=3, dur=2 * D, typ="half"),
            dict(step="E", octave=3, dur=2 * D, typ="half"),
        ],
    )
    rewrite(
        ms[1],
        [
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
            dict(step="C", octave=5, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=2 * D, typ="half"),
        ],
        [
            dict(step="D", octave=3, dur=2 * D, typ="half"),
            dict(step="C", octave=3, dur=2 * D, typ="half"),
        ],
    )
    rewrite(
        ms[2],
        [
            dict(step="F", octave=4, dur=D, typ="quarter"),
            dict(step="F", octave=4, dur=D // 2, typ="eighth"),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=D // 2, typ="eighth"),
            dict(step="C", octave=5, dur=D // 2, typ="eighth"),
            dict(step="A", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="B", octave=2, alter=-1, dur=2 * D, typ="half"),
            dict(step="A", octave=2, dur=2 * D, typ="half"),
        ],
    )
    rewrite(
        ms[3],
        [
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step="G", octave=4, dur=D // 2, typ="eighth"),
            dict(step="F", octave=4, dur=D // 2, typ="eighth"),
            dict(step="G", octave=4, dur=2 * D, typ="half"),
        ],
        [
            dict(step="G", octave=2, dur=2 * D, typ="half"),
            dict(step="C", octave=3, dur=2 * D, typ="half"),
        ],
    )
    save(sid, tree)
    convert(sid)


def fix_an_he() -> None:
    """PDF: 1=C 4/4 ♩=120; opening vocal-ish with LH eighth pulse."""
    sid = "an_he_qiao"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_key(ms[0], ns, 0)
    set_tempo(ms[0], ns, 120)
    D = 4
    e = D // 2
    s = D // 4

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for x in rh:
            m.append(make_note(ns, **x, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for x in lh:
            m.append(make_note(ns, **x, staff=2, voice=5))

    def lh_pat(notes):
        return [dict(step=st, octave=oc, dur=e, typ="eighth") for st, oc in notes]

    # m1 RH: q rest + dense 16ths then 2 q + 3 2 16ths (approx from PDF)
    rewrite(
        ms[0],
        [
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step="E", octave=4, dur=s, typ="16th"),
            dict(step="E", octave=4, dur=s, typ="16th"),
            dict(step="E", octave=4, dur=s, typ="16th"),
            dict(step="E", octave=4, dur=s, typ="16th"),
            dict(step="A", octave=4, dur=s, typ="16th"),
            dict(step="E", octave=4, dur=s, typ="16th"),
            dict(step="D", octave=4, dur=D, typ="quarter"),
            dict(step="E", octave=4, dur=s, typ="16th"),
            dict(step="D", octave=4, dur=s, typ="16th"),
        ],
        lh_pat(
            [
                ("C", 3),
                ("G", 2),
                ("C", 3),
                ("G", 2),
                ("G", 2),
                ("D", 3),
                ("G", 2),
                ("D", 3),
            ]
        ),
    )
    rewrite(
        ms[1],
        [
            dict(step="C", octave=4, dur=e, typ="eighth"),
            dict(step="A", octave=3, dur=s, typ="16th"),
            dict(step="A", octave=3, dur=s, typ="16th"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step=None, octave=None, dur=e, typ="eighth", rest=True),
            dict(step="G", octave=3, dur=s, typ="16th"),
            dict(step="G", octave=3, dur=s, typ="16th"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
        ],
        lh_pat([("A", 2), ("E", 2), ("A", 2), ("E", 2), ("A", 2), ("E", 2), ("A", 2), ("E", 2)]),
    )
    save(sid, tree)
    convert(sid)


def fix_blowin() -> None:
    """PDF single-line jianpu 1=C ♩=120: 5—55 | 6—66 | 5—32 | 1—0 3 | …"""
    sid = "blowin_in_the_wind"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_key(ms[0], ns, 0)
    set_tempo(ms[0], ns, 120)
    D = 4

    def rewrite(m, rh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        m.append(
            make_note(
                ns,
                step=None,
                octave=None,
                dur=4 * D,
                typ="whole",
                staff=2,
                voice=5,
                rest=True,
            )
        )

    bars = [
        [
            dict(step="G", octave=4, dur=2 * D, typ="half"),
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step="G", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="A", octave=4, dur=2 * D, typ="half"),
            dict(step="A", octave=4, dur=D, typ="quarter"),
            dict(step="A", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="G", octave=4, dur=2 * D, typ="half"),
            dict(step="E", octave=4, dur=D, typ="quarter"),
            dict(step="D", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="C", octave=4, dur=2 * D, typ="half"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step="E", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="G", octave=4, dur=2 * D, typ="half"),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step="G", octave=4, dur=D, typ="quarter"),
        ],
        [
            dict(step="A", octave=4, dur=2 * D, typ="half"),
            dict(step="G", octave=4, dur=D, typ="quarter"),
            dict(step="F", octave=4, dur=D, typ="quarter"),
        ],
        [dict(step="G", octave=4, dur=4 * D, typ="whole")],
        [
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step="E", octave=4, dur=D, typ="quarter"),
            dict(step="F", octave=4, dur=D, typ="quarter"),
        ],
    ]
    for i, rh in enumerate(bars):
        if i < len(ms):
            rewrite(ms[i], rh)
    save(sid, tree)
    convert(sid)


def fix_whistle() -> None:
    """PDF: m1 RH rests; m2 6.5.3. 5.3. high; tempo 120."""
    sid = "whistle"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_tempo(ms[0], ns, 120)
    D = 4
    e = D // 2

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for s in lh:
            m.append(make_note(ns, **s, staff=2, voice=5))

    # LH pattern: low 6 q, 3 q, 6 dotted-q, e rest  (A2 E2 A2)
    def lh_ae():
        return [
            dict(step="A", octave=2, dur=D, typ="quarter"),
            dict(step="E", octave=2, dur=D, typ="quarter"),
            dict(step="A", octave=2, dur=D + e, typ="quarter", dotted=True),
            dict(step=None, octave=None, dur=e, typ="eighth", rest=True),
        ]

    def lh_fc():
        return [
            dict(step="F", octave=2, dur=D, typ="quarter"),
            dict(step="C", octave=2, dur=D, typ="quarter"),
            dict(step="F", octave=2, dur=D + e, typ="quarter", dotted=True),
            dict(step=None, octave=None, dur=e, typ="eighth", rest=True),
        ]

    def lh_cg():
        return [
            dict(step="C", octave=3, dur=D, typ="quarter"),
            dict(step="G", octave=2, dur=D, typ="quarter"),
            dict(step="C", octave=3, dur=D + e, typ="quarter", dotted=True),
            dict(step=None, octave=None, dur=e, typ="eighth", rest=True),
        ]

    def lh_gd():
        return [
            dict(step="G", octave=2, dur=D, typ="quarter"),
            dict(step="D", octave=2, dur=D, typ="quarter"),
            dict(step="G", octave=2, dur=D + e, typ="quarter", dotted=True),
            dict(step=None, octave=None, dur=e, typ="eighth", rest=True),
        ]

    rewrite(
        ms[0],
        [dict(step=None, octave=None, dur=4 * D, typ="whole", rest=True)],
        lh_ae(),
    )
    rewrite(
        ms[1],
        [
            dict(step="A", octave=5, dur=D, typ="quarter"),
            dict(step="G", octave=5, dur=D, typ="quarter"),
            dict(step="E", octave=5, dur=D, typ="quarter"),
            dict(step="G", octave=5, dur=e, typ="eighth"),
            dict(step="E", octave=5, dur=e, typ="eighth"),
        ],
        lh_fc(),
    )
    rewrite(
        ms[2],
        [dict(step=None, octave=None, dur=4 * D, typ="whole", rest=True)],
        lh_cg(),
    )
    rewrite(
        ms[3],
        [
            dict(step="E", octave=5, dur=D, typ="quarter"),
            dict(step="D", octave=5, dur=D, typ="quarter"),
            dict(step="C", octave=5, dur=D, typ="quarter"),
            dict(step="D", octave=5, dur=e, typ="eighth"),
            dict(step="E", octave=5, dur=e, typ="eighth"),
        ],
        lh_gd(),
    )
    save(sid, tree)
    convert(sid)


def fix_wish_tempo() -> None:
    sid = "when_you_wish_upon_a_star"
    tree, root, ns = load(sid)
    set_tempo(measures(root, ns)[0], ns, 120)
    save(sid, tree)
    convert(sid)


def fix_pure() -> None:
    """PDF: 1=Eb ♩=120; sparse intro then m5 melody."""
    sid = "pure_imagination"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_key(ms[0], ns, -3)
    set_tempo(ms[0], ns, 120)
    D = 4

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for s in lh:
            m.append(make_note(ns, **s, staff=2, voice=5))

    rewrite(
        ms[0],
        [
            dict(step="C", octave=5, dur=3 * D, typ="half", dotted=True),
            dict(step="C", octave=4, dur=3 * D, typ="half", dotted=True, chord=True),
            dict(step="E", octave=4, alter=-1, dur=3 * D, typ="half", dotted=True, chord=True),
            dict(step="D", octave=5, dur=D, typ="quarter"),
            dict(step="D", octave=4, dur=D, typ="quarter", chord=True),
        ],
        [
            dict(step="B", octave=2, alter=-1, dur=2 * D, typ="half"),
            dict(step="B", octave=1, alter=-1, dur=2 * D, typ="half"),
        ],
    )
    if len(ms) > 4:
        rewrite(
            ms[4],
            [
                dict(step="C", octave=3, dur=D, typ="quarter"),
                dict(step="C", octave=4, dur=D, typ="quarter"),
                dict(step="B", octave=3, alter=-1, dur=D, typ="quarter"),
                dict(step="G", octave=3, dur=D, typ="quarter"),
            ],
            [dict(step="B", octave=2, alter=-1, dur=4 * D, typ="whole")],
        )
    if len(ms) > 5:
        rewrite(
            ms[5],
            [
                dict(step="B", octave=2, alter=-1, dur=D, typ="quarter"),
                dict(step="B", octave=3, alter=-1, dur=D, typ="quarter"),
                dict(step="F", octave=3, dur=D, typ="quarter"),
                dict(step="E", octave=3, alter=-1, dur=D, typ="quarter"),
            ],
            [dict(step="B", octave=2, alter=-1, dur=4 * D, typ="whole")],
        )
    save(sid, tree)
    convert(sid)


def fix_ye() -> None:
    """PDF: 1=C ♩=120; m1 rests + 6 7 1. 3.; m2 high 6 half + pickup."""
    sid = "ye_de_gang_qin_qu_5"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    set_tempo(ms[0], ns, 120)
    D = 4
    e = D // 2

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, 4 * D)
        for s in lh:
            m.append(make_note(ns, **s, staff=2, voice=5))

    rewrite(
        ms[0],
        [
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step="A", octave=4, dur=e, typ="eighth"),
            dict(step="B", octave=4, dur=e, typ="eighth"),
            dict(step="C", octave=5, dur=e, typ="eighth"),
            dict(step="E", octave=5, dur=e, typ="eighth"),
        ],
        [dict(step=None, octave=None, dur=4 * D, typ="whole", rest=True)],
    )
    rewrite(
        ms[1],
        [
            dict(step="A", octave=5, dur=2 * D, typ="half"),
            dict(step="A", octave=4, dur=e, typ="eighth"),
            dict(step="B", octave=4, dur=e, typ="eighth"),
            dict(step="C", octave=5, dur=e, typ="eighth"),
            dict(step="E", octave=5, dur=e, typ="eighth"),
        ],
        [
            dict(step="F", octave=2, dur=e, typ="eighth"),
            dict(step="C", octave=2, dur=e, typ="eighth"),
            dict(step="G", octave=2, dur=e, typ="eighth"),
            dict(step="A", octave=2, dur=e, typ="eighth"),
            dict(step="C", octave=3, dur=2 * D, typ="half"),
        ],
    )
    rewrite(
        ms[2],
        [
            dict(step="A", octave=5, dur=2 * D, typ="half"),
            dict(step="D", octave=5, dur=e, typ="eighth"),
            dict(step="C", octave=5, dur=e, typ="eighth"),
            dict(step="B", octave=4, dur=e, typ="eighth"),
            dict(step="C", octave=5, dur=e, typ="eighth"),
        ],
        [
            dict(step="G", octave=2, dur=e, typ="eighth"),
            dict(step="D", octave=2, dur=e, typ="eighth"),
            dict(step="A", octave=2, dur=e, typ="eighth"),
            dict(step="B", octave=2, dur=e, typ="eighth"),
            dict(step="D", octave=3, dur=2 * D, typ="half"),
        ],
    )
    rewrite(
        ms[3],
        [dict(step="A", octave=5, dur=4 * D, typ="whole")],
        [
            dict(step="A", octave=2, dur=e, typ="eighth"),
            dict(step="E", octave=2, dur=e, typ="eighth"),
            dict(step="B", octave=2, dur=e, typ="eighth"),
            dict(step="C", octave=3, dur=e, typ="eighth"),
            dict(step="E", octave=3, dur=2 * D, typ="half"),
        ],
    )
    save(sid, tree)
    convert(sid)


def main() -> None:
    which = sys.argv[1:] or [
        "xiao",
        "fen",
        "bella",
        "ju",
        "anhe",
        "blowin",
        "whistle",
        "wish",
        "pure",
        "ye",
    ]
    mapping = {
        "xiao": fix_xiao,
        "fen": fix_fen,
        "bella": fix_bella,
        "ju": fix_ju_hua,
        "anhe": fix_an_he,
        "blowin": fix_blowin,
        "whistle": fix_whistle,
        "wish": fix_wish_tempo,
        "pure": fix_pure,
        "ye": fix_ye,
    }
    for name in which:
        print("===", name, "===")
        mapping[name]()


if __name__ == "__main__":
    main()
