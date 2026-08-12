# -*- coding: utf-8 -*-
"""Suzume: rewrite opening from PDF + remove m8-11 ostinato duplicate (omrDraft)."""
from __future__ import annotations

import copy
import sys
from pathlib import Path

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
    set_key,
)


def main() -> None:
    sid = "radwimps_suzume"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    by = {m.get("number"): m for m in ms}
    qn, e, s, de, h, w = 12, 6, 3, 9, 24, 48

    def rewrite(m, rh, lh=None):
        clear_notes(m, ns)
        for spec in rh:
            m.append(make_note(ns, **spec, staff=1, voice=1))
        append_backup(m, ns, w)
        if lh is None:
            m.append(
                make_note(
                    ns,
                    step=None,
                    octave=None,
                    dur=w,
                    typ="whole",
                    staff=2,
                    voice=5,
                    rest=True,
                )
            )
        else:
            for spec in lh:
                m.append(make_note(ns, **spec, staff=2, voice=5))

    intro_a = [
        dict(step="A", octave=4, dur=qn, typ="quarter"),
        dict(step="E", octave=5, dur=de, typ="eighth", dotted=True),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=e, typ="eighth"),
        dict(step="B", octave=4, dur=e, typ="eighth"),
        dict(step="A", octave=4, dur=e, typ="eighth"),
        dict(step="B", octave=4, dur=e, typ="eighth"),
    ]
    intro_b = [
        dict(step="A", octave=4, dur=e, typ="eighth"),
        dict(step="B", octave=4, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=s, typ="16th"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=s, typ="16th"),
        dict(step="B", octave=4, dur=s, typ="16th"),
        dict(step="A", octave=4, dur=s, typ="16th"),
        dict(step="A", octave=4, dur=h, typ="half"),
    ]
    ph2_a = [
        dict(step="C", octave=5, dur=qn, typ="quarter"),
        dict(step="E", octave=5, dur=de, typ="eighth", dotted=True),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=e, typ="eighth"),
        dict(step="B", octave=4, dur=e, typ="eighth"),
        dict(step="A", octave=4, dur=e, typ="eighth"),
        dict(step="G", octave=4, dur=s, typ="16th"),
        dict(step="A", octave=4, dur=s, typ="16th"),
    ]
    lh5 = [
        dict(step="A", octave=2, dur=h, typ="half"),
        dict(step="E", octave=3, dur=h, typ="half"),
    ]
    ph2_b = [
        dict(step="B", octave=4, dur=qn, typ="quarter"),
        dict(step="C", octave=5, dur=s, typ="16th"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="E", octave=5, dur=s, typ="16th"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=h, typ="half"),
    ]
    lh6 = [
        dict(step="F", octave=2, dur=h, typ="half"),
        dict(step="C", octave=3, dur=h, typ="half"),
    ]

    order = (
        ["0", "1", "2", "3", "4", "5", "6", "7"]
        if "0" in by
        else ["1", "2", "3", "4", "5", "6", "7", "8"]
    )
    pats = [
        (intro_a, None),
        (intro_b, None),
        (intro_a, None),
        (intro_b, None),
        (ph2_a, lh5),
        (ph2_b, lh6),
        (ph2_a, lh5),
        (ph2_b, lh6),
    ]
    for num, (rh, lh) in zip(order, pats):
        rewrite(by[num], rh, lh)

    src_nums = ["12", "13", "14", "15"]
    dst_nums = ["8", "9", "10", "11"] if "0" in by else ["9", "10", "11", "12"]
    for src, n in zip(src_nums, dst_nums):
        if src not in by or n not in by:
            continue
        sm, dm = by[src], by[n]
        clear_notes(dm, ns)
        for el in list(sm):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag in ("note", "backup", "forward"):
                dm.append(copy.deepcopy(el))

    first = by.get("0") or by.get("1") or ms[0]
    for el in first.iter():
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag == "per-minute":
            el.text = "80"
        if tag == "sound" and "tempo" in el.attrib:
            el.attrib["tempo"] = "80.0"
    set_key(first, ns, 0)
    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] suzume opening+dedup done; still omrDraft")


if __name__ == "__main__":
    main()
