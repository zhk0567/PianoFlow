# -*- coding: utf-8 -*-
"""Continue omrDraft fixes: qing LH/RH, haru opening, castle m19+m25. Still omrDraft."""
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


def rewrite(m, ns, rh, lh, bar: int) -> None:
    clear_notes(m, ns)
    for s in rh:
        m.append(make_note(ns, **s, staff=1, voice=1))
    append_backup(m, ns, bar)
    for s in lh:
        m.append(make_note(ns, **s, staff=2, voice=5))


def fix_qing() -> None:
    """PDF: m1 G|Em, m2 C|D; RH rests until m5 chord hits."""
    sid = "jay_chou_qing_tian"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}
    # divisions typically 8 for this score — detect
    div = 8
    for el in by["1"].iter():
        if (el.tag.split("}")[-1]) == "divisions" and el.text:
            div = int(el.text)
            break
    e, q, h, w = div // 2, div, div * 2, div * 4
    s = div // 4  # 16th if div=8 → 2

    def eighths(seq: list[tuple[str, int, int | None]]) -> list[dict]:
        out = []
        for st, octv, alt in seq:
            out.append(
                dict(step=st, octave=octv, dur=e, typ="eighth", alter=alt)
                if alt is not None
                else dict(step=st, octave=octv, dur=e, typ="eighth")
            )
        return out

    g = eighths([("G", 2, None), ("D", 3, None), ("G", 3, None), ("B", 3, None)])
    em = eighths([("E", 2, None), ("B", 2, None), ("E", 3, None), ("G", 3, None)])
    c = eighths([("C", 2, None), ("G", 2, None), ("C", 3, None), ("E", 3, None)])
    d = eighths(
        [("D", 2, None), ("A", 2, None), ("D", 3, None), ("F", 3, 1)]
    )
    rest_w = [dict(step=None, octave=None, dur=w, typ="whole", rest=True)]

    rewrite(by["1"], ns, rest_w, g + em, w)
    rewrite(by["2"], ns, rest_w, c + d, w)
    rewrite(by["3"], ns, rest_w, g + em, w)
    # m4: PDF G arp + walk C4 B3 A3 B3 (approx 8ths; last pair as 16ths→keep 8ths A3 B3)
    m4_lh = eighths(
        [
            ("G", 2, None),
            ("D", 3, None),
            ("G", 3, None),
            ("B", 3, None),
            ("C", 4, None),
            ("B", 3, None),
            ("A", 3, None),
            ("B", 3, None),
        ]
    )
    rewrite(by["4"], ns, rest_w, m4_lh, w)

    def chord3(notes: list[tuple[str, int]], dur: int, typ: str, dotted=False) -> list[dict]:
        specs = []
        for i, (st, octv) in enumerate(notes):
            specs.append(
                dict(
                    step=st,
                    octave=octv,
                    dur=dur,
                    typ=typ,
                    dotted=dotted,
                    chord=(i > 0),
                )
            )
        return specs

    # m5: dotted-8th+16th GBD ×2, then ACE ×2
    de, sn = e + s, s  # dotted eighth + sixteenth when div=8 → 6+2? Wait e=4 if div=8
    # if div=8: eighth=4, sixteenth=2, dotted eighth=6
    de, sn = e + s if s else e, s if s else e // 2
    if div % 4 != 0:
        de, sn = e, e  # fallback equal eighths
        m5_rh = (
            chord3([("G", 4), ("B", 4), ("D", 5)], e, "eighth")
            + chord3([("G", 4), ("B", 4), ("D", 5)], e, "eighth")
            + chord3([("A", 4), ("C", 5), ("E", 5)], e, "eighth")
            + chord3([("A", 4), ("C", 5), ("E", 5)], e, "eighth")
        )
    else:
        m5_rh = (
            chord3([("G", 4), ("B", 4), ("D", 5)], de, "eighth", dotted=True)
            + chord3([("G", 4), ("B", 4), ("D", 5)], sn, "16th")
            + chord3([("A", 4), ("C", 5), ("E", 5)], de, "eighth", dotted=True)
            + chord3([("A", 4), ("C", 5), ("E", 5)], sn, "16th")
        )
    m5_lh = eighths(
        [
            ("G", 2, None),
            ("D", 3, None),
            ("G", 3, None),
            ("B", 3, None),
            ("C", 4, None),
            ("B", 3, None),
            ("G", 3, None),
            ("D", 3, None),
        ]
    )
    rewrite(by["5"], ns, m5_rh, m5_lh, w)

    # m6: G4 + BD ; G4 + BD ; A4 + CE ; A4 + CE
    def note_then_chord(melody: tuple[str, int], ch: list[tuple[str, int]]) -> list[dict]:
        return [dict(step=melody[0], octave=melody[1], dur=e, typ="eighth")] + chord3(
            ch, e, "eighth"
        )

    m6_rh = (
        note_then_chord(("G", 4), [("B", 4), ("D", 5)])
        + note_then_chord(("G", 4), [("B", 4), ("D", 5)])
        + note_then_chord(("A", 4), [("C", 5), ("E", 5)])
        + note_then_chord(("A", 4), [("C", 5), ("E", 5)])
    )
    m6_lh = eighths(
        [
            ("E", 2, None),
            ("B", 2, None),
            ("E", 3, None),
            ("G", 3, None),
            ("A", 3, None),
            ("G", 3, None),
            ("E", 3, None),
            ("B", 2, None),
        ]
    )
    rewrite(by["6"], ns, m6_rh, m6_lh, w)

    # m7: dotted GBD×2 twice (PDF both halves G)
    if div % 4 == 0:
        gbd = chord3([("G", 4), ("B", 4), ("D", 5)], de, "eighth", dotted=True) + chord3(
            [("G", 4), ("B", 4), ("D", 5)], sn, "16th"
        )
        m7_rh = gbd + gbd
    else:
        m7_rh = chord3([("G", 4), ("B", 4), ("D", 5)], e, "eighth") * 4
    m7_lh = eighths(
        [
            ("C", 2, None),
            ("G", 2, None),
            ("C", 3, None),
            ("E", 3, None),
            ("F", 3, None),
            ("E", 3, None),
            ("C", 3, None),
            ("G", 2, None),
        ]
    )
    rewrite(by["7"], ns, m7_rh, m7_lh, w)

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] qing_tian m1-7 LH/RH aligned to PDF, still omrDraft")


