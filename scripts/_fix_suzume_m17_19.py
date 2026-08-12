# -*- coding: utf-8 -*-
"""Suzume: rewrite RH m17/m19 to PDF dense descending 16ths (omrDraft only).

Evidence: docs/omr_audit/_suzume_proof/auto_p1_sys4.png + m16_bars/m17_rh.png
PDF m17–19 are high ledger-line runs (fingering 5-4-3-1…), not the D5–E5
melody currently in XML m17/m19. LH quarter F/Em kept (matches 5 + 1/4 pattern).
m16/m18 left unchanged this round. Still omrDraft — no formal.
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
    save,
)

S = 3  # 16th at divisions=12
BAR = 48


def rh_dense_a() -> list[tuple[str, int]]:
    # A5 G5 F5 F5 E5 | D5×4 | C5×4 | D5 E5 D5  (16 × 16th)
    return [
        ("A", 5),
        ("G", 5),
        ("F", 5),
        ("F", 5),
        ("E", 5),
        ("D", 5),
        ("D", 5),
        ("D", 5),
        ("D", 5),
        ("C", 5),
        ("C", 5),
        ("C", 5),
        ("C", 5),
        ("D", 5),
        ("E", 5),
        ("D", 5),
    ]


def lh_f_em() -> list[tuple]:
    # F2, C3+F3, E2, B2+E3  (quarter each event; chords via chord=True)
    return [
        ("F", 2, False),
        ("C", 3, False),
        ("F", 3, True),
        ("E", 2, False),
        ("B", 2, False),
        ("E", 3, True),
    ]


def rewrite(m, ns, rh, lh) -> None:
    clear_notes(m, ns)
    for step, octv in rh:
        m.append(
            make_note(
                ns,
                step=step,
                octave=octv,
                dur=S,
                typ="16th",
                staff=1,
                voice=1,
            )
        )
    append_backup(m, ns, BAR)
    # LH: three chord-events of quarter (=12). Group as (root) (third+fifth chord)
    # Pattern: F2 | C3+F3 | E2 | B2+E3 — but durations: each non-chord starts event.
    qn = 12
    # F2 quarter
    m.append(make_note(ns, step="F", octave=2, dur=qn, typ="quarter", staff=2, voice=5))
    # C3+F3 quarter
    m.append(make_note(ns, step="C", octave=3, dur=qn, typ="quarter", staff=2, voice=5))
    m.append(
        make_note(
            ns, step="F", octave=3, dur=qn, typ="quarter", staff=2, voice=5, chord=True
        )
    )
    # E2 quarter
    m.append(make_note(ns, step="E", octave=2, dur=qn, typ="quarter", staff=2, voice=5))
    # B2+E3 quarter
    m.append(make_note(ns, step="B", octave=2, dur=qn, typ="quarter", staff=2, voice=5))
    m.append(
        make_note(
            ns, step="E", octave=3, dur=qn, typ="quarter", staff=2, voice=5, chord=True
        )
    )


def main() -> None:
    sid = "radwimps_suzume"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}
    rh = rh_dense_a()
    for num in ("17", "19"):
        rewrite(by[num], ns, rh, lh_f_em())
    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] suzume m17/m19 RH dense A5-run vs PDF; still omrDraft")


if __name__ == "__main__":
    main()
