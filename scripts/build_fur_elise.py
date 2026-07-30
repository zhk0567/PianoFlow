#!/usr/bin/env python3
"""Build Fur Elise (WoO 59) MusicXML assets for PianoFlow.

CRITICAL — score accuracy is the #1 priority for shipped formal scores.
Do NOT convert from MIDI (music21 / converter.parse on .mid). MIDI loses
voices, staves, accidental spelling, and beams; Verovio then shows colliding
noteheads and redundant accidentals. That path is forbidden for formal scores.

Canonical musical source for this pipeline:
  Mutopia Project / Stelios Samelis LilyPond edition (Public Domain),
  matching the user's PDF (Breitkopf & Härtel 1888 lineage).
  Engraved MusicXML: MuseScore encoding of the same edition (A minor, 3/8,
  Poco moto, grand staff) — single Piano part with staff 1/2.

Source files under third_party/scores_musicxml/_omr_work/fur_elise/:
  - fur_Elise_WoO59.ly / .mid  (Mutopia originals; MIDI is reference only)
  - fur_Elise_WoO59.musicxml   (notation-accurate PianoStaff MusicXML)
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
WORK = REPO / "third_party" / "scores_musicxml" / "_omr_work" / "fur_elise"
SRC_CANONICAL = WORK / "fur_Elise_WoO59.musicxml"
OUT_ID = "fur_elise_woo59"
SRC_XML = REPO / "third_party" / "scores_musicxml" / f"{OUT_ID}.musicxml"
ASSET_XML = REPO / "assets" / "scores" / "musicxml" / f"{OUT_ID}.musicxml"

TITLE = "Fur Elise"
SUBTITLE = "Clavierstuck in A Minor - WoO 59"
COMPOSER = "Ludwig van Beethoven"


def _strip_ns(root: ET.Element) -> None:
    for el in root.iter():
        if "}" in el.tag:
            el.tag = el.tag.split("}", 1)[1]


def _ensure_child(parent: ET.Element, tag: str, *, text: str | None = None, index: int = 0) -> ET.Element:
    for c in parent:
        if c.tag == tag:
            if text is not None:
                c.text = text
            return c
    el = ET.Element(tag)
    if text is not None:
        el.text = text
    parent.insert(index, el)
    return el


def _patch_metadata(root: ET.Element) -> None:
    work = root.find("work")
    if work is None:
        work = ET.Element("work")
        root.insert(0, work)
    _ensure_child(work, "work-title", text=TITLE)
    _ensure_child(work, "work-number", text="WoO 59")

    mt = root.find("movement-title")
    if mt is None:
        # After <work>
        idx = 1 if root.find("work") is not None else 0
        mt = ET.Element("movement-title")
        root.insert(idx, mt)
    mt.text = SUBTITLE

    ident = root.find("identification")
    if ident is None:
        ident = ET.Element("identification")
        root.insert(2, ident)

    creator = None
    for c in ident.findall("creator"):
        if c.get("type") == "composer":
            creator = c
            break
    if creator is None:
        creator = ET.Element("creator", {"type": "composer"})
        ident.insert(0, creator)
    creator.text = COMPOSER

    rights = ident.find("rights")
    if rights is None:
        rights = ET.Element("rights")
        ident.append(rights)
    rights.text = "Public Domain"

    # Drop page credits that may carry non-English glyphs / extra layout text.
    for credit in list(root.findall("credit")):
        root.remove(credit)

    # Empty part name so Verovio does not draw "Piano" on the staff.
    for sp in root.findall("./part-list/score-part"):
        pn = sp.find("part-name")
        if pn is not None:
            pn.text = ""
        pa = sp.find("part-abbreviation")
        if pa is not None:
            pa.text = ""


def _strip_redundant_accidentals(root: ET.Element) -> int:
    """Remove repeated accidentals on the same pitch within one measure."""
    removed = 0
    for part in root.findall("part"):
        for measure in part.findall("measure"):
            seen: set[tuple[str, str, str]] = set()
            for note in measure.findall("note"):
                pitch = note.find("pitch")
                if pitch is None:
                    continue
                step = pitch.findtext("step") or ""
                octave = pitch.findtext("octave") or ""
                alter = pitch.findtext("alter") or "0"
                key = (step, octave, alter)
                acc = note.find("accidental")
                if acc is None:
                    continue
                if key in seen:
                    note.remove(acc)
                    removed += 1
                else:
                    seen.add(key)
    return removed


def _normalize_tempo(root: ET.Element) -> None:
    """Keep Poco moto + quarter=72 (Mutopia/PDF). Drop MuseScore rit. numbers."""
    for part in root.findall("part"):
        for measure in part.findall("measure"):
            for direction in list(measure.findall("direction")):
                words = (direction.findtext(".//words") or "").strip()
                sound = direction.find("sound")
                tempo = sound.get("tempo") if sound is not None else None
                # Drop trailing ritardando text tempos ("66", "60", "48").
                if words.isdigit() and tempo is not None:
                    measure.remove(direction)
                    continue
                if words.lower().startswith("poco moto"):
                    # Ensure practice timeline uses 72, matching \\tempo 4 = 72.
                    if sound is None:
                        sound = ET.SubElement(direction, "sound")
                    sound.set("tempo", "72")
                    # Prefer an explicit metronome for exporters that ignore sound@.
                    dtype = direction.find("direction-type")
                    if dtype is not None and dtype.find("metronome") is None:
                        metro = ET.Element("metronome")
                        bu = ET.SubElement(metro, "beat-unit")
                        bu.text = "quarter"
                        pm = ET.SubElement(metro, "per-minute")
                        pm.text = "72"
                        dtype.append(metro)


def _validate(root: ET.Element) -> None:
    parts = root.findall("part")
    if len(parts) != 1:
        raise SystemExit(f"expected 1 piano part, found {len(parts)}")
    part = parts[0]
    measures = part.findall("measure")
    if not measures:
        raise SystemExit("no measures")
    attrs = measures[0].find("attributes")
    if attrs is None:
        raise SystemExit("measure 1 missing attributes")
    staves = attrs.findtext("staves")
    if staves != "2":
        raise SystemExit(f"expected staves=2, got {staves!r}")
    fifths = attrs.findtext("key/fifths")
    beats = attrs.findtext("time/beats")
    beat_type = attrs.findtext("time/beat-type")
    if fifths != "0" or beats != "3" or beat_type != "8":
        raise SystemExit(f"expected a minor 3/8, got fifths={fifths} {beats}/{beat_type}")

    # Opening motif after anacrusis: E D# E B D C on staff 1 (Mutopia bar 1).
    m1 = next(m for m in measures if m.get("number") == "1")
    pitches: list[str] = []
    for note in m1.findall("note"):
        if note.find("rest") is not None:
            continue
        if (note.findtext("staff") or "1") != "1":
            continue
        if note.find("chord") is not None:
            continue
        step = note.findtext("pitch/step")
        alter = note.findtext("pitch/alter") or ""
        octv = note.findtext("pitch/octave")
        pitches.append(f"{step}{alter}{octv}")
    expected = ["E5", "D15", "E5", "B4", "D5", "C5"]
    if pitches[:6] != expected:
        raise SystemExit(f"measure 1 RH motif mismatch: {pitches[:8]} != {expected}")


def main() -> int:
    if not SRC_CANONICAL.exists():
        print(f"Missing canonical MusicXML: {SRC_CANONICAL}", file=sys.stderr)
        print(
            "Place a notation-accurate PianoStaff MusicXML there "
            "(not MIDI-derived).",
            file=sys.stderr,
        )
        return 1

    tree = ET.parse(SRC_CANONICAL)
    root = tree.getroot()
    _strip_ns(root)
    _patch_metadata(root)
    _normalize_tempo(root)
    removed = _strip_redundant_accidentals(root)
    _validate(root)

    # Pretty-ish serialization without requiring Python 3.9 indent everywhere.
    try:
        ET.indent(tree, space="  ")
    except AttributeError:
        pass

    SRC_XML.parent.mkdir(parents=True, exist_ok=True)
    ASSET_XML.parent.mkdir(parents=True, exist_ok=True)
    tree.write(SRC_XML, encoding="utf-8", xml_declaration=True)
    shutil.copy2(SRC_XML, ASSET_XML)
    print(f"wrote {SRC_XML}")
    print(f"wrote {ASSET_XML}")
    print(f"stripped {removed} redundant same-measure accidentals")
    print("validated: 1 part / 2 staves / a minor 3/8 / opening motif OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