def fix_haru() -> None:
    """PDF sys1: 6/8 key=5 tempo97; m1-3 opening chords (G#m / C#m / B)."""
    sid = "haruhikage"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}
    div = 4
    for el in by["1"].iter():
        if el.tag.split("}")[-1] == "divisions" and el.text:
            div = int(el.text)
            break
    # 6/8 bar = 6 eighths
    e = div  # eighth
    dq = div * 3  # dotted quarter = 3 eighths
    bar = div * 6
    dh = bar  # dotted half spanning bar

    def chord(notes: list[tuple[str, int, int | None]], dur: int, typ: str, dotted=False) -> list[dict]:
        out = []
        for i, (st, octv, alt) in enumerate(notes):
            d = dict(
                step=st,
                octave=octv,
                dur=dur,
                typ=typ,
                dotted=dotted,
                chord=(i > 0),
            )
            if alt is not None:
                d["alter"] = alt
            out.append(d)
        return out

    # m1: G#4 B4 D#5 dotted-q; 8th rest; D#5 e; B4 e | LH E2 B2 E3 dotted-half
    rh1 = (
        chord([("G", 4, 1), ("B", 4, None), ("D", 5, 1)], dq, "quarter", dotted=True)
        + [dict(step=None, octave=None, dur=e, typ="eighth", rest=True)]
        + [dict(step="D", octave=5, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=4, dur=e, typ="eighth")]
    )
    lh1 = chord([("E", 2, None), ("B", 2, None), ("E", 3, None)], dh, "half", dotted=True)
    rewrite(by["1"], ns, rh1, lh1, bar)

    # m2: G#4 B4 D#5 e; B4 e; G#4 e; F#5 dotted-e; G#5 16th; F#5 e | LH C#2 G#2 C#3
    # simplify voices: chord + B4 G#4 + F#5 de G#5 s F#5 e
    s = div // 2 if div >= 2 else 1
    de = e + s if div >= 2 else e
    rh2 = (
        chord([("G", 4, 1), ("B", 4, None), ("D", 5, 1)], e, "eighth")
        + [dict(step="B", octave=4, dur=e, typ="eighth")]
        + [dict(step="G", octave=4, alter=1, dur=e, typ="eighth")]
        + [dict(step="F", octave=5, alter=1, dur=de, typ="eighth", dotted=True)]
        + [dict(step="G", octave=5, alter=1, dur=s, typ="16th")]
        + [dict(step="F", octave=5, alter=1, dur=e, typ="eighth")]
    )
    # duration check: e+e+e+de+s+e = 3e + (e+s) + s + e = 5e + 2s
    # want 6e: if s=e/2, 5e+e=6e OK when div even
    lh2 = chord([("C", 2, 1), ("G", 2, 1), ("C", 3, 1)], dh, "half", dotted=True)
    rewrite(by["2"], ns, rh2, lh2, bar)

    # m3: B4 D#5 F#5 e; G#4 B4 D#5 (as three 8ths or chord+); B5 de C#6 s B5 e | LH F#2 C#3 F#3
    rh3 = (
        chord([("B", 4, None), ("D", 5, 1), ("F", 5, 1)], e, "eighth")
        + [dict(step="G", octave=4, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=4, dur=e, typ="eighth")]
        + [dict(step="D", octave=5, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=5, dur=de, typ="eighth", dotted=True)]
        + [dict(step="C", octave=6, alter=1, dur=s, typ="16th")]
        + [dict(step="B", octave=5, dur=e, typ="eighth")]
    )
    # e*4 + de + s + e = 5e + de + s = 5e + e + s + s = 6e + 2s if wrong
    # Want: chord e + three e + de + s + e = 4e + (e+s) + s + e = 6e + 2s — OVER
    # PDF: chord e, then G#4 B4 D#5 as three 8ths (=3e), then B5 de C#6 s B5 e
    # = 1+3+1.5+0.5+1 = 7 eighths — OVER 6/8. Vision may have overcounted.
    # Safer: chord dq; G#4 e B4 e; B5 e | or chord e + G# B D# + B5 dq
    rh3 = (
        chord([("B", 4, None), ("D", 5, 1), ("F", 5, 1)], e, "eighth")
        + [dict(step="G", octave=4, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=4, dur=e, typ="eighth")]
        + [dict(step="D", octave=5, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=5, dur=dq, typ="quarter", dotted=True)]
    )
    # 4e + 3e = 7e still over. Use: chord dq + G# e + B5 e? = 3+1+1=5, need 1 more
    rh3 = (
        chord([("B", 4, None), ("D", 5, 1), ("F", 5, 1)], dq, "quarter", dotted=True)
        + [dict(step="G", octave=4, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=4, dur=e, typ="eighth")]
        + [dict(step="D", octave=5, alter=1, dur=e, typ="eighth")]
    )
    lh3 = chord([("F", 2, 1), ("C", 3, 1), ("F", 3, 1)], dh, "half", dotted=True)
    rewrite(by["3"], ns, rh3, lh3, bar)

    # m4: A#4 C#5 F#5 — G#m-ish; LH G#2 D#3 G#3 (from PDF)
    rh4 = (
        chord([("A", 4, 1), ("C", 5, 1), ("F", 5, 1)], dq, "quarter", dotted=True)
        + [dict(step="D", octave=6, alter=1, dur=de, typ="eighth", dotted=True)]
        + [dict(step="E", octave=6, dur=s, typ="16th")]
        + [dict(step="D", octave=6, alter=1, dur=e, typ="eighth")]
    )
    # dq + de + s + e = 3e + e + s + s + e = 5e + 2s = 6e when s=e/2
    lh4 = chord([("G", 2, 1), ("D", 3, 1), ("G", 3, 1)], dh, "half", dotted=True)
    rewrite(by["4"], ns, rh4, lh4, bar)

    # m5: G# B D# e + E5 D#5 B4 G#4 | LH E2 B2 E3 dq + B2 e E3 e
    rh5 = (
        chord([("G", 4, 1), ("B", 4, None), ("D", 5, 1)], e, "eighth")
        + [dict(step="E", octave=5, dur=e, typ="eighth")]
        + [dict(step="D", octave=5, alter=1, dur=e, typ="eighth")]
        + [dict(step="B", octave=4, dur=e, typ="eighth")]
        + [dict(step="G", octave=4, alter=1, dur=e, typ="eighth")]
        + [dict(step=None, octave=None, dur=e, typ="eighth", rest=True)]
    )
    lh5 = (
        chord([("E", 2, None), ("B", 2, None), ("E", 3, None)], dq, "quarter", dotted=True)
        + [dict(step="B", octave=2, dur=e, typ="eighth")]
        + [dict(step="E", octave=3, dur=e, typ="eighth")]
    )
    rewrite(by["5"], ns, rh5, lh5, bar)

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] haruhikage m1-5 rewritten from PDF, still omrDraft")


