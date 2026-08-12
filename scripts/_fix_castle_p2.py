# -*- coding: utf-8 -*-
"""Rewrite Castle in the Sky measures 31-48 from PDF p2 reads (omrDraft only)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import (  # noqa: E402
    ET,
    append_backup,
    clear_notes,
    convert,
    load,
    make_note,
    measures,
    q,
    save,
)


def main() -> None:
    sid = "hisaishi_castle_in_the_sky"
    tree, root, ns = load(sid)
    by_num = {m.get("number"): m for m in measures(root, ns)}
    qdur, edur, hdur, dhdur, wdur = 6, 3, 12, 18, 24

    def rewrite(num: int, rh: list, lh: tuple[str, int] | None) -> None:
        m = by_num[str(num)]
        clear_notes(m, ns)
        for s in rh:
            m.append(make_note(ns, **s, staff=1, voice=1))
        append_backup(m, ns, wdur)
        if lh is None:
            m.append(
                make_note(
                    ns,
                    step=None,
                    octave=None,
                    dur=wdur,
                    typ="whole",
                    staff=2,
                    voice=5,
                    rest=True,
                )
            )
        else:
            step, octv = lh
            m.append(
                make_note(
                    ns,
                    step=step,
                    octave=octv,
                    dur=wdur,
                    typ="whole",
                    staff=2,
                    voice=5,
                )
            )

    # PDF p2 top ~m31-42
    rewrite(
        31,
        [
            dict(step="A", octave=4, dur=edur, typ="eighth"),
            dict(step="G", octave=4, dur=edur, typ="eighth"),
            dict(step="F", octave=4, dur=qdur, typ="quarter"),
            dict(step=None, octave=None, dur=hdur, typ="half", rest=True),
        ],
        ("F", 3),
    )
    rewrite(
        32,
        [
            dict(step="C", octave=5, dur=qdur, typ="quarter"),
            dict(step="C", octave=5, dur=qdur, typ="quarter"),
            dict(step="D", octave=5, dur=qdur, typ="quarter"),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        None,
    )
    rewrite(
        33,
        [
            dict(step="C", octave=5, dur=qdur, typ="quarter"),
            dict(step="D", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=hdur, typ="half"),
        ],
        ("C", 3),
    )
    rewrite(
        34,
        [
            dict(step="E", octave=5, dur=qdur, typ="quarter"),
            dict(step="D", octave=5, dur=qdur, typ="quarter"),
            dict(step="C", octave=5, dur=qdur, typ="quarter"),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        None,
    )
    rewrite(
        35,
        [
            dict(step="G", octave=4, dur=dhdur, typ="half", dotted=True),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        ("G", 2),
    )
    rewrite(
        36,
        [
            dict(step="A", octave=4, dur=edur, typ="eighth"),
            dict(step="B", octave=4, dur=edur, typ="eighth"),
            dict(step="C", octave=5, dur=qdur + edur, typ="quarter", dotted=True),
            dict(step="D", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=qdur, typ="quarter"),
        ],
        None,
    )
    rewrite(
        37,
        [
            dict(step="G", octave=5, dur=dhdur, typ="half", dotted=True),
            dict(step="E", octave=5, dur=qdur, typ="quarter"),
        ],
        ("A", 2),
    )
    rewrite(
        38,
        [
            dict(step="A", octave=5, dur=qdur, typ="quarter"),
            dict(step="G", octave=5, dur=edur, typ="eighth"),
            dict(step="F", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=qdur, typ="quarter"),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        None,
    )
    rewrite(
        39,
        [
            dict(step="D", octave=5, dur=hdur, typ="half"),
            dict(step="D", octave=5, dur=qdur, typ="quarter"),
            dict(step="E", octave=5, dur=qdur, typ="quarter"),
        ],
        ("D", 3),
    )
    rewrite(
        40,
        [
            dict(step="F", octave=5, dur=qdur, typ="quarter"),
            dict(step="F", octave=5, alter=1, dur=edur, typ="eighth"),
            dict(step="G", octave=5, dur=edur, typ="eighth"),
            dict(step="G", octave=5, dur=qdur, typ="quarter"),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        None,
    )
    rewrite(
        41,
        [
            dict(step="A", octave=5, dur=hdur, typ="half"),
            dict(step="B", octave=5, dur=edur, typ="eighth"),
            dict(step="C", octave=6, dur=edur, typ="eighth"),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        ("E", 3),
    )
    rewrite(
        42,
        [
            dict(step="B", octave=5, dur=edur, typ="eighth"),
            dict(step="A", octave=5, dur=edur, typ="eighth"),
            dict(step="B", octave=5, dur=qdur, typ="quarter"),
            dict(step=None, octave=None, dur=hdur, typ="half", rest=True),
        ],
        ("A", 3),
    )
    # PDF p2 mid ending ~m43-48 into XML 43-47 + final 48
    rewrite(
        43,
        [
            dict(step="E", octave=5, dur=dhdur, typ="half", dotted=True),
            dict(step=None, octave=None, dur=qdur, typ="quarter", rest=True),
        ],
        ("C", 3),
    )
    rewrite(
        44,
        [
            dict(step="C", octave=5, dur=qdur, typ="quarter"),
            dict(step="E", octave=5, dur=qdur + edur, typ="quarter", dotted=True),
            dict(step="D", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=qdur, typ="quarter"),
        ],
        ("G", 2),
    )
    rewrite(
        45,
        [
            dict(step="F", octave=5, dur=dhdur, typ="half", dotted=True),
            dict(step="D", octave=5, dur=qdur, typ="quarter"),
        ],
        ("F", 2),
    )
    rewrite(
        46,
        [
            dict(step="E", octave=5, dur=dhdur, typ="half", dotted=True),
            dict(step="C", octave=5, dur=qdur, typ="quarter"),
        ],
        ("C", 3),
    )
    rewrite(
        47,
        [
            dict(step="G", octave=5, dur=edur, typ="eighth"),
            dict(step="F", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=edur, typ="eighth"),
            dict(step="E", octave=5, dur=edur, typ="eighth"),
            dict(step="F", octave=5, dur=qdur, typ="quarter"),
            dict(step="C", octave=5, alter=1, dur=qdur, typ="quarter"),
        ],
        ("G", 2),
    )
    # Final bar (XML last number 48): PDF closing E5 / C3
    m = by_num["48"]
    clear_notes(m, ns)
    m.append(make_note(ns, step="E", octave=5, dur=wdur, typ="whole", staff=1, voice=1))
    append_backup(m, ns, wdur)
    m.append(make_note(ns, step="C", octave=3, dur=wdur, typ="whole", staff=2, voice=5))
    for el in list(m):
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag == "barline":
            m.remove(el)
    bl = ET.Element(q(ns, "barline"))
    bl.set("location", "right")
    bs = ET.SubElement(bl, q(ns, "bar-style"))
    bs.text = "light-heavy"
    m.append(bl)

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] castle m31-48 rewritten, still omrDraft")


if __name__ == "__main__":
    main()
