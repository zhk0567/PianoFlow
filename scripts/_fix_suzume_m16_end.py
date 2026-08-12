# -*- coding: utf-8 -*-
"""Suzume m16–26 rewrite vs PDF system crops (omrDraft only).

Sources (2026-08-09):
- auto_p1_sys4 / m17_rh → m17/m19 dense A5 run (also applied to normalize m16/m18)
- auto_p1_sys5 → m20–23
- auto_p2_sys1 → m24–26
m27–29 left as prior OMR (PDF end not re-signed). No formal.
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

S, E, Q, DE, H, BAR = 3, 6, 12, 9, 24, 48  # divisions=12


def N(
    ns,
    step,
    octv,
    dur,
    typ,
    staff=1,
    voice=1,
    chord=False,
    rest=False,
    dotted=False,
):
    return make_note(
        ns,
        step=None if rest else step,
        octave=None if rest else octv,
        dur=dur,
        typ=typ,
        staff=staff,
        voice=voice,
        chord=chord,
        rest=rest,
        dotted=dotted,
    )


def clear_rewrite(m, ns, rh_specs, lh_specs):
    clear_notes(m, ns)
    for sp in rh_specs:
        # (step, oct, dur, typ[, dotted])
        dotted = len(sp) > 4 and sp[4] is True and sp[0] is not None
        m.append(
            N(
                ns,
                sp[0],
                sp[1],
                sp[2],
                sp[3],
                staff=1,
                voice=1,
                rest=sp[0] is None,
                dotted=bool(dotted),
            )
        )
    append_backup(m, ns, BAR)
    for sp in lh_specs:
        chord = len(sp) > 4 and sp[4]
        m.append(
            N(
                ns,
                sp[0],
                sp[1],
                sp[2],
                sp[3],
                staff=2,
                voice=5,
                chord=bool(chord),
            )
        )


def lh_pulse(a_step, a_oct, b_step, b_oct, c_step, c_oct):
    """quarter root | quarter dyad | quarter root | quarter dyad"""
    return [
        (a_step, a_oct, Q, "quarter", False),
        (b_step, b_oct, Q, "quarter", False),
        (c_step, c_oct, Q, "quarter", True),
        (a_step, a_oct, Q, "quarter", False),
        (b_step, b_oct, Q, "quarter", False),
        (c_step, c_oct, Q, "quarter", True),
    ]


def lh_f_em():
    return [
        ("F", 2, Q, "quarter", False),
        ("C", 3, Q, "quarter", False),
        ("F", 3, Q, "quarter", True),
        ("E", 2, Q, "quarter", False),
        ("B", 2, Q, "quarter", False),
        ("E", 3, Q, "quarter", True),
    ]


def lh_am_g():
    return [
        ("A", 2, Q, "quarter", False),
        ("E", 3, Q, "quarter", False),
        ("A", 3, Q, "quarter", True),
        ("G", 2, Q, "quarter", False),
        ("D", 3, Q, "quarter", False),
        ("G", 3, Q, "quarter", True),
    ]


def dense_g():
    return [("G", 5, S, "16th")] * 4 + [("E", 5, S, "16th")] * 2 + [
        ("D", 5, S, "16th")
    ] * 6 + [("C", 5, S, "16th")] * 2 + [("D", 5, S, "16th")] * 2


def dense_a():
    return [
        ("A", 5, S, "16th"),
        ("G", 5, S, "16th"),
        ("F", 5, S, "16th"),
        ("F", 5, S, "16th"),
        ("E", 5, S, "16th"),
    ] + [("D", 5, S, "16th")] * 4 + [("C", 5, S, "16th")] * 4 + [
        ("D", 5, S, "16th"),
        ("E", 5, S, "16th"),
        ("D", 5, S, "16th"),
    ]


def main() -> None:
    sid = "radwimps_suzume"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}

    # m16 / m18 — dense G5 run (sys3/4 bridge); m17/m19 — dense A5 (already done, reapply)
    for num, rh, lh in (
        ("16", dense_g(), lh_am_g()),
        ("17", dense_a(), lh_f_em()),
        ("18", dense_g(), lh_am_g()),
        ("19", dense_a(), lh_f_em()),
    ):
        clear_rewrite(by[num], ns, rh, lh)

    # m20 — PDF sys5
    clear_rewrite(
        by["20"],
        ns,
        [
            ("G", 4, E, "eighth"),
            ("A", 4, E, "eighth"),
            ("G", 4, E, "eighth"),
            ("A", 4, E, "eighth"),
            ("G", 4, S, "16th"),
            ("A", 4, S, "16th"),
            ("B", 4, S, "16th"),
            ("C", 5, S, "16th"),
            ("B", 4, S, "16th"),
            ("A", 4, S, "16th"),
            ("G", 4, S, "16th"),
            ("F", 4, S, "16th"),
        ],
        lh_pulse("G", 2, "G", 3, "B", 3),
    )

    # m21
    clear_rewrite(
        by["21"],
        ns,
        [
            ("E", 4, E, "eighth"),
            ("F", 4, E, "eighth"),
            ("G", 4, E, "eighth"),
            ("F", 4, E, "eighth"),
            ("E", 4, E, "eighth"),
            ("D", 4, S, "16th"),
            ("C", 4, S, "16th"),
            (None, None, S, "16th"),  # rest
            ("C", 4, S, "16th"),
            ("D", 4, S, "16th"),
            ("C", 4, S, "16th"),
        ],
        [
            ("C", 3, Q, "quarter", False),
            ("C", 4, Q, "quarter", False),
            ("E", 4, Q, "quarter", True),
            ("G", 2, Q, "quarter", False),
            ("C", 4, Q, "quarter", False),
            ("E", 4, Q, "quarter", True),
        ],
    )

    # m22
    clear_rewrite(
        by["22"],
        ns,
        [
            ("F", 4, S, "16th"),
            ("G", 4, S, "16th"),
            ("A", 4, S, "16th"),
            ("B", 4, S, "16th"),
            ("C", 5, E, "eighth"),
            ("B", 4, E, "eighth"),
            ("A", 4, S, "16th"),
            ("G", 4, S, "16th"),
            ("F", 4, S, "16th"),
            ("E", 4, S, "16th"),
            ("D", 4, E, "eighth"),
            ("C", 4, E, "eighth"),
        ],
        lh_pulse("D", 3, "D", 4, "F", 4),
    )

    # m23 — scale cascade
    clear_rewrite(
        by["23"],
        ns,
        [
            ("G", 4, S, "16th"),
            ("F", 4, S, "16th"),
            ("E", 4, S, "16th"),
            ("D", 4, S, "16th"),
            ("C", 4, S, "16th"),
            ("B", 3, S, "16th"),
            ("A", 3, S, "16th"),
            ("G", 3, S, "16th"),
            ("A", 3, S, "16th"),
            ("B", 3, S, "16th"),
            ("C", 4, S, "16th"),
            ("D", 4, S, "16th"),
            ("E", 4, S, "16th"),
            ("F", 4, S, "16th"),
            ("G", 4, S, "16th"),
            ("A", 4, S, "16th"),
        ],
        lh_pulse("G", 2, "G", 3, "B", 3),
    )

    # m24: F5(6)+D5(12)+rest(3)+D5 E5 F5 G5 A5 A5 G5 F5 E5 (9×3) = 48
    clear_rewrite(
        by["24"],
        ns,
        [
            ("F", 5, E, "eighth"),
            ("D", 5, Q, "quarter"),
            (None, None, S, "16th"),
            ("D", 5, S, "16th"),
            ("E", 5, S, "16th"),
            ("F", 5, S, "16th"),
            ("G", 5, S, "16th"),
            ("A", 5, S, "16th"),
            ("A", 5, S, "16th"),
            ("G", 5, S, "16th"),
            ("F", 5, S, "16th"),
            ("E", 5, S, "16th"),
        ],
        lh_pulse("G", 2, "B", 2, "D", 3),
    )

    # m25
    clear_rewrite(
        by["25"],
        ns,
        [
            ("B", 5, S, "16th"),
            ("A", 5, S, "16th"),
            ("G", 5, S, "16th"),
            ("F", 5, S, "16th"),
            ("G", 5, S, "16th"),
            ("F", 5, S, "16th"),
            ("E", 5, S, "16th"),
            ("D", 5, S, "16th"),
            ("E", 5, S, "16th"),
            ("D", 5, S, "16th"),
            ("C", 5, S, "16th"),
            ("B", 4, S, "16th"),
            ("C", 5, S, "16th"),
            ("D", 5, S, "16th"),
            ("E", 5, S, "16th"),
            ("F", 5, S, "16th"),
        ],
        lh_pulse("C", 3, "E", 3, "G", 3),
    )

    # m26
    clear_rewrite(
        by["26"],
        ns,
        [
            ("G", 5, E, "eighth"),
            ("F", 5, S, "16th"),
            ("E", 5, S, "16th"),
            ("F", 5, DE, "eighth", True),
            ("G", 5, S, "16th"),
            ("A", 5, S, "16th"),
            ("G", 5, S, "16th"),
            ("F", 5, S, "16th"),
            ("E", 5, S, "16th"),
            ("D", 5, Q, "quarter"),
        ],
        lh_pulse("G", 2, "B", 2, "D", 3),
    )

    # verify RH sums
    for num in map(str, range(16, 27)):
        m = by[num]
        sm = 0
        for n in m:
            tag = n.tag.split("}")[-1] if "}" in n.tag else n.tag
            if tag != "note":
                continue
            staff = n.find("{*}staff")
            # ns-aware
            from _fix_omr_openings import q as qq

            st = n.findtext(qq(ns, "staff")) or "1"
            if st != "1":
                continue
            if n.find(qq(ns, "chord")) is not None:
                continue
            sm += int(n.findtext(qq(ns, "duration")) or 0)
        if sm != BAR:
            raise SystemExit(f"[PianoFlow/omr] m{num} RH sum={sm} want {BAR}")

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] suzume m16-26 rewritten vs PDF systems; m27-29 untouched; omrDraft")


if __name__ == "__main__":
    main()