def fix_castle_bridge() -> None:
    """Labeled crops: m19 E5+A4A4/A3; m25 C5 + Am arp; m26 A5 G5 / A3 G3."""
    sid = "hisaishi_castle_in_the_sky"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}
    qn, en, hn, dhn, wn = 6, 3, 12, 18, 24

    # m19
    rewrite(
        by["19"],
        ns,
        [
            dict(step="E", octave=5, dur=dhn, typ="half", dotted=True),
            dict(step="A", octave=4, dur=en, typ="eighth"),
            dict(step="A", octave=4, dur=en, typ="eighth"),
        ],
        [dict(step="A", octave=3, dur=wn, typ="whole")],
        wn,
    )
    # m20 — single-measure crop: F5 dotted-q D5 e E5 q F5 q / B2 (LH uncertain→F2 common after A)
    rewrite(
        by["20"],
        ns,
        [
            dict(step="F", octave=5, dur=qn + en, typ="quarter", dotted=True),
            dict(step="D", octave=5, dur=en, typ="eighth"),
            dict(step="E", octave=5, dur=qn, typ="quarter"),
            dict(step="F", octave=5, dur=qn, typ="quarter"),
        ],
        [dict(step="F", octave=2, dur=wn, typ="whole")],
        wn,
    )
    # m25 labeled: C5 whole; LH A2 C3 E3 A3 + C4 half (fingering 5-2-1-3-2)
    rewrite(
        by["25"],
        ns,
        [dict(step="C", octave=5, dur=wn, typ="whole")],
        [
            dict(step="A", octave=2, dur=en, typ="eighth"),
            dict(step="C", octave=3, dur=en, typ="eighth"),
            dict(step="E", octave=3, dur=en, typ="eighth"),
            dict(step="A", octave=3, dur=en, typ="eighth"),
            dict(step="C", octave=4, dur=hn, typ="half"),
        ],
        wn,
    )
    # m26: A5 G5 halves / A3 G3 (was wrongly at m25 in OMR)
    rewrite(
        by["26"],
        ns,
        [
            dict(step="A", octave=5, dur=hn, typ="half"),
            dict(step="G", octave=5, dur=hn, typ="half"),
        ],
        [
            dict(step="A", octave=3, dur=hn, typ="half"),
            dict(step="G", octave=3, dur=hn, typ="half"),
        ],
        wn,
    )
    # m27: E5 D5 8ths, C5 half, C5 C5 8ths / F3 — from s5_m2-ish + prior OMR motif
    rewrite(
        by["27"],
        ns,
        [
            dict(step="E", octave=5, dur=en, typ="eighth"),
            dict(step="D", octave=5, dur=en, typ="eighth"),
            dict(step="C", octave=5, dur=hn, typ="half"),
            dict(step="C", octave=5, dur=en, typ="eighth"),
            dict(step="C", octave=5, dur=en, typ="eighth"),
        ],
        [dict(step="F", octave=3, dur=wn, typ="whole")],
        wn,
    )
    # m28: C5 C5, D5, E5 F5, G5 / G2
    rewrite(
        by["28"],
        ns,
        [
            dict(step="C", octave=5, dur=en, typ="eighth"),
            dict(step="C", octave=5, dur=en, typ="eighth"),
            dict(step="D", octave=5, dur=qn, typ="quarter"),
            dict(step="E", octave=5, dur=en, typ="eighth"),
            dict(step="F", octave=5, dur=en, typ="eighth"),
            dict(step="G", octave=5, dur=qn, typ="quarter"),
        ],
        [dict(step="G", octave=2, dur=wn, typ="whole")],
        wn,
    )
    # m29: E5 dotted half, C5 q / C3 G3
    rewrite(
        by["29"],
        ns,
        [
            dict(step="E", octave=5, dur=dhn, typ="half", dotted=True),
            dict(step="C", octave=5, dur=qn, typ="quarter"),
        ],
        [
            dict(step="C", octave=3, dur=hn, typ="half"),
            dict(step="G", octave=3, dur=hn, typ="half"),
        ],
        wn,
    )
    # m30: D5, F5 half, E5 / F3 C4 — leads into m31 A4 G4 F4
    rewrite(
        by["30"],
        ns,
        [
            dict(step="D", octave=5, dur=qn, typ="quarter"),
            dict(step="F", octave=5, dur=hn, typ="half"),
            dict(step="E", octave=5, dur=qn, typ="quarter"),
        ],
        [
            dict(step="F", octave=3, dur=hn, typ="half"),
            dict(step="C", octave=4, dur=hn, typ="half"),
        ],
        wn,
    )

    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] castle m19-20 + m25-30 rewritten (m21-24 still prior), omrDraft")


def main() -> None:
    fix_qing()
    fix_haru()
    fix_castle_bridge()


if __name__ == "__main__":
    main()
