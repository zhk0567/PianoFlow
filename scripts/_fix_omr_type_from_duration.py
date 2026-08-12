# -*- coding: utf-8 -*-
"""Align MusicXML <type>/<dot> to <duration> (divisions-aware).

Does not change pitches or durations. Skips grace notes and tuplets
(time-modification). omrDraft hygiene for Verovio display — no formal.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, q, save  # noqa: E402

TYPE_BEATS = [
    ("whole", 4.0),
    ("half", 2.0),
    ("quarter", 1.0),
    ("eighth", 0.5),
    ("16th", 0.25),
    ("32nd", 0.125),
    ("64th", 0.0625),
    ("128th", 0.03125),
]


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def encode_duration(dur: int, div: int) -> tuple[str, int] | None:
    target = float(dur)
    for typ, beats in TYPE_BEATS:
        base = beats * div
        for dots in (0, 1, 2):
            val = base
            unit = base
            for _ in range(dots):
                unit /= 2.0
                val += unit
            if abs(val - target) < 1e-6:
                return typ, dots
    return None


def set_type_dots(note: ET.Element, ns: str, typ: str, dots: int) -> None:
    type_el = note.find(q(ns, "type"))
    if type_el is None:
        # insert after duration if present
        dur = note.find(q(ns, "duration"))
        type_el = ET.Element(q(ns, "type"))
        if dur is not None:
            idx = list(note).index(dur) + 1
            note.insert(idx, type_el)
        else:
            note.append(type_el)
    type_el.text = typ
    for d in list(note.findall(q(ns, "dot"))):
        note.remove(d)
    if dots:
        # dots follow type
        type_el = note.find(q(ns, "type"))
        idx = list(note).index(type_el) + 1
        for i in range(dots):
            note.insert(idx + i, ET.Element(q(ns, "dot")))


def fix_score(sid: str) -> int:
    tree, root, ns = load(sid)
    nfix = 0
    for part in root.findall(q(ns, "part")):
        div = None
        for m in part.findall(q(ns, "measure")):
            for el in m:
                if local(el.tag) != "attributes":
                    continue
                d = el.find(q(ns, "divisions"))
                if d is not None and d.text:
                    div = int(d.text)
            if not div:
                continue
            for n in m.findall(q(ns, "note")):
                if n.find(q(ns, "grace")) is not None:
                    continue
                if n.find(q(ns, "time-modification")) is not None:
                    continue
                d = n.find(q(ns, "duration"))
                if d is None or not d.text:
                    continue
                enc = encode_duration(int(d.text), div)
                if enc is None:
                    continue
                typ, dots = enc
                cur_typ = n.findtext(q(ns, "type"))
                cur_dots = len(n.findall(q(ns, "dot")))
                if cur_typ == typ and cur_dots == dots:
                    continue
                set_type_dots(n, ns, typ, dots)
                nfix += 1
    if nfix:
        save(sid, tree)
        convert(sid)
    print(f"[PianoFlow/omr] {sid}: synced type/dot on {nfix} notes; still omrDraft")
    return nfix


DEFAULT = [
    "ru_yuan",
    "jay_chou_qing_tian",
    "sawano_call_of_silence",
    "xiang_yun_duan",
    "jue_bie_shu",
    "rush_e",
    "christina_perri_a_thousand_years",
    "hisaishi_castle_in_the_sky",
    "radwimps_suzume",
    "haruhikage",
    "clayderman_reve_damour",
    "rimsky_flight_of_the_bumblebee",
    "when_you_wish_upon_a_star",
    "pure_imagination",
    "an_he_qiao",
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", nargs="*", default=DEFAULT)
    args = ap.parse_args()
    total = sum(fix_score(sid) for sid in args.ids)
    print(f"[PianoFlow/omr] TOTAL type/dot sync notes={total}; no formal")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
