"""MIDI → crude MusicXML draft for PianoFlow workshop (userImport only).

NEVER use this output as formal / textbook MusicXML.
MIDI loses articulation, true voices, and often staff assignment.

Usage:
  python .\\scripts\\midi_to_musicxml_draft.py --input song.mid --output draft.musicxml
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

STEP_NAMES = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
ALTERS = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]


@dataclass
class NoteEvent:
    start: int
    end: int
    midi: int
    velocity: int


def _read_vlq(data: bytes, i: int) -> tuple[int, int]:
    value = 0
    while True:
        if i >= len(data):
            raise ValueError("truncated VLQ")
        b = data[i]
        i += 1
        value = (value << 7) | (b & 0x7F)
        if b < 0x80:
            return value, i


def _parse_track(data: bytes) -> tuple[list[NoteEvent], int | None, tuple[int, int] | None]:
    """Return note events, optional microseconds-per-quarter, optional (num, den)."""
    i = 0
    abs_tick = 0
    running = None
    active: dict[tuple[int, int], tuple[int, int]] = {}  # (ch, note) -> (start, vel)
    notes: list[NoteEvent] = []
    tempo_us: int | None = None
    time_sig: tuple[int, int] | None = None

    while i < len(data):
        delta, i = _read_vlq(data, i)
        abs_tick += delta
        if i >= len(data):
            break
        status = data[i]
        if status & 0x80:
            i += 1
            running = status
        else:
            if running is None:
                raise ValueError("running status missing")
            status = running

        if status == 0xFF:
            if i >= len(data):
                break
            meta = data[i]
            i += 1
            length, i = _read_vlq(data, i)
            payload = data[i : i + length]
            i += length
            if meta == 0x2F:
                break
            if meta == 0x51 and length == 3:
                tempo_us = (payload[0] << 16) | (payload[1] << 8) | payload[2]
            elif meta == 0x58 and length >= 2:
                time_sig = (payload[0], 2 ** payload[1])
            continue

        if status in (0xF0, 0xF7):
            length, i = _read_vlq(data, i)
            i += length
            continue

        msg = status & 0xF0
        ch = status & 0x0F
        if msg in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
            if i + 1 >= len(data):
                break
            a, b = data[i], data[i + 1]
            i += 2
            if msg == 0x90:
                if b == 0:
                    key = (ch, a)
                    if key in active:
                        start, vel = active.pop(key)
                        notes.append(NoteEvent(start, abs_tick, a, vel))
                else:
                    key = (ch, a)
                    # Retrigger: close prior sounding note before opening a new one.
                    if key in active:
                        start, vel = active.pop(key)
                        notes.append(NoteEvent(start, abs_tick, a, vel))
                    active[key] = (abs_tick, b)
            elif msg == 0x80:
                key = (ch, a)
                if key in active:
                    start, vel = active.pop(key)
                    notes.append(NoteEvent(start, abs_tick, a, vel))
        elif msg in (0xC0, 0xD0):
            i += 1
        else:
            # Unknown — stop track parse conservatively
            break

    # Hang notes to end of track
    for (ch, pitch), (start, vel) in active.items():
        notes.append(NoteEvent(start, max(start + 1, abs_tick), pitch, vel))
    return notes, tempo_us, time_sig


def parse_midi(path: Path) -> tuple[list[NoteEvent], int, int, tuple[int, int]]:
    raw = path.read_bytes()
    if raw[:4] != b"MThd":
        raise ValueError("not a Standard MIDI File (missing MThd)")
    header_len = struct.unpack(">I", raw[4:8])[0]
    if header_len < 6:
        raise ValueError("bad MIDI header length")
    fmt, ntrks, division = struct.unpack(">HHH", raw[8:14])
    if division & 0x8000:
        raise ValueError("SMPTE MIDI timing not supported")
    ppq = division
    i = 8 + header_len
    all_notes: list[NoteEvent] = []
    tempo_us: int | None = None
    time_sig: tuple[int, int] | None = None
    for _ in range(ntrks):
        if raw[i : i + 4] != b"MTrk":
            raise ValueError("missing MTrk chunk")
        tlen = struct.unpack(">I", raw[i + 4 : i + 8])[0]
        track = raw[i + 8 : i + 8 + tlen]
        i += 8 + tlen
        notes, t_us, ts = _parse_track(track)
        all_notes.extend(notes)
        if t_us is not None and tempo_us is None:
            tempo_us = t_us
        if ts is not None and time_sig is None:
            time_sig = ts
    if not all_notes:
        raise ValueError("no note events in MIDI")
    bpm = 120
    if tempo_us and tempo_us > 0:
        bpm = max(30, min(240, int(round(60_000_000 / tempo_us))))
    ts = time_sig or (4, 4)
    all_notes.sort(key=lambda n: (n.start, n.midi))
    _ = fmt  # unused; Type 0/1 both OK
    return all_notes, ppq, bpm, ts


def midi_to_pitch(midi: int) -> tuple[str, int, int]:
    midi = max(21, min(108, midi))
    octave = (midi // 12) - 1
    pc = midi % 12
    return STEP_NAMES[pc], ALTERS[pc], octave


def _emit_staff_voice(
    lines: list[str],
    notes: list[NoteEvent],
    *,
    staff: int,
    m_start: int,
    m_end: int,
) -> None:
    """Emit one staff/voice for a measure, always spanning m_start..m_end."""
    span = m_end - m_start
    if not notes:
        lines.extend(
            [
                "      <note>",
                "        <rest/>",
                f"        <duration>{span}</duration>",
                f"        <voice>{staff}</voice>",
                f"        <staff>{staff}</staff>",
                "      </note>",
            ]
        )
        return

    notes = sorted(notes, key=lambda n: (n.start, n.midi))
    cursor = m_start
    i = 0
    while i < len(notes):
        start = notes[i].start
        chord: list[NoteEvent] = []
        while i < len(notes) and notes[i].start == start:
            chord.append(notes[i])
            i += 1
        next_start = m_end
        if i < len(notes):
            next_start = min(m_end, notes[i].start)
        if start > cursor:
            lines.append(f"      <forward><duration>{start - cursor}</duration></forward>")
        elif start < cursor:
            lines.append(f"      <backup><duration>{cursor - start}</duration></backup>")
        cursor = start
        # Chord duration = min(shortest member, gap to next onset) so overlapping
        # melody under held tones is not dropped by a long cursor advance.
        shortest = max(1, min(n.end - n.start for n in chord))
        gap = max(1, next_start - start)
        dur = max(1, min(shortest, gap, m_end - start))
        for j, n in enumerate(chord):
            step, alter, octave = midi_to_pitch(n.midi)
            lines.append("      <note>")
            if j > 0:
                lines.append("        <chord/>")
            lines.append("        <pitch>")
            lines.append(f"          <step>{step}</step>")
            if alter:
                lines.append(f"          <alter>{alter}</alter>")
            lines.append(f"          <octave>{octave}</octave>")
            lines.append("        </pitch>")
            lines.append(f"        <duration>{dur}</duration>")
            lines.append(f"        <voice>{staff}</voice>")
            lines.append("        <type>quarter</type>")
            lines.append(f"        <staff>{staff}</staff>")
            lines.append("      </note>")
        cursor = start + dur
    if cursor < m_end:
        lines.append(f"      <forward><duration>{m_end - cursor}</duration></forward>")
    elif cursor > m_end:
        # Keep stream on the barline so the following staff backup is exact.
        lines.append(f"      <backup><duration>{cursor - m_end}</duration></backup>")


def write_musicxml(
    notes: list[NoteEvent],
    ppq: int,
    bpm: int,
    time_sig: tuple[int, int],
    out: Path,
    title: str,
) -> None:
    beats, beat_type = time_sig
    # MusicXML divisions: use ppq so durations stay exact when possible.
    divisions = max(1, ppq)
    ticks_per_measure = int(ppq * beats * (4 / beat_type))
    if ticks_per_measure <= 0:
        ticks_per_measure = ppq * 4

    # Quantize end >= start+1
    cleaned: list[NoteEvent] = []
    for n in notes:
        end = n.end if n.end > n.start else n.start + max(1, ppq // 4)
        cleaned.append(NoteEvent(n.start, end, n.midi, n.velocity))

    max_tick = max(n.end for n in cleaned)
    measure_count = max(1, (max_tick + ticks_per_measure - 1) // ticks_per_measure)

    lines: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN"',
        '  "http://www.musicxml.org/dtds/partwise.dtd">',
        '<score-partwise version="3.1">',
        "  <work>",
        f"    <work-title>{_xml(title)}</work-title>",
        "  </work>",
        "  <identification>",
        "    <encoding>",
        "      <software>PianoFlow midi_to_musicxml_draft</software>",
        "      <encoding-description>DRAFT from MIDI — not formal score. "
        "userImport only.</encoding-description>",
        "    </encoding>",
        "  </identification>",
        "  <part-list>",
        '    <score-part id="P1">',
        "      <part-name>Piano (MIDI draft)</part-name>",
        "    </score-part>",
        "  </part-list>",
        '  <part id="P1">',
    ]

    for mi in range(measure_count):
        m_start = mi * ticks_per_measure
        m_end = m_start + ticks_per_measure
        lines.append(f'    <measure number="{mi + 1}">')
        if mi == 0:
            lines.extend(
                [
                    "      <attributes>",
                    f"        <divisions>{divisions}</divisions>",
                    "        <key><fifths>0</fifths></key>",
                    "        <time>",
                    f"          <beats>{beats}</beats>",
                    f"          <beat-type>{beat_type}</beat-type>",
                    "        </time>",
                    "        <staves>2</staves>",
                    '        <clef number="1"><sign>G</sign><line>2</line></clef>',
                    '        <clef number="2"><sign>F</sign><line>4</line></clef>',
                    "      </attributes>",
                    "      <direction placement=\"above\">",
                    "        <direction-type>",
                    f'          <metronome><beat-unit>quarter</beat-unit>'
                    f"<per-minute>{bpm}</per-minute></metronome>",
                    "        </direction-type>",
                    "        <sound tempo=\"{bpm}\"/>".replace("{bpm}", str(bpm)),
                    "      </direction>",
                ]
            )

        # Notes that start in this measure. MusicXML has ONE stream cursor:
        # write RH (staff 1) fully, backup to measure start, then write LH.
        # (Previously per-staff cursors were interleaved without stream backup,
        # which desynchronized LH/RH when re-parsed by musicxml_to_score.)
        in_m = [n for n in cleaned if m_start <= n.start < m_end]
        if not in_m:
            lines.extend(
                [
                    "      <note>",
                    '        <rest measure="yes"/>',
                    f"        <duration>{ticks_per_measure}</duration>",
                    "        <voice>1</voice>",
                    "        <staff>1</staff>",
                    "      </note>",
                ]
            )
            lines.append("    </measure>")
            continue

        rh = [n for n in in_m if n.midi >= 60]
        lh = [n for n in in_m if n.midi < 60]
        _emit_staff_voice(lines, rh, staff=1, m_start=m_start, m_end=m_end)
        lines.append(f"      <backup><duration>{ticks_per_measure}</duration></backup>")
        _emit_staff_voice(lines, lh, staff=2, m_start=m_start, m_end=m_end)

        lines.append("    </measure>")

    lines.extend(["  </part>", "</score-partwise>", ""])
    out.write_text("\n".join(lines), encoding="utf-8")


def _xml(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def write_score_json(
    notes: list[NoteEvent],
    ppq: int,
    bpm: int,
    time_sig: tuple[int, int],
    out: Path,
    *,
    score_id: str,
    title: str,
) -> None:
    """Practice JSON directly from MIDI ticks — avoids MusicXML RH/LH cursor drift."""
    beats, beat_type = time_sig
    out_notes: list[dict] = []
    for n in sorted(notes, key=lambda x: (x.start, x.midi)):
        dur_ticks = max(1, n.end - n.start)
        out_notes.append(
            {
                "midi": int(n.midi),
                "start": round(n.start / float(ppq), 6),
                "duration": round(dur_ticks / float(ppq), 6),
                "hand": "right" if n.midi >= 60 else "left",
            }
        )
    payload = {
        "id": score_id,
        "title": title,
        "bpm": int(bpm),
        "timeSignature": {"num": int(beats), "den": int(beat_type)},
        "keySignature": 0,
        "notes": out_notes,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="MIDI → MusicXML draft (NOT formal; workshop userImport only)"
    )
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument(
        "--json-output",
        type=Path,
        default=None,
        help="Also write PianoFlow practice JSON directly from MIDI (preferred for playback)",
    )
    ap.add_argument("--id", default="", help="Score id for --json-output")
    ap.add_argument("--title", default="")
    args = ap.parse_args()
    if not args.input.is_file():
        print(f"[PianoFlow/midi-draft] missing input: {args.input}", file=sys.stderr)
        return 1
    try:
        notes, ppq, bpm, ts = parse_midi(args.input)
    except Exception as e:
        print(f"[PianoFlow/midi-draft] parse failed: {e}", file=sys.stderr)
        return 1
    title = args.title.strip() or args.input.stem
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_musicxml(notes, ppq, bpm, ts, args.output, title)
    print(
        f"[PianoFlow/midi-draft] wrote {args.output} notes={len(notes)} "
        f"bpm={bpm} ppq={ppq} DRAFT_ONLY"
    )
    if args.json_output is not None:
        sid = (args.id or args.json_output.stem).strip()
        write_score_json(
            notes, ppq, bpm, ts, args.json_output, score_id=sid, title=title
        )
        print(
            f"[PianoFlow/midi-draft] wrote {args.json_output} notes={len(notes)} "
            f"DIRECT_FROM_MIDI (playback timing)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
