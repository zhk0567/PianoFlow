# -*- coding: utf-8 -*-
"""Rewrite Moonlight m1–69 in true 4/4 (4 triplet groups / bar).

PDF: third_party/scores_pdf/beethoven_moonlight_sonata.pdf (♩=44, C# minor).
m1–2 kept as arpeggio (matches DCMLab; drops OMR ghost G#5 on m1).
m3–15 rewritten from DCMLab 14-1 (matches original Audiveris OMR of repo PDF;
prior hand simplification of m3–8/m9–15 diverged from PDF+DCMLab).
m16–30 pitches cross-checked vs DCMLab 14-1 notes + original OMR.
m31–69 rewritten from DCMLab notes/14-1.notes.tsv (measure length matches 4/4).
Prior A♮/B rewrite of m16–18 was wrong (PDF/OMR/DCMLab = C♮–B–C♮).
"""
from __future__ import annotations

import csv
import re
import sys
from collections import defaultdict
from fractions import Fraction
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

BAR = 48  # divisions=12, 4/4
TRIP = 4  # triplet eighth written duration (3×4 = 1 quarter)
KEY_ALTER = {"F": 1, "C": 1, "G": 1, "D": 1}  # C# minor / E major key sig
_STEP_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def dcmlab_tsv_path() -> Path:
    primary = ROOT / "docs" / "omr_audit" / "_moonlight_proof" / "14-1.notes.tsv"
    if primary.is_file():
        return primary
    return ROOT / "_tmp_moon_ref" / "14-1.notes.tsv"


def ensure_time_44(measure: ET.Element, ns: str) -> None:
    for el in measure:
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag != "attributes":
            continue
        div = el.find(q(ns, "divisions"))
        if div is not None:
            div.text = "12"
        time_el = el.find(q(ns, "time"))
        if time_el is None:
            time_el = ET.Element(q(ns, "time"))
            kids = list(el)
            idx = 0
            for i, ch in enumerate(kids):
                ctag = ch.tag.replace(ns, "") if ns else ch.tag
                if ctag in ("key", "divisions"):
                    idx = i + 1
            el.insert(idx, time_el)
        beats = time_el.find(q(ns, "beats"))
        if beats is None:
            beats = ET.SubElement(time_el, q(ns, "beats"))
        beat_type = time_el.find(q(ns, "beat-type"))
        if beat_type is None:
            beat_type = ET.SubElement(time_el, q(ns, "beat-type"))
        beats.text = "4"
        beat_type.text = "4"
        return


def add_tm(note: ET.Element, ns: str) -> None:
    tm = ET.Element(q(ns, "time-modification"))
    a = ET.SubElement(tm, q(ns, "actual-notes"))
    a.text = "3"
    n = ET.SubElement(tm, q(ns, "normal-notes"))
    n.text = "2"
    kids = list(note)
    idx = 0
    for i, c in enumerate(kids):
        t = c.tag.replace(ns, "") if ns else c.tag
        if t in ("type", "duration"):
            idx = i + 1
    note.insert(idx, tm)


def trip_note(
    ns: str,
    step: str,
    octave: int,
    alter: int | None = None,
    *,
    staff: int = 1,
    voice: int = 2,
) -> ET.Element:
    n = make_note(
        ns,
        step=step,
        octave=octave,
        alter=alter,
        dur=TRIP,
        typ="eighth",
        staff=staff,
        voice=voice,
    )
    add_tm(n, ns)
    return n


def trips(
    ns: str,
    groups: list[tuple],
    *,
    staff: int = 1,
    voice: int = 2,
) -> list[ET.Element]:
    out: list[ET.Element] = []
    for g in groups:
        for item in g:
            if len(item) == 2:
                step, octv = item
                alter = None
            else:
                step, octv, alter = item
            out.append(trip_note(ns, step, octv, alter, staff=staff, voice=voice))
    return out


def lh_chord(
    ns: str,
    pitches: list[tuple],
    dur: int,
    typ: str,
    *,
    dotted: bool = False,
    voice: int = 5,
) -> list[ET.Element]:
    """pitches: (step, octave, alter|None) list; first is root, rest chord=True."""
    out: list[ET.Element] = []
    for i, item in enumerate(pitches):
        if len(item) == 2:
            step, octv = item
            alter = None
        else:
            step, octv, alter = item
        out.append(
            make_note(
                ns,
                step=step,
                octave=octv,
                alter=alter,
                dur=dur,
                typ=typ,
                staff=2,
                voice=voice,
                chord=i > 0,
                dotted=dotted,
            )
        )
    return out


