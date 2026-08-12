# -*- coding: utf-8 -*-
"""Minimal Jianpu (numbered notation) → MusicXML for PianoFlow omrDraft import.

Pitch: digit 1-7 in key tonic; '.' above = +octave (we use '^'), below = '_' .
Duration tokens (beat units in 4/4 where 1.0 = quarter):
  n      → 1 beat
  n-     → extend previous by 1 (handled as tied duration in token stream)
  underlines: we encode eighth as 'n/' and sixteenth as 'n//'

This is intentionally small — for batch PDF jianpu that Audiveris cannot read.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable

DEGREE = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}  # semitones from tonic in major


def tonic_midi(key: str) -> int:
    """key like 'C','G','F','Eb' → MIDI of middle tonic (octave 4)."""
    table = {
        "C": 60,
        "G": 67,
        "F": 65,
        "D": 62,
        "A": 69,
        "E": 64,
        "B": 71,
        "Bb": 58,
        "Eb": 63,
        "Ab": 56,
        "Db": 61,
        "Gb": 54,
        "F#": 66,
    }
    if key not in table:
        raise ValueError(f"unsupported key {key}")
    return table[key]


def pitch_to_step_alter_octave(midi: int) -> tuple[str, int, int]:
    pc = midi % 12
    octave = midi // 12 - 1
    mapping = {
        0: ("C", 0),
        1: ("C", 1),
        2: ("D", 0),
        3: ("D", 1),
        4: ("E", 0),
        5: ("F", 0),
        6: ("F", 1),
        7: ("G", 0),
        8: ("G", 1),
        9: ("A", 0),
        10: ("A", 1),
        11: ("B", 0),
    }
    step, alter = mapping[pc]
    return step, alter, octave


def parse_token(tok: str, key_midi: int) -> tuple[int | None, float]:
    """Return (midi_or_None_for_rest, duration_in_quarters)."""
    tok = tok.strip()
    if not tok:
        raise ValueError("empty token")
    # duration modifiers
    dur = 1.0
    if tok.endswith("//"):
        dur = 0.25
        tok = tok[:-2]
    elif tok.endswith("/"):
        dur = 0.5
        tok = tok[:-1]
    # extension dash alone means rest? handled by caller as '-' attach
    if tok == "0" or tok == "r":
        return None, dur
    sharp = tok.startswith("#")
    flat = tok.startswith("b") and len(tok) > 1 and tok[1].isdigit()
    if sharp:
        tok = tok[1:]
    if flat:
        tok = tok[1:]
    oct_up = tok.count("^")
    oct_dn = tok.count("_")
    core = tok.replace("^", "").replace("_", "")
    if not core.isdigit():
        raise ValueError(f"bad token {tok}")
    deg = int(core)
    if deg < 1 or deg > 7:
        raise ValueError(f"degree {deg}")
    midi = key_midi + DEGREE[deg] + 12 * (oct_up - oct_dn)
    if sharp:
        midi += 1
    if flat:
        midi -= 1
    return midi, dur


def expand_measure(tokens: Iterable[str], key_midi: int) -> list[tuple[int | None, float]]:
    """Tokens may include '-' which extends previous note by 1 quarter."""
    out: list[tuple[int | None, float]] = []
    for raw in tokens:
        t = raw.strip()
        if not t:
            continue
        if t == "-":
            if not out:
                raise ValueError("orphan '-'")
            m, d = out[-1]
            out[-1] = (m, d + 1.0)
            continue
        # multi-extend like '--' not used; use repeated '-'
        midi, dur = parse_token(t, key_midi)
        out.append((midi, dur))
    return out


def dur_to_type(quarters: float) -> tuple[str, int, bool]:
    """type name, dots, is_dotted approximation."""
    table = [
        (4.0, "whole", 0),
        (3.0, "half", 1),
        (2.0, "half", 0),
        (1.5, "quarter", 1),
        (1.0, "quarter", 0),
        (0.75, "eighth", 1),
        (0.5, "eighth", 0),
        (0.375, "16th", 1),
        (0.25, "16th", 0),
    ]
    for q, typ, dots in table:
        if abs(quarters - q) < 1e-6:
            return typ, dots, dots > 0
    # fallback: nearest
    best = min(table, key=lambda x: abs(x[0] - quarters))
    return best[1], best[2], best[2] > 0


def build_musicxml(
    *,
    title: str,
    artist: str,
    key: str,
    divisions: int = 4,
    beats: int = 4,
    beat_type: int = 4,
    tempo: int = 120,
    rh_measures: list[list[str]],
    lh_measures: list[list[str]] | None = None,
) -> str:
    key_midi = tonic_midi(key)
    if lh_measures is None:
        lh_measures = [[] for _ in rh_measures]
    if len(lh_measures) != len(rh_measures):
        raise ValueError("RH/LH measure count mismatch")

    score = ET.Element("score-partwise", version="3.1")
    work = ET.SubElement(score, "work")
    ET.SubElement(work, "work-title").text = title
    ident = ET.SubElement(score, "identification")
    ET.SubElement(ident, "creator", type="composer").text = artist
    encoding = ET.SubElement(ident, "encoding")
    ET.SubElement(encoding, "software").text = "PianoFlow jianpu_to_musicxml"
    ET.SubElement(encoding, "encoding-description").text = (
        "Transcribed from jianpu PDF (not Audiveris). omrDraft quality."
    )

    part_list = ET.SubElement(score, "part-list")
    sp = ET.SubElement(part_list, "score-part", id="P1")
    ET.SubElement(sp, "part-name").text = "Piano"

    part = ET.SubElement(score, "part", id="P1")

    fifths_map = {
        "C": 0,
        "G": 1,
        "D": 2,
        "A": 3,
        "E": 4,
        "B": 5,
        "F#": 6,
        "F": -1,
        "Bb": -2,
        "Eb": -3,
        "Ab": -4,
        "Db": -5,
        "Gb": -6,
    }
    fifths = fifths_map.get(key, 0)

    for mi, (rh_toks, lh_toks) in enumerate(zip(rh_measures, lh_measures), start=1):
        measure = ET.SubElement(part, "measure", number=str(mi))
        if mi == 1:
            attr = ET.SubElement(measure, "attributes")
            ET.SubElement(attr, "divisions").text = str(divisions)
            key_el = ET.SubElement(attr, "key")
            ET.SubElement(key_el, "fifths").text = str(fifths)
            time_el = ET.SubElement(attr, "time")
            ET.SubElement(time_el, "beats").text = str(beats)
            ET.SubElement(time_el, "beat-type").text = str(beat_type)
            staves = ET.SubElement(attr, "staves")
            staves.text = "2"
            for clef_num, sign, line in ((1, "G", 2), (2, "F", 4)):
                clef = ET.SubElement(attr, "clef", number=str(clef_num))
                ET.SubElement(clef, "sign").text = sign
                ET.SubElement(clef, "line").text = str(line)
            direction = ET.SubElement(measure, "direction", placement="above")
            dtype = ET.SubElement(direction, "direction-type")
            metro = ET.SubElement(dtype, "metronome")
            ET.SubElement(metro, "beat-unit").text = "quarter"
            ET.SubElement(metro, "per-minute").text = str(tempo)
            sound = ET.SubElement(direction, "sound", tempo=str(tempo))

        rh = expand_measure(rh_toks, key_midi)
        lh = expand_measure(lh_toks, key_midi) if lh_toks else []
        # pad empty LH with full-measure rest
        if not lh:
            lh = [(None, float(beats))]

        def emit_voice(events: list[tuple[int | None, float]], staff: int, voice: int) -> None:
            for midi, dur_q in events:
                dur = int(round(dur_q * divisions))
                if dur <= 0:
                    continue
                note = ET.SubElement(measure, "note")
                if midi is None:
                    ET.SubElement(note, "rest")
                else:
                    step, alter, octave = pitch_to_step_alter_octave(midi)
                    pitch = ET.SubElement(note, "pitch")
                    ET.SubElement(pitch, "step").text = step
                    if alter:
                        ET.SubElement(pitch, "alter").text = str(alter)
                    ET.SubElement(pitch, "octave").text = str(octave)
                ET.SubElement(note, "duration").text = str(dur)
                ET.SubElement(note, "voice").text = str(voice)
                typ, dots, _ = dur_to_type(dur_q)
                ET.SubElement(note, "type").text = typ
                for _ in range(dots):
                    ET.SubElement(note, "dot")
                ET.SubElement(note, "staff").text = str(staff)

        emit_voice(rh, staff=1, voice=1)
        backup = ET.SubElement(measure, "backup")
        ET.SubElement(backup, "duration").text = str(int(beats * divisions))
        emit_voice(lh, staff=2, voice=2)

    # pretty serialize
    rough = ET.tostring(score, encoding="utf-8")
    import xml.dom.minidom as minidom

    pretty = minidom.parseString(rough).toprettyxml(indent="  ", encoding="utf-8")
    # minidom adds xml decl
    text = pretty.decode("utf-8")
    if not text.startswith("<?xml"):
        text = '<?xml version="1.0" encoding="UTF-8"?>\n' + text
    return text


def write(path: Path, xml: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(xml, encoding="utf-8")
