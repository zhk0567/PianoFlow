# -*- coding: utf-8 -*-
"""Call of Silence: rewrite m15–19 mid theme from PDF (omrDraft only)."""
from __future__ import annotations

import sys
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import (  # noqa: E402
    append_backup,
    clear_notes,
    convert,
    load,
    make_note,
    measures,
    q,
    save,
)

D = 8  # divisions: quarter=8, eighth=4, dotted-quarter=12, half=16, whole=32
BAR = 4 * D


def chord_q(ns: str, root_step: str, root_oct: int) -> list:
    """Root–fifth–octave quarter chord."""
    fifth = {"C": ("G", root_oct), "G": ("D", root_oct + 1), "A": ("E", root_oct + 1), "F": ("C", root_oct + 1)}[
        root_step
    ]
    return [
        dict(step=root_step, octave=root_oct, dur=D, typ="quarter"),
        dict(step=fifth[0], octave=fifth[1], dur=D, typ="quarter", chord=True),
        dict(step=root_step, octave=root_oct + 1, dur=D, typ="quarter", chord=True),
    ]


def four_chords(ns: str, root_step: str, root_oct: int) -> list:
    out = []
    for _ in range(4):
        out.extend(chord_q(ns, root_step, root_oct))
    return out


def rewrite(m: ET.Element, ns: str, rh: list, lh: list) -> None:
    clear_notes(m, ns)
    for spec in rh:
        m.append(make_note(ns, **spec, staff=1, voice=1))
    append_backup(m, ns, BAR)
    for spec in lh:
        m.append(make_note(ns, **spec, staff=2, voice=5))


def main() -> None:
    sid = "sawano_call_of_silence"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}

    # m15: C5. B4 | A4 B4 | C5  — LH C×4
    rewrite(
        by["15"],
        ns,
        [
            dict(step="C", octave=5, dur=12, typ="quarter", dotted=True),
            dict(step="B", octave=4, dur=4, typ="eighth"),
            dict(step="A", octave=4, dur=4, typ="eighth"),
            dict(step="B", octave=4, dur=4, typ="eighth"),
            dict(step="C", octave=5, dur=D, typ="quarter"),
        ],
        four_chords(ns, "C", 2),
    )
    # m16: B4. A4 | G4 A4 | B4
    rewrite(
        by["16"],
        ns,
        [
            dict(step="B", octave=4, dur=12, typ="quarter", dotted=True),
            dict(step="A", octave=4, dur=4, typ="eighth"),
            dict(step="G", octave=4, dur=4, typ="eighth"),
            dict(step="A", octave=4, dur=4, typ="eighth"),
            dict(step="B", octave=4, dur=D, typ="quarter"),
        ],
        four_chords(ns, "G", 1),
    )
    # m17: A4 B4 C5 D5 E5 (fill 4/4)
    rewrite(
        by["17"],
        ns,
        [
            dict(step="A", octave=4, dur=D, typ="quarter"),
            dict(step="B", octave=4, dur=4, typ="eighth"),
            dict(step="C", octave=5, dur=D, typ="quarter"),
            dict(step="D", octave=5, dur=4, typ="eighth"),
            dict(step="E", octave=5, dur=D, typ="quarter"),
        ],
        four_chords(ns, "A", 1),
    )
    # m18: F5. E5 D5 half
    rewrite(
        by["18"],
        ns,
        [
            dict(step="F", octave=5, dur=12, typ="quarter", dotted=True),
            dict(step="E", octave=5, dur=4, typ="eighth"),
            dict(step="D", octave=5, dur=16, typ="half"),
        ],
        four_chords(ns, "F", 1),
    )
    # m19: fermata quarter rest + 8th rest + G5 8th + half rest | LH whole rest
    m19 = by["19"]
    rewrite(
        m19,
        ns,
        [
            dict(step=None, octave=None, dur=D, typ="quarter", rest=True),
            dict(step=None, octave=None, dur=4, typ="eighth", rest=True),
            dict(step="G", octave=5, dur=4, typ="eighth"),
            dict(step=None, octave=None, dur=16, typ="half", rest=True),
        ],
        [dict(step=None, octave=None, dur=BAR, typ="whole", rest=True)],
    )
    # attach fermata to first rest
    for n in m19.findall(q(ns, "note")):
        if n.find(q(ns, "rest")) is not None:
            notations = n.find(q(ns, "notations"))
            if notations is None:
                notations = ET.SubElement(n, q(ns, "notations"))
            arts = notations.find(q(ns, "articulations"))
            if arts is None:
                arts = ET.SubElement(notations, q(ns, "articulations"))
            if arts.find(q(ns, "fermata")) is None and notations.find(q(ns, "fermata")) is None:
                ET.SubElement(notations, q(ns, "fermata"))
            break

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] silence m15-19 rewritten; still omrDraft")


if __name__ == "__main__":
    main()