def lh_octave(
    ns: str,
    step: str,
    octave: int,
    dur: int,
    typ: str,
    *,
    alter: int | None = None,
    dotted: bool = False,
    voice: int = 5,
) -> list[ET.Element]:
    a = make_note(
        ns,
        step=step,
        octave=octave,
        alter=alter,
        dur=dur,
        typ=typ,
        staff=2,
        voice=voice,
        dotted=dotted,
    )
    b = make_note(
        ns,
        step=step,
        octave=octave + 1,
        alter=alter,
        dur=dur,
        typ=typ,
        staff=2,
        voice=voice,
        chord=True,
        dotted=dotted,
    )
    return [a, b]


def rewrite_bar(
    m: ET.Element,
    ns: str,
    melody: list[dict] | None,
    trip_groups: list[tuple],
    lh: list[ET.Element],
    *,
    trip_staff: int = 1,
    trip_voice: int = 2,
) -> None:
    clear_notes(m, ns)
    if melody:
        for spec in melody:
            kwargs = dict(spec)
            staff = int(kwargs.pop("staff", 1))
            voice = int(kwargs.pop("voice", 1))
            m.append(make_note(ns, staff=staff, voice=voice, **kwargs))
        append_backup(m, ns, BAR)
    if trip_groups:
        for n in trips(ns, trip_groups, staff=trip_staff, voice=trip_voice):
            m.append(n)
        append_backup(m, ns, BAR)
    for n in lh:
        m.append(n)


def parse_dcmlab_pitch(name: str, midi: int) -> tuple[str, int, int]:
    """Return (step, octave, alter) using MIDI for accidental accuracy."""
    m = re.fullmatch(r"([A-G])(#{1,2}|b{1,2}|n)?(\d+)", name)
    if not m:
        raise ValueError(f"bad DCMLab name: {name}")
    step, _acc, octave = m.group(1), m.group(2), int(m.group(3))
    base = _STEP_PC[step] + 12 * (octave + 1)
    alter = int(midi) - base
    if alter < -2 or alter > 2:
        raise ValueError(f"alter out of range for {name} midi={midi}")
    return step, octave, alter


def frac_to_div(fr: Fraction) -> int:
    return int(fr * BAR)


def dur_type(div: int, *, is_trip: bool = False) -> tuple[str, bool]:
    if is_trip:
        return "eighth", False
    mapping = {
        48: ("whole", False),
        36: ("half", True),
        24: ("half", False),
        18: ("quarter", True),
        12: ("quarter", False),
        9: ("eighth", True),
        8: ("quarter", False),
        6: ("eighth", False),
        4: ("eighth", False),
        3: ("16th", False),
    }
    if div in mapping:
        return mapping[div]
    for cand, typ in (
        (48, ("whole", False)),
        (36, ("half", True)),
        (24, ("half", False)),
        (12, ("quarter", False)),
        (9, ("eighth", True)),
        (6, ("eighth", False)),
        (3, ("16th", False)),
    ):
        if div >= cand:
            return typ
    return "16th", False


def _append_rests(
    measure: ET.Element,
    ns: str,
    gap: int,
    *,
    staff: int,
    voice: int,
    is_trip: bool,
) -> None:
    remain = gap
    while remain > 0:
        if is_trip:
            chunk = TRIP if remain >= TRIP else remain
            n = make_note(
                ns,
                step=None,
                octave=None,
                dur=chunk,
                typ="eighth",
                staff=staff,
                voice=voice,
                rest=True,
            )
            add_tm(n, ns)
            measure.append(n)
            remain -= chunk
            continue
        placed = False
        for cand in (48, 36, 24, 12, 9, 6, 3):
            if remain >= cand:
                typ, dotted = dur_type(cand)
                measure.append(
                    make_note(
                        ns,
                        step=None,
                        octave=None,
                        dur=cand,
                        typ=typ,
                        staff=staff,
                        voice=voice,
                        rest=True,
                        dotted=dotted,
                    )
                )
                remain -= cand
                placed = True
                break
        if not placed:
            measure.append(
                make_note(
                    ns,
                    step=None,
                    octave=None,
                    dur=remain,
                    typ="16th",
                    staff=staff,
                    voice=voice,
                    rest=True,
                )
            )
            remain = 0


