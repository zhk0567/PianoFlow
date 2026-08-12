# -*- coding: utf-8 -*-
"""DEPRECATED theme rewrite — do not re-run.

2026-08-09: half-note dyad / G4–C5 patterns for m8–15 disagreed with PDF m13
(broken-chord LH). Use ``_restore_suzume_m8_15.py`` instead. omrDraft only.
"""
from __future__ import annotations

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
)


def main() -> None:
    sid = "radwimps_suzume"
    tree, root, ns = load(sid)
    ms = measures(root, ns)
    by = {m.get("number"): m for m in ms}
    qn, e, s, de, h, w = 12, 6, 3, 9, 24, 48

    for m in ms:
        rh = [
            n
            for n in m.findall(q(ns, "note"))
            if n.find(q(ns, "chord")) is None
            and (n.findtext(q(ns, "staff")) or "1") == "1"
            and n.findtext(q(ns, "duration"))
        ]
        sm = sum(int(n.findtext(q(ns, "duration")) or 0) for n in rh)
        if sm not in (44, 45):
            continue
        for n in rh:
            d = n.find(q(ns, "duration"))
            if d is not None and d.text == "2":
                d.text = "3"
                t = n.find(q(ns, "type"))
                if t is not None:
                    t.text = "16th"
        sm2 = sum(int(n.findtext(q(ns, "duration")) or 0) for n in rh)
        if sm2 < 48 and rh:
            last = rh[-1].find(q(ns, "duration"))
            if last is not None:
                last.text = str(int(last.text or "0") + (48 - sm2))

    def rewrite(m, rh, lh):
        clear_notes(m, ns)
        for spec in rh:
            m.append(make_note(ns, **spec, staff=1, voice=1))
        append_backup(m, ns, w)
        for spec in lh:
            m.append(make_note(ns, **spec, staff=2, voice=5))

    def dyad(a, ao, b, bo, dur, typ):
        return [
            dict(step=a, octave=ao, dur=dur, typ=typ),
            dict(step=b, octave=bo, dur=dur, typ=typ, chord=True),
        ]

    pat_a_rh = [
        dict(step="G", octave=4, dur=qn, typ="quarter"),
        dict(step="C", octave=5, dur=de, typ="eighth", dotted=True),
        dict(step="B", octave=4, dur=s, typ="16th"),
        dict(step="A", octave=4, dur=e, typ="eighth"),
        dict(step="G", octave=4, dur=e, typ="eighth"),
        dict(step="A", octave=4, dur=e, typ="eighth"),
        dict(step="B", octave=4, dur=e, typ="eighth"),
    ]
    pat_a_lh = dyad("C", 3, "E", 3, h, "half") + dyad("G", 2, "B", 2, h, "half")
    pat_b_rh = [
        dict(step="C", octave=5, dur=e, typ="eighth"),
        dict(step="D", octave=5, dur=e, typ="eighth"),
        dict(step="E", octave=5, dur=e, typ="eighth"),
        dict(step="D", octave=5, dur=s, typ="16th"),
        dict(step="C", octave=5, dur=s, typ="16th"),
        dict(step="D", octave=5, dur=e, typ="eighth"),
        dict(step="G", octave=4, dur=de, typ="eighth", dotted=True),
        dict(step="G", octave=4, dur=s, typ="16th"),
        dict(step="G", octave=4, dur=e, typ="eighth"),
    ]

    lh_b = [
        dict(step="F", octave=2, dur=h, typ="half"),
        dict(step="C", octave=3, dur=h, typ="half", chord=True),
        dict(step="E", octave=2, dur=h, typ="half"),
        dict(step="B", octave=2, dur=h, typ="half", chord=True),
    ]
    for num, rh, lh in (
        ("8", pat_a_rh, pat_a_lh),
        ("9", pat_b_rh, pat_a_lh),
        ("10", pat_a_rh, pat_a_lh),
        ("11", pat_b_rh, pat_a_lh),
        ("12", pat_a_rh, pat_a_lh),
        ("13", pat_b_rh, lh_b),
        ("14", pat_a_rh, pat_a_lh),
        ("15", pat_b_rh, lh_b),
    ):
        if num in by:
            rewrite(by[num], rh, lh)

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] suzume m8-15 + short-bar fix; still omrDraft")


if __name__ == "__main__":
    main()
