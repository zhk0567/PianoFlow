#!/usr/bin/env python3
"""Convert assets/scores/*.json → simplified MusicXML for Verovio.

Writes to both:
  - assets/scores/musicxml/     (packaged app asset)
  - third_party/scores_musicxml/ (source of truth / sync target)

Skips ids that already have MusicXML unless --force.
Mirrors lib/features/practice/staff/score_to_musicxml.dart logic.

Verovio requires a non-empty <type>: duration alone only sets dur.ges and
renders stemless noteheads (no logical @dur).
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_DIR = ROOT / "assets" / "scores"
ASSET_XML = ROOT / "assets" / "scores" / "musicxml"
SRC_XML = ROOT / "third_party" / "scores_musicxml"

FORMAL_IDS = {
    "fur_elise_woo59",
    "pachelbel_canon_d",
    # Requires PDF-matched MusicXML via build_megalovania.py — never MIDI→MusicXML.
    "toby_fox_megalovania",
}

STEPS = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
ALTERS = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]

# (type name, undotted length in quarter-notes)
_TYPE_QUARTERS: list[tuple[str, float]] = [
    ("whole", 4.0),
    ("half", 2.0),
    ("quarter", 1.0),
    ("eighth", 0.5),
    ("16th", 0.25),
    ("32nd", 0.125),
    ("64th", 0.0625),
]

_BEAMABLE = {"eighth", "16th", "32nd", "64th"}


def duration_to_type(d: int, divisions: int) -> tuple[str, int]:
    """Map MusicXML duration/divisions → (type, dot_count)."""
    quarters = max(d, 1) / max(divisions, 1)
    best_name, best_dots = "quarter", 0
    best_err = 1e9
    for name, q in _TYPE_QUARTERS:
        for dots in (0, 1, 2):
            mult = 1.0 + sum(0.5 ** (i + 1) for i in range(dots))
            err = abs(quarters - q * mult)
            if err < best_err - 1e-9:
                best_err = err
                best_name, best_dots = name, dots
    return best_name, best_dots


def type_xml(d: int, divisions: int) -> str:
    name, dots = duration_to_type(d, divisions)
    return f"<type>{name}</type>" + ("<dot/>" * dots)


def beam_xml(value: str) -> str:
    return f'<beam number="1">{value}</beam>'


def esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def midi_to_pitch(midi: int) -> tuple[str, int, int]:
    pc = midi % 12
    octave = midi // 12 - 1
    return STEPS[pc], ALTERS[pc], octave


def write_staff_voice(
    lines: list[str],
    notes: list[dict],
    *,
    staff: int,
    measure_start: float,
    measure_beats: float,
    divisions: int,
) -> None:
    if not notes:
        d = int(round(measure_beats * divisions))
        lines.append(
            f'<note><rest measure="yes"/><duration>{d}</duration>'
            f"<voice>{staff}</voice><staff>{staff}</staff></note>"
        )
        return

    notes = sorted(notes, key=lambda n: float(n["start"]))

    # Pass 1: build timed events (rests + note groups) with clipped durations.
    events: list[dict] = []
    cursor = 0.0
    i = 0
    while i < len(notes):
        n = notes[i]
        onset = max(0.0, min(measure_beats, float(n["start"]) - measure_start))
        if onset <= cursor - 0.001:
            # Overlap / past end — skip
            i += 1
            continue
        if onset > cursor + 0.001:
            rest_beats = onset - cursor
            d = max(1, min(9999, int(round(rest_beats * divisions))))
            events.append({"kind": "rest", "d": d})
            cursor += d / divisions

        group = [n]
        j = i + 1
        while j < len(notes) and abs(float(notes[j]["start"]) - float(n["start"])) < 0.02:
            group.append(notes[j])
            j += 1

        remain = max(0.0, measure_beats - cursor)
        if remain < 0.05:
            break
        dur_beats = max(0.05, min(remain, float(n["duration"])))
        d = max(1, min(9999, int(round(dur_beats * divisions))))
        # Keep measure sum exact when near the end.
        if cursor + d / divisions > measure_beats + 0.001:
            d = max(1, int(round((measure_beats - cursor) * divisions)))
        tname, _ = duration_to_type(d, divisions)
        events.append(
            {
                "kind": "notes",
                "d": d,
                "group": group,
                "type_name": tname,
                "beamable": tname in _BEAMABLE,
            }
        )
        cursor += d / divisions
        i = j
        if cursor >= measure_beats - 0.001:
            break

    if cursor < measure_beats - 0.05:
        d = max(1, min(9999, int(round((measure_beats - cursor) * divisions))))
        events.append({"kind": "rest", "d": d})

    # Pass 2: assign beams for consecutive beamable (non-chord-only) groups.
    beam_vals: dict[int, str] = {}
    k = 0
    while k < len(events):
        ev = events[k]
        if ev["kind"] != "notes" or not ev["beamable"]:
            k += 1
            continue
        run = [k]
        t0 = ev["type_name"]
        m = k + 1
        while (
            m < len(events)
            and events[m]["kind"] == "notes"
            and events[m]["beamable"]
            and events[m]["type_name"] == t0
        ):
            run.append(m)
            m += 1
        if len(run) >= 2:
            beam_vals[run[0]] = "begin"
            for mid in run[1:-1]:
                beam_vals[mid] = "continue"
            beam_vals[run[-1]] = "end"
        k = m

    # Pass 3: emit XML.
    for idx, ev in enumerate(events):
        d = ev["d"]
        tx = type_xml(d, divisions)
        if ev["kind"] == "rest":
            lines.append(
                f"<note><rest/><duration>{d}</duration>{tx}"
                f"<voice>{staff}</voice><staff>{staff}</staff></note>"
            )
            continue
        bx = beam_xml(beam_vals[idx]) if idx in beam_vals else ""
        for g, gn in enumerate(ev["group"]):
            step, alter, octave = midi_to_pitch(int(gn["midi"]))
            chord = "<chord/>" if g > 0 else ""
            alter_xml = f"<alter>{alter}</alter>" if alter else ""
            # Beams only on the primary (non-chord) note.
            beam_part = bx if g == 0 else ""
            lines.append(
                f"<note>{chord}<pitch><step>{step}</step>{alter_xml}"
                f"<octave>{octave}</octave></pitch>"
                f"<duration>{d}</duration>{tx}<voice>{staff}</voice>"
                f"{beam_part}<staff>{staff}</staff></note>"
            )


def score_to_musicxml(data: dict) -> str:
    notes = data.get("notes") or []
    divisions = 4
    ts = data.get("timeSignature") or {}
    time_num = int(ts.get("num", 4))
    time_den = int(ts.get("den", 4))
    fifths = int(data.get("keySignature", 0))
    bpm = int(data.get("bpm", 100))
    title = str(data.get("title", data.get("id", "score")))
    bpm_measure = time_num * (4.0 / time_den)

    end_beat = 0.0
    for n in notes:
        end_beat = max(end_beat, float(n["start"]) + float(n["duration"]))
    if end_beat <= 0:
        end_beat = bpm_measure
    measure_count = max(1, min(512, math.ceil(end_beat / bpm_measure)))

    by_measure: dict[int, list[dict]] = {}
    for n in notes:
        mi = max(0, min(measure_count - 1, int(math.floor(float(n["start"]) / bpm_measure))))
        by_measure.setdefault(mi, []).append(n)

    lines: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" '
        '"http://www.musicxml.org/dtds/partwise.dtd">',
        '<score-partwise version="3.1">',
        f"<work><work-title>{esc(title)}</work-title></work>",
        "<identification>",
        "<rights>PianoFlow simplified MusicXML generated from practice JSON "
        "(not a formal engraving)</rights>",
        "</identification>",
        '<part-list><score-part id="P1"><part-name print-object="no">Piano</part-name></score-part></part-list>',
        '<part id="P1">',
    ]

    for mi in range(measure_count):
        m_start = mi * bpm_measure
        lines.append(f'<measure number="{mi + 1}">')
        if mi == 0:
            lines.append("<attributes>")
            lines.append(f"<divisions>{divisions}</divisions>")
            lines.append(f"<key><fifths>{fifths}</fifths></key>")
            lines.append(
                f"<time><beats>{time_num}</beats><beat-type>{time_den}</beat-type></time>"
            )
            lines.append("<staves>2</staves>")
            lines.append('<clef number="1"><sign>G</sign><line>2</line></clef>')
            lines.append('<clef number="2"><sign>F</sign><line>4</line></clef>')
            lines.append("</attributes>")
            lines.append(
                '<direction placement="above"><direction-type>'
                f"<metronome><beat-unit>quarter</beat-unit><per-minute>{bpm}</per-minute></metronome>"
                f'</direction-type><sound tempo="{bpm}"/></direction>'
            )

        m_notes = by_measure.get(mi, [])
        rh = [n for n in m_notes if n.get("hand", "right") != "left"]
        lh = [n for n in m_notes if n.get("hand", "right") == "left"]
        write_staff_voice(
            lines, rh, staff=1, measure_start=m_start, measure_beats=bpm_measure, divisions=divisions
        )
        measure_divs = int(round(bpm_measure * divisions))
        lines.append(f"<backup><duration>{measure_divs}</duration></backup>")
        write_staff_voice(
            lines, lh, staff=2, measure_start=m_start, measure_beats=bpm_measure, divisions=divisions
        )
        lines.append("</measure>")

    lines.append("</part></score-partwise>")
    return "\n".join(lines) + "\n"


def has_musicxml(sid: str) -> bool:
    for base in (ASSET_XML, SRC_XML):
        for ext in (".musicxml", ".xml", ".mxl"):
            if (base / f"{sid}{ext}").exists():
                return True
    return False


def fill_empty_types_in_xml(text: str) -> tuple[str, int]:
    """Surgical repair: replace empty <type></type> using sibling <duration>.

    Does not rewrite pitches or structure — safe for formal textbook files.
    """
    div_m = re.search(r"<divisions>\s*(\d+)\s*</divisions>", text)
    divisions = int(div_m.group(1)) if div_m else 4
    fixed = 0

    def repl_note(m: re.Match[str]) -> str:
        nonlocal fixed
        note = m.group(0)
        if "<type></type>" not in note and not re.search(r"<type\s*/>", note):
            # Missing type entirely (simplified legacy) — insert after duration.
            if "<type>" not in note:
                dm = re.search(r"<duration>\s*(\d+)\s*</duration>", note)
                if not dm:
                    return note
                d = int(dm.group(1))
                tx = type_xml(d, divisions)
                fixed += 1
                return note.replace(dm.group(0), dm.group(0) + tx, 1)
            return note
        dm = re.search(r"<duration>\s*(\d+)\s*</duration>", note)
        if not dm:
            return note
        d = int(dm.group(1))
        tx = type_xml(d, divisions)
        fixed += 1
        note2 = note.replace("<type></type>", tx, 1)
        note2 = re.sub(r"<type\s*/>", tx, note2, count=1)
        return note2

    out = re.sub(r"<note\b[\s\S]*?</note>", repl_note, text)
    return out, fixed


def repair_formal_types() -> int:
    """Fill empty <type> in formal MusicXML without regenerating from JSON."""
    repaired = 0
    for sid in sorted(FORMAL_IDS):
        for base in (ASSET_XML, SRC_XML):
            path = base / f"{sid}.musicxml"
            if not path.exists():
                continue
            raw = path.read_text(encoding="utf-8")
            if "<type></type>" not in raw and "<type/>" not in raw:
                continue
            new, n = fill_empty_types_in_xml(raw)
            if n:
                path.write_text(new, encoding="utf-8")
                print(f"repaired types {path.relative_to(ROOT)} ({n} notes)")
                repaired += 1
    return repaired


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="Overwrite existing MusicXML")
    ap.add_argument("--id", default="", help="Single song id")
    ap.add_argument(
        "--skip-formal",
        action="store_true",
        default=True,
        help="Never overwrite formal textbook ids (default on)",
    )
    ap.add_argument("--no-skip-formal", action="store_false", dest="skip_formal")
    ap.add_argument(
        "--repair-formal-types",
        action="store_true",
        help="Fill empty <type></type> in formal MusicXML in place",
    )
    args = ap.parse_args()

    ASSET_XML.mkdir(parents=True, exist_ok=True)
    SRC_XML.mkdir(parents=True, exist_ok=True)

    if args.repair_formal_types:
        n = repair_formal_types()
        print(f"done repair-formal-types files_touched={n}")
        if not args.force and not args.id:
            return 0

    json_files = sorted(JSON_DIR.glob("*.json"))
    json_files = [p for p in json_files if p.name != "catalog.json"]
    if args.id:
        json_files = [p for p in json_files if p.stem == args.id]
        if not json_files:
            print(f"No JSON for id={args.id}")
            return 1

    written = 0
    skipped = 0
    for path in json_files:
        sid = path.stem
        # Formal ids are never overwritten from JSON when skip_formal is on.
        if args.skip_formal and sid in FORMAL_IDS:
            print(f"skip formal {sid}")
            skipped += 1
            continue
        if has_musicxml(sid) and not args.force:
            skipped += 1
            print(f"skip existing {sid}")
            continue

        data = json.loads(path.read_text(encoding="utf-8-sig"))
        xml = score_to_musicxml(data)
        for out_dir in (ASSET_XML, SRC_XML):
            out = out_dir / f"{sid}.musicxml"
            out.write_text(xml, encoding="utf-8")
        print(f"wrote {sid}.musicxml")
        written += 1

    print(f"done: wrote={written} skipped={skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