def _mark_accidental(note: ET.Element, ns: str, step: str, alter: int) -> None:
    expect = KEY_ALTER.get(step, 0)
    if alter == expect:
        return
    names = {
        0: "natural",
        1: "sharp",
        2: "double-sharp",
        -1: "flat",
        -2: "flat-flat",
    }
    acc = note.find(q(ns, "accidental"))
    if acc is None:
        acc = ET.Element(q(ns, "accidental"))
        pitch = note.find(q(ns, "pitch"))
        assert pitch is not None
        note.insert(list(note).index(pitch) + 1, acc)
    acc.text = names.get(alter, "sharp")


def emit_stream(
    measure: ET.Element,
    ns: str,
    events: list[tuple[int, int, list[tuple[str, int, int]]]],
    *,
    staff: int,
    voice: int,
    is_trip: bool = False,
) -> bool:
    """Emit timed notes/rests covering a full bar. events: (onset, dur, pitches)."""
    if not events:
        return False
    cursor = 0
    for onset, dur, pitches in events:
        if onset > cursor:
            _append_rests(
                measure, ns, onset - cursor, staff=staff, voice=voice, is_trip=is_trip
            )
        typ, dotted = dur_type(dur, is_trip=is_trip)
        for i, (step, octv, alter) in enumerate(pitches):
            n = make_note(
                ns,
                step=step,
                octave=octv,
                alter=alter if alter != 0 else (0 if step in KEY_ALTER else None),
                dur=dur,
                typ=typ,
                staff=staff,
                voice=voice,
                chord=i > 0,
                dotted=dotted,
            )
            # ensure natural against key sharps is encoded
            if alter == 0 and step in KEY_ALTER:
                pitch = n.find(q(ns, "pitch"))
                assert pitch is not None
                al = pitch.find(q(ns, "alter"))
                if al is None:
                    al = ET.Element(q(ns, "alter"))
                    al.text = "0"
                    pitch.insert(list(pitch).index(pitch.find(q(ns, "step"))) + 1, al)
                else:
                    al.text = "0"
            if is_trip:
                add_tm(n, ns)
            _mark_accidental(n, ns, step, alter)
            measure.append(n)
        cursor = onset + dur
    if cursor < BAR:
        _append_rests(
            measure, ns, BAR - cursor, staff=staff, voice=voice, is_trip=is_trip
        )
    return True


def group_dcmlab_events(
    rows: list[dict],
) -> list[tuple[int, int, list[tuple[str, int, int]]]]:
    by_onset: dict[tuple[int, int], list[tuple[str, int, int, int]]] = defaultdict(list)
    for r in rows:
        onset = frac_to_div(Fraction(r["mc_onset"]))
        dur = frac_to_div(Fraction(r["duration"]))
        step, octv, alter = parse_dcmlab_pitch(r["name"], int(r["midi"]))
        by_onset[(onset, dur)].append((step, octv, alter, int(r["midi"])))
    events: list[tuple[int, int, list[tuple[str, int, int]]]] = []
    for (onset, dur), pitches in sorted(by_onset.items()):
        seen: set[tuple[str, int, int]] = set()
        uniq: list[tuple[str, int, int]] = []
        for step, octv, alter, midi in sorted(pitches, key=lambda x: x[3]):
            key = (step, octv, alter)
            if key in seen:
                continue
            seen.add(key)
            uniq.append((step, octv, alter))
        events.append((onset, dur, uniq))
    return events


def load_dcmlab_rows() -> list[dict]:
    path = dcmlab_tsv_path()
    if not path.is_file():
        raise FileNotFoundError(
            f"[PianoFlow/omr] missing DCMLab TSV: {path} "
            "(download notes/14-1.notes.tsv from DCMLab/beethoven_piano_sonatas)"
        )
    with path.open(encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def rewrite_bar_from_dcmlab(measure: ET.Element, ns: str, rows: list[dict]) -> None:
    """Rewrite one measure from DCMLab note rows (full bar, divisions=12)."""
    clear_notes(measure, ns)
    # drop empty <attributes/> leftovers from old OMR
    for el in list(measure):
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag == "attributes" and len(list(el)) == 0:
            measure.remove(el)

    trip_rows = [r for r in rows if Fraction(r["duration"]) == Fraction(1, 12)]
    sust = [r for r in rows if Fraction(r["duration"]) != Fraction(1, 12)]

    mel_rows: list[dict] = []
    lh_rows: list[dict] = []
    for r in sust:
        staff = int(r["staff"])
        midi = int(r["midi"])
        dur = Fraction(r["duration"])
        if staff == 1:
            mel_rows.append(r)
        elif staff == 2 and midi >= 60 and dur <= Fraction(1, 4):
            # middle-voice accents (e.g. C#4/E4); keep A3 octave mates in LH
            mel_rows.append(r)
        else:
            lh_rows.append(r)

    trip_midis = [int(r["midi"]) for r in trip_rows]
    trip_staff, trip_voice = 1, 2
    if trip_midis and max(trip_midis) < 58 and not mel_rows:
        trip_staff, trip_voice = 2, 5

    emitted_any = False
    mel_events = group_dcmlab_events(mel_rows)
    if emit_stream(measure, ns, mel_events, staff=1, voice=1, is_trip=False):
        append_backup(measure, ns, BAR)
        emitted_any = True

    trip_events = group_dcmlab_events(trip_rows)
    if emit_stream(
        measure, ns, trip_events, staff=trip_staff, voice=trip_voice, is_trip=True
    ):
        append_backup(measure, ns, BAR)
        emitted_any = True

    lh_keys = sorted({(r["staff"], r["voice"]) for r in lh_rows})
    base_lh_voice = 6 if trip_staff == 2 else 5
    for i, key in enumerate(lh_keys):
        part = [r for r in lh_rows if (r["staff"], r["voice"]) == key]
        events = group_dcmlab_events(part)
        voice = base_lh_voice + i
        if emit_stream(measure, ns, events, staff=2, voice=voice, is_trip=False):
            emitted_any = True
            if i < len(lh_keys) - 1:
                append_backup(measure, ns, BAR)

    if not emitted_any:
        # safety: whole rest both staves
        measure.append(
            make_note(
                ns,
                step=None,
                octave=None,
                dur=BAR,
                typ="whole",
                staff=1,
                voice=1,
                rest=True,
            )
        )
        append_backup(measure, ns, BAR)
        measure.append(
            make_note(
                ns,
                step=None,
                octave=None,
                dur=BAR,
                typ="whole",
                staff=2,
                voice=5,
                rest=True,
            )
        )


def rewrite_mc_range_from_dcmlab(
    by: dict[str, ET.Element], ns: str, start: int, end: int
) -> int:
    rows = load_dcmlab_rows()
    max_mc = max(int(r["mc"]) for r in rows)
    end = min(end, max_mc, max(int(k) for k in by))
    n = 0
    for mc in range(start, end + 1):
        key = str(mc)
        if key not in by:
            print(f"[PianoFlow/omr] moonlight skip missing measure {mc}")
            continue
        mc_rows = [r for r in rows if int(r["mc"]) == mc]
        if not mc_rows:
            print(f"[PianoFlow/omr] moonlight no DCMLab rows for m{mc}")
            continue
        rewrite_bar_from_dcmlab(by[key], ns, mc_rows)
        n += 1
    return n


def rewrite_m31_end(by: dict[str, ET.Element], ns: str) -> int:
    return rewrite_mc_range_from_dcmlab(by, ns, 31, 10**9)


def pad_sum36(root: ET.Element, ns: str) -> int:
    """Pad 3/4 leftovers: repeat last trip group, or +12 on last melody note."""
    fixed = 0
    part = root.find(q(ns, "part"))
    assert part is not None
    for m in part.findall(q(ns, "measure")):
        notes = [
            n
            for n in m.findall(q(ns, "note"))
            if n.find(q(ns, "chord")) is None and n.findtext(q(ns, "duration"))
        ]
        by_v: dict[tuple[str, str], list[ET.Element]] = {}
        for n in notes:
            staff = n.findtext(q(ns, "staff")) or "1"
            voice = n.findtext(q(ns, "voice")) or "1"
            by_v.setdefault((staff, voice), []).append(n)

        changed = False
        for (staff, voice), els in list(by_v.items()):
            s = sum(int(e.findtext(q(ns, "duration")) or 0) for e in els)
            if s != 36:
                continue
            all_trip = all(e.findtext(q(ns, "duration")) == str(TRIP) for e in els)
            if staff == "1" and all_trip and len(els) >= 3:
                clones = [
                    ET.fromstring(ET.tostring(src, encoding="unicode"))
                    for src in els[-3:]
                ]
                last = els[-1]
                idx = list(m).index(last) + 1
                for i, c in enumerate(clones):
                    m.insert(idx + i, c)
                changed = True
            elif staff == "1" and not all_trip:
                # extend last melody/event by one quarter
                d = els[-1].find(q(ns, "duration"))
                if d is not None:
                    d.text = str(int(d.text or "0") + 12)
                    changed = True

        if changed:
            for n in m.findall(q(ns, "note")):
                if n.findtext(q(ns, "staff")) != "2":
                    continue
                d = n.find(q(ns, "duration"))
                if d is not None and d.text == "36":
                    d.text = "48"
                    t = n.find(q(ns, "type"))
                    if t is not None:
                        t.text = "whole"
                        for dot in list(n.findall(q(ns, "dot"))):
                            n.remove(dot)
            fixed += 1
    return fixed


def main() -> None:
    sid = "beethoven_moonlight_sonata"
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}
    ensure_time_44(by["1"], ns)

    gce = (("G", 3, 1), ("C", 4, 1), ("E", 4, None))  # G# C# E

    # m1–2: arpeggio only (matches DCMLab; strips OMR ghost G#5 on m1)
    rewrite_bar(
        by["1"],
        ns,
        None,
        [gce, gce, gce, gce],
        lh_octave(ns, "C", 2, BAR, "whole", alter=1),
    )
    rewrite_bar(
        by["2"],
        ns,
        None,
        [gce, gce, gce, gce],
        lh_octave(ns, "B", 1, BAR, "whole"),
    )
    # m3–15: DCMLab (= original Audiveris OMR of repo PDF for these bars)
    n_open = rewrite_mc_range_from_dcmlab(by, ns, 3, 15)
    print(f"[PianoFlow/omr] moonlight m3-15 from DCMLab ({n_open} bars)")

    # m16–30: DCMLab 14-1 + original OMR (C♮–B–C♮, NOT A♮–B–A♮)
    beg = (("B", 3, None), ("E", 4, None), ("G", 4, 0))  # B E G♮
    bdf = (("B", 3, None), ("D", 4, 1), ("F", 4, 1))  # B D# F#
    bde = (("B", 3, None), ("D", 4, 0), ("E", 4, 1))  # B D♮ E#
    bcg = (("B", 3, None), ("C", 4, 1), ("G", 4, 1))  # B C# G#
    acf = (("A", 3, None), ("C", 4, 1), ("F", 4, 1))  # A C# F#
    gbd_nat = (("G", 3, 0), ("B", 3, None), ("D", 4, 0))  # G♮ B D♮
    fad = (("F", 3, 1), ("A", 3, None), ("D", 4, 1))  # F# A D#
    cfa = (("C", 3, 1), ("F", 3, 1), ("A", 3, None))  # C# F# A
    cfg = (("C", 3, 1), ("F", 3, 1), ("G", 3, 1))  # C# F# G#
    ceg = (("C", 3, 1), ("E", 3, 1), ("G", 3, 1))  # C# E# G#
    cgb = (("C", 4, 1), ("G", 4, 1), ("B", 4, None))  # C# G# B
    cfa4 = (("C", 4, 1), ("F", 4, 1), ("A", 4, None))  # C# F# A
    bfa = (("B", 3, 1), ("F", 4, 1), ("A", 4, None))  # B# F# A
    dfg = (("D", 4, 1), ("F", 4, 1), ("G", 4, 1))  # D# F# G#
    egc = (("E", 4, None), ("G", 4, 1), ("C", 5, 1))  # E G# C#
    dfa = (("D", 4, 1), ("F", 4, 1), ("A", 4, None))  # D# F# A
    cea = (("C", 4, 1), ("E", 4, None), ("A", 4, 1))  # C# E A#

    # m16 / m18
    for mno in ("16", "18"):
        rewrite_bar(
            by[mno],
            ns,
            [
                dict(step="C", octave=5, alter=0, dur=36, typ="half", dotted=True),
                dict(step="A", octave=4, alter=1, dur=12, typ="quarter"),
            ],
            [beg, beg, beg, beg],
            lh_octave(ns, "B", 1, 12, "quarter")
            + lh_octave(ns, "E", 2, 12, "quarter")
            + lh_octave(ns, "G", 2, 12, "quarter", alter=0)
            + lh_octave(ns, "E", 2, 12, "quarter"),
        )
    # m17
    rewrite_bar(
        by["17"],
        ns,
        [
            dict(step="B", octave=4, dur=36, typ="half", dotted=True),
            dict(step="B", octave=4, dur=12, typ="quarter"),
        ],
        [bdf, bdf, bdf, bdf],
        lh_octave(ns, "B", 1, BAR, "whole"),
    )
    # m19
    rewrite_bar(
        by["19"],
        ns,
        [
            dict(step="B", octave=4, dur=24, typ="half"),
            dict(step="B", octave=4, dur=24, typ="half"),
        ],
        [bdf, bdf, bde, bde],
        lh_octave(ns, "B", 1, 24, "half")
        + lh_octave(ns, "G", 1, 24, "half", alter=1),
    )
    # m20
    rewrite_bar(
        by["20"],
        ns,
        [
            dict(step="B", octave=4, dur=24, typ="half"),
            dict(step="A", octave=4, dur=24, typ="half"),
        ],
        [bcg, bcg, acf, acf],
        lh_octave(ns, "E", 1, 24, "half", alter=1)
        + lh_octave(ns, "F", 1, 24, "half", alter=1),
    )
    # m21 — arpeggios in LH staff
    rewrite_bar(
        by["21"],
        ns,
        [
            dict(step="G", octave=4, alter=0, dur=24, typ="half"),
            dict(step="F", octave=4, alter=1, dur=24, typ="half"),
        ],
        [gbd_nat, gbd_nat, fad, fad],
        lh_octave(ns, "B", 1, 24, "half", voice=6)
        + lh_octave(ns, "B", 1, 24, "half", alter=1, voice=6),
        trip_staff=2,
        trip_voice=5,
    )
    # m22 — arpeggios in LH staff
    rewrite_bar(
        by["22"],
        ns,
        [
            dict(step="C", octave=4, alter=1, dur=24, typ="half"),
            dict(step="C", octave=4, alter=1, dur=12, typ="quarter"),
            dict(step="C", octave=4, alter=1, dur=12, typ="quarter"),
        ],
        [cfa, cfa, cfg, ceg],
        [
            make_note(ns, step="C", octave=2, alter=1, dur=24, typ="half", staff=2, voice=6),
            make_note(ns, step="C", octave=2, alter=1, dur=24, typ="half", staff=2, voice=6),
        ],
        trip_staff=2,
        trip_voice=5,
    )
    # m23 rising arpeggio + C#5 dotted-8th/16th
    rewrite_bar(
        by["23"],
        ns,
        [
            dict(step="F", octave=3, alter=1, dur=12, typ="quarter"),
            dict(step=None, octave=None, dur=24, typ="half", rest=True),
            dict(step="C", octave=5, alter=1, dur=9, typ="eighth", dotted=True),
            dict(step="C", octave=5, alter=1, dur=3, typ="16th"),
        ],
        [
            (("F", 3, 1), ("A", 3, None), ("C", 4, 1)),
            (("A", 3, None), ("C", 4, 1), ("F", 4, 1)),
            (("C", 4, 1), ("F", 4, 1), ("A", 4, None)),
            (("C", 4, 1), ("F", 4, 1), ("A", 4, None)),
        ],
        lh_chord(ns, [("F", 1, 1), ("C", 2, 1), ("F", 2, 1)], BAR, "whole"),
    )
    # m24
    rewrite_bar(
        by["24"],
        ns,
        [
            dict(step="C", octave=5, alter=1, dur=36, typ="half", dotted=True),
            dict(step="C", octave=5, alter=1, dur=9, typ="eighth", dotted=True),
            dict(step="C", octave=5, alter=1, dur=3, typ="16th"),
        ],
        [cgb, cgb, cgb, cgb],
        lh_chord(ns, [("E", 2, 1), ("C", 3, 1), ("E", 3, 1)], BAR, "whole"),
    )
    # m25
    rewrite_bar(
        by["25"],
        ns,
        [
            dict(step="C", octave=5, alter=1, dur=24, typ="half"),
            dict(step="B", octave=4, alter=1, dur=12, typ="quarter"),
            dict(step="C", octave=5, alter=1, dur=12, typ="quarter"),
        ],
        [cfa4, cfa4, bfa, cfa4],
        lh_octave(ns, "F", 2, 24, "half", alter=1)
        + lh_octave(ns, "D", 2, 12, "quarter", alter=1)
        + lh_octave(ns, "C", 2, 12, "quarter", alter=1),
    )
    # m26
    rewrite_bar(
        by["26"],
        ns,
        [
            dict(step="D", octave=5, alter=1, dur=36, typ="half", dotted=True),
            dict(step="D", octave=5, alter=1, dur=12, typ="quarter"),
        ],
        [dfg, dfg, dfg, dfg],
        lh_chord(ns, [("B", 1, 1), ("G", 2, 1), ("B", 2, 1)], 36, "half", dotted=True)
        + lh_chord(ns, [("B", 1, 1), ("G", 2, 1), ("B", 2, 1)], 12, "quarter"),
    )
    # m27
    rewrite_bar(
        by["27"],
        ns,
        [
            dict(step="E", octave=5, dur=24, typ="half"),
            dict(step="D", octave=5, alter=1, dur=12, typ="quarter"),
            dict(step="C", octave=5, alter=1, dur=12, typ="quarter"),
        ],
        [egc, egc, dfa, cea],
        lh_chord(ns, [("C", 2, 1), ("G", 2, 1), ("C", 3, 1)], 24, "half")
        + lh_octave(ns, "F", 1, 12, "quarter", alter=1)
        + lh_octave(ns, "F", 1, 12, "quarter", alter=2),
    )
    # m28 — B# leap trip + G#/A/F# accents
    rewrite_bar(
        by["28"],
        ns,
        [
            dict(step=None, octave=None, dur=12, typ="quarter", rest=True),
            dict(step="G", octave=4, alter=1, dur=12, typ="quarter"),
            dict(step="A", octave=4, dur=12, typ="quarter"),
            dict(step="F", octave=4, alter=1, dur=12, typ="quarter"),
        ],
        [
            (("B", 4, 1), ("B", 3, 1), ("D", 4, 1)),
            (("G", 4, 1), ("B", 3, 1), ("D", 4, 1)),
            (("A", 4, None), ("B", 3, 1), ("D", 4, 1)),
            (("F", 4, 1), ("B", 3, 1), ("D", 4, 1)),
        ],
        lh_octave(ns, "G", 1, BAR, "whole", alter=1),
    )
    # m29 — lower; eighth rest then trips; accents G#/A/F#
    clear_notes(by["29"], ns)
    by["29"].append(
        make_note(ns, step=None, octave=None, dur=12, typ="quarter", staff=1, voice=1, rest=True)
    )
    by["29"].append(
        make_note(ns, step="G", octave=3, alter=1, dur=12, typ="quarter", staff=1, voice=1)
    )
    by["29"].append(
        make_note(ns, step="A", octave=3, dur=12, typ="quarter", staff=1, voice=1)
    )
    by["29"].append(
        make_note(ns, step="F", octave=3, alter=1, dur=12, typ="quarter", staff=1, voice=1)
    )
    append_backup(by["29"], ns, BAR)
    rest_t = make_note(
        ns, step=None, octave=None, dur=TRIP, typ="eighth", staff=1, voice=2, rest=True
    )
    add_tm(rest_t, ns)
    by["29"].append(rest_t)
    for item in (
        ("B", 3, 1),
        ("D", 4, 1),
        ("G", 3, 1),
        ("B", 3, 1),
        ("D", 4, 1),
        ("A", 3, None),
        ("B", 3, 1),
        ("D", 4, 1),
        ("F", 3, 1),
        ("B", 3, 1),
        ("D", 4, 1),
    ):
        by["29"].append(trip_note(ns, *item))
    append_backup(by["29"], ns, BAR)
    for n in lh_octave(ns, "G", 1, BAR, "whole", alter=1):
        by["29"].append(n)

    # m30
    rewrite_bar(
        by["30"],
        ns,
        [
            dict(step=None, octave=None, dur=12, typ="quarter", rest=True),
            dict(step="C", octave=5, alter=1, dur=12, typ="quarter"),
            dict(step="E", octave=5, dur=12, typ="quarter"),
            dict(step="C", octave=5, alter=1, dur=12, typ="quarter"),
        ],
        [
            (("E", 3, None), ("E", 4, None), ("G", 4, 1)),
            (("C", 5, 1), ("E", 4, None), ("G", 4, 1)),
            (("E", 5, None), ("E", 4, None), ("G", 4, 1)),
            (("C", 5, 1), ("E", 4, None), ("G", 4, 1)),
        ],
        lh_octave(ns, "G", 1, BAR, "whole", alter=1),
    )

    def force_natural(measure: ET.Element, step: str, octave: str) -> None:
        for n in measure.findall(q(ns, "note")):
            p = n.find(q(ns, "pitch"))
            if p is None:
                continue
            if p.findtext(q(ns, "step")) != step or p.findtext(q(ns, "octave")) != octave:
                continue
            al = p.find(q(ns, "alter"))
            if al is None:
                al = ET.Element(q(ns, "alter"))
                al.text = "0"
                p.insert(list(p).index(p.find(q(ns, "step"))) + 1, al)
            else:
                al.text = "0"
            if n.find(q(ns, "accidental")) is None:
                acc = ET.Element(q(ns, "accidental"))
                acc.text = "natural"
                n.insert(list(n).index(p) + 1, acc)

    def force_accidental(measure: ET.Element, step: str, octave: str, alter: int, acc_name: str) -> None:
        for n in measure.findall(q(ns, "note")):
            p = n.find(q(ns, "pitch"))
            if p is None:
                continue
            if p.findtext(q(ns, "step")) != step or p.findtext(q(ns, "octave")) != octave:
                continue
            al = p.find(q(ns, "alter"))
            if al is None:
                al = ET.Element(q(ns, "alter"))
                al.text = str(alter)
                p.insert(list(p).index(p.find(q(ns, "step"))) + 1, al)
            else:
                al.text = str(alter)
            acc = n.find(q(ns, "accidental"))
            if acc is None:
                acc = ET.Element(q(ns, "accidental"))
                n.insert(list(n).index(p) + 1, acc)
            acc.text = acc_name

    force_natural(by["3"], "D", "4")
    force_natural(by["13"], "E", "4")
    force_natural(by["13"], "A", "2")
    force_natural(by["15"], "G", "4")
    force_natural(by["15"], "A", "4")
    # m16/18 C♮ melody + G♮ in trips/LH
    for mno in ("16", "18"):
        force_natural(by[mno], "C", "5")
        force_natural(by[mno], "G", "4")
        force_natural(by[mno], "G", "2")
        force_natural(by[mno], "G", "3")
        force_accidental(by[mno], "A", "4", 1, "sharp")
    # Only mark D♮ / E# where alter already matches (do not clobber D#)
    def mark_acc_if_alter(
        measure: ET.Element, step: str, octave: str, alter: int, acc_name: str
    ) -> None:
        for n in measure.findall(q(ns, "note")):
            p = n.find(q(ns, "pitch"))
            if p is None:
                continue
            if p.findtext(q(ns, "step")) != step or p.findtext(q(ns, "octave")) != octave:
                continue
            al = p.findtext(q(ns, "alter"))
            want = str(alter)
            have = al if al is not None else ("0" if alter == 0 else None)
            if have != want:
                continue
            acc = n.find(q(ns, "accidental"))
            if acc is None:
                acc = ET.Element(q(ns, "accidental"))
                n.insert(list(n).index(p) + 1, acc)
            acc.text = acc_name

    mark_acc_if_alter(by["19"], "D", "4", 0, "natural")
    mark_acc_if_alter(by["19"], "E", "4", 1, "sharp")
    mark_acc_if_alter(by["20"], "E", "1", 1, "sharp")
    mark_acc_if_alter(by["20"], "E", "2", 1, "sharp")
    mark_acc_if_alter(by["21"], "G", "4", 0, "natural")
    mark_acc_if_alter(by["21"], "G", "3", 0, "natural")
    mark_acc_if_alter(by["21"], "D", "4", 0, "natural")
    mark_acc_if_alter(by["21"], "B", "1", 1, "sharp")
    mark_acc_if_alter(by["21"], "B", "2", 1, "sharp")
    mark_acc_if_alter(by["22"], "E", "3", 1, "sharp")
    mark_acc_if_alter(by["24"], "E", "2", 1, "sharp")
    mark_acc_if_alter(by["24"], "E", "3", 1, "sharp")
    mark_acc_if_alter(by["25"], "B", "4", 1, "sharp")
    mark_acc_if_alter(by["25"], "B", "3", 1, "sharp")
    mark_acc_if_alter(by["26"], "B", "1", 1, "sharp")
    mark_acc_if_alter(by["26"], "B", "2", 1, "sharp")
    mark_acc_if_alter(by["27"], "F", "1", 2, "double-sharp")
    mark_acc_if_alter(by["27"], "F", "2", 2, "double-sharp")
    mark_acc_if_alter(by["27"], "A", "4", 1, "sharp")
    for mno in ("28", "29"):
        mark_acc_if_alter(by[mno], "B", "3", 1, "sharp")
        mark_acc_if_alter(by[mno], "B", "4", 1, "sharp")

    # m19–21 previously used force_* that clobbered D#/F# — removed

    # m31–end from DCMLab 14-1 (full-bar 4/4 / divisions=12)
    n_tail = rewrite_m31_end(by, ns)

    padded = pad_sum36(root, ns)
    save(sid, tree)
    convert(sid)
    print(
        f"[PianoFlow/omr] moonlight m1-2 + m3-15(DCMLab) + m16-30 + "
        f"m31-end({n_tail} bars) rewritten 4/4; padded_sum36={padded}"
    )


if __name__ == "__main__":
    main()
