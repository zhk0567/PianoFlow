#!/usr/bin/env python3
"""Emit Ian Cantor / Cantorion Easy Piano Canon in D as MusicXML.

Source PDF: Canon in D, Arranged by Ian Cantor
Licence: Creative Commons Attribution-Share Alike 2.0 (www.cantorion.org)
Engraving: LilyPond 2.11.38

This is a note-accurate transcription of that 40-bar easy piano arrangement
(not a generic Pachelbel reduction).
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_ASSET = ROOT / "assets" / "scores" / "musicxml" / "pachelbel_canon_d.musicxml"
OUT_SRC = ROOT / "third_party" / "scores_musicxml" / "pachelbel_canon_d.musicxml"

# Ground bass cycle (half notes): D3 A2 | B2 F#2 | G2 D2 | G2 A2
# Continues through m39; m40 is D3+D2 whole-note octave with fermata.
BASS_CYCLE = [50, 45, 47, 42, 43, 38, 43, 45]  # MIDI


def midi_to_pitch(midi: int) -> tuple[str, int, int]:
    steps = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    alters = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]
    pc = midi % 12
    octave = midi // 12 - 1
    return steps[pc], alters[pc], octave


def note_xml(
    midi: int,
    *,
    duration: int,
    typ: str,
    staff: int,
    voice: int,
    chord: bool = False,
    dot: bool = False,
    accidental: str | None = None,
    cautionary: bool = False,
    fermata: bool = False,
) -> str:
    step, alter, octave = midi_to_pitch(midi)
    # D major key signature already has F# and C# — do not print redundant
    # accidentals (they make Verovio look unlike the LilyPond PDF).
    key_alters = {6: 1, 1: 1}  # F#, C# pitch classes
    pc = midi % 12
    acc = ""
    if accidental:
        paren = ' parentheses="yes"' if cautionary else ""
        acc = f"<accidental{paren}>{accidental}</accidental>"
    elif alter and pc not in key_alters:
        acc = f"<accidental>{'sharp' if alter > 0 else 'flat'}</accidental>"
    alter_el = f"<alter>{alter}</alter>" if alter else ""
    chord_el = "<chord/>" if chord else ""
    dot_el = "<dot/>" if dot else ""
    fermata_el = '<notations><fermata type="upright"/></notations>' if fermata else ""
    return f"""
      <note>
        {chord_el}
        <pitch><step>{step}</step>{alter_el}<octave>{octave}</octave></pitch>
        <duration>{duration}</duration>
        <voice>{voice}</voice>
        <type>{typ}</type>{dot_el}
        {acc}
        <staff>{staff}</staff>
        {fermata_el}
      </note>"""


def rest_xml(duration: int, typ: str, staff: int, voice: int) -> str:
    return f"""
      <note>
        <rest/>
        <duration>{duration}</duration>
        <voice>{voice}</voice>
        <type>{typ}</type>
        <staff>{staff}</staff>
      </note>"""


def measure_open(n: int, *, new_system: bool = False) -> str:
    print_el = ""
    if new_system:
        print_el = '<print new-system="yes"/>'
    return f'<measure number="{n}">{print_el}'


# Right-hand: (midi, duration_divs, type, dot?, accidental?, cautionary?)
# divisions = 2 → quarter=2, half=4, whole=8, eighth=1, dotted-quarter=3, dotted-half=6
# Transcribed measure-by-measure from Ian Cantor / Cantorion Easy Piano PDF.
RH: dict[int, list[tuple]] = {
    1: [],
    2: [],
    3: [],
    4: [],
    # System 2 — half-note melody
    5: [(66, 4, "half", False, None, False), (64, 4, "half", False, None, False)],
    6: [(62, 4, "half", False, None, False), (61, 4, "half", False, None, False)],
    7: [(59, 4, "half", False, None, False), (57, 4, "half", False, None, False)],
    8: [(59, 4, "half", False, None, False), (61, 4, "half", False, None, False)],
    # System 3
    9: [(69, 4, "half", False, None, False), (67, 4, "half", False, None, False)],
    10: [(66, 4, "half", False, None, False), (64, 4, "half", False, None, False)],
    11: [(62, 4, "half", False, None, False), (61, 4, "half", False, None, False)],
    12: [(62, 4, "half", False, None, False), (64, 4, "half", False, None, False)],
    # System 4 — quarters
    13: [(74, 2, "quarter", False, None, False), (73, 2, "quarter", False, None, False),
         (74, 2, "quarter", False, None, False), (69, 2, "quarter", False, None, False)],
    14: [(71, 2, "quarter", False, None, False), (69, 2, "quarter", False, None, False),
         (67, 2, "quarter", False, None, False), (66, 2, "quarter", False, None, False)],
    15: [(67, 2, "quarter", False, None, False), (66, 2, "quarter", False, None, False),
         (64, 2, "quarter", False, None, False), (62, 2, "quarter", False, None, False)],
    16: [(64, 2, "quarter", False, None, False), (66, 2, "quarter", False, None, False),
         (67, 2, "quarter", False, None, False), (69, 2, "quarter", False, None, False)],
    # System 5
    17: [(66, 2, "quarter", False, None, False), (64, 2, "quarter", False, None, False),
         (62, 2, "quarter", False, None, False), (64, 2, "quarter", False, None, False)],
    18: [(66, 2, "quarter", False, None, False), (67, 2, "quarter", False, None, False),
         (69, 2, "quarter", False, None, False), (67, 2, "quarter", False, None, False)],
    19: [(66, 2, "quarter", False, None, False), (64, 2, "quarter", False, None, False),
         (62, 2, "quarter", False, None, False), (61, 2, "quarter", False, None, False)],
    20: [(62, 6, "half", True, None, False), (67, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False)],
    # Page 2 — eighths
    21: [(78, 1, "eighth", False, None, False), (76, 1, "eighth", False, None, False),
         (74, 1, "eighth", False, None, False), (73, 1, "eighth", False, None, False),
         (74, 1, "eighth", False, None, False), (71, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False), (67, 1, "eighth", False, None, False)],
    22: [(66, 1, "eighth", False, None, False), (67, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False), (71, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False), (67, 1, "eighth", False, None, False),
         (66, 1, "eighth", False, None, False), (64, 1, "eighth", False, None, False)],
    23: [(62, 1, "eighth", False, None, False), (64, 1, "eighth", False, None, False),
         (66, 1, "eighth", False, None, False), (67, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False), (71, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False), (67, 1, "eighth", False, None, False)],
    24: [(66, 1, "eighth", False, None, False), (67, 1, "eighth", False, None, False),
         (69, 1, "eighth", False, None, False), (71, 1, "eighth", False, None, False),
         (69, 4, "half", False, None, False)],
    # Climax
    25: [(74, 3, "quarter", True, None, False), (76, 1, "eighth", False, None, False),
         (78, 2, "quarter", False, None, False), (79, 2, "quarter", False, None, False)],
    26: [(69, 3, "quarter", True, None, False), (71, 1, "eighth", False, None, False),
         (73, 2, "quarter", False, None, False), (74, 2, "quarter", False, None, False)],
    27: [(71, 1, "eighth", False, None, False), (73, 1, "eighth", False, None, False),
         (74, 1, "eighth", False, None, False), (76, 1, "eighth", False, None, False),
         (74, 1, "eighth", False, None, False), (73, 1, "eighth", False, None, False),
         (71, 1, "eighth", False, None, False), (69, 1, "eighth", False, None, False)],
    28: [(67, 4, "half", False, None, False), (66, 4, "half", False, "sharp", True)],
    29: [(69, 4, "half", False, None, False), (69, 1, "eighth", False, None, False),
         (67, 1, "eighth", False, None, False), (66, 1, "eighth", False, None, False),
         (64, 1, "eighth", False, None, False)],
    30: [(62, 3, "quarter", True, None, False), (64, 1, "eighth", False, None, False),
         (66, 4, "half", False, None, False)],
    31: [(67, 4, "half", False, None, False), (69, 4, "half", False, None, False)],
    32: [(71, 4, "half", False, None, False), (69, 4, "half", False, None, False)],
    # Closing half-note sequence (mirrors opening motif an octave up / variant)
    33: [(78, 4, "half", False, None, False), (76, 4, "half", False, None, False)],
    34: [(74, 4, "half", False, None, False), (73, 4, "half", False, None, False)],
    35: [(71, 4, "half", False, None, False), (69, 4, "half", False, None, False)],
    36: [(71, 4, "half", False, None, False), (73, 4, "half", False, None, False)],
    37: [(74, 4, "half", False, None, False), (69, 4, "half", False, None, False)],
    38: [(71, 4, "half", False, None, False), (66, 4, "half", False, None, False)],
    39: [(67, 4, "half", False, None, False), (69, 4, "half", False, None, False)],
    40: [(74, 8, "whole", False, None, False)],
}


def bass_for_measure(m: int) -> list[int]:
    i = (m - 1) % 4
    return [BASS_CYCLE[i * 2], BASS_CYCLE[i * 2 + 1]]


# Header block matching Cantorion PDF page 1–2 credits (English, as printed).
SCORE_HEADER = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work>
    <work-title>Canon in D</work-title>
  </work>
  <identification>
    <creator type="composer">J. Pachelbel (1653 - 1706)</creator>
    <creator type="arranger">Ian Cantor</creator>
    <rights>Licensed under the Creative Commons Attribution-Share Alike 2.0 License by www.cantorion.org</rights>
    <encoding>
      <software>PianoFlow transcription of Cantorion Easy Piano PDF</software>
      <software>LilyPond 2.11.38</software>
      <encoding-description>Note-accurate Easy Piano arrangement; CC-BY-SA 2.0 attribution required. Original engraving by LilyPond — www.lilypond.org</encoding-description>
    </encoding>
  </identification>
  <credit page="1">
    <credit-type>title</credit-type>
    <credit-words default-x="597" default-y="1624" justify="center" valign="top" font-size="22">Canon in D</credit-words>
  </credit>
  <credit page="1">
    <credit-type>composer</credit-type>
    <credit-words default-x="1122" default-y="1524" justify="right" valign="top" font-size="10">J. Pachelbel (1653 - 1706)</credit-words>
  </credit>
  <credit page="1">
    <credit-type>arranger</credit-type>
    <credit-words default-x="1122" default-y="1474" justify="right" valign="top" font-size="10">Arranged by Ian Cantor</credit-words>
  </credit>
  <credit page="1">
    <credit-type>rights</credit-type>
    <credit-words default-x="597" default-y="70" justify="center" valign="bottom" font-size="8">Licensed under the Creative Commons Attribution-Share Alike 2.0 License by www.cantorion.org</credit-words>
  </credit>
  <part-list>
    <score-part id="P1"><part-name print-object="no">Piano</part-name></score-part>
  </part-list>
  <part id="P1">
"""



def build_fixed() -> str:
    """Emit MusicXML matching Ian Cantor Easy Piano PDF (note content)."""
    chunks: list[str] = []
    chunks.append(SCORE_HEADER)
    new_systems = {1, 5, 9, 13, 17, 21, 25, 29, 33, 37}
    dyn = {
        1: "p",
        13: "mp",
        21: "mf",
        25: "f",
        29: "mf",
        33: "mp",
        37: "p",
    }
    for m in range(1, 41):
        chunks.append(f'<measure number="{m}">')
        if m in new_systems and m != 1:
            chunks.append('<print new-system="yes"/>')
        if m == 1:
            chunks.append(
                """
      <attributes>
        <divisions>2</divisions>
        <key><fifths>2</fifths></key>
        <time symbol="common"><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above">
        <direction-type><words>Andante</words></direction-type>
        <sound tempo="72"/>
      </direction>
"""
            )
        if m in dyn:
            d = dyn[m]
            chunks.append(
                f"""
      <direction placement="below">
        <direction-type><dynamics><{d}/></dynamics></direction-type>
        <staff>1</staff>
      </direction>
"""
            )
        if m == 39:
            chunks.append(
                '<direction placement="above"><direction-type><words>rit.</words></direction-type><staff>1</staff></direction>'
            )

        rh = RH[m]
        if not rh:
            chunks.append(rest_xml(8, "whole", 1, 1))
        else:
            for midi, dur, typ, dot, acc, cautionary in rh:
                chunks.append(
                    note_xml(
                        midi,
                        duration=dur,
                        typ=typ,
                        staff=1,
                        voice=1,
                        dot=dot,
                        accidental=acc,
                        cautionary=cautionary,
                        fermata=(m == 40),
                    )
                )

        chunks.append("<backup><duration>8</duration></backup>")
        if m == 40:
            chunks.append(
                note_xml(50, duration=8, typ="whole", staff=2, voice=2, fermata=True)
            )
            chunks.append(
                note_xml(38, duration=8, typ="whole", staff=2, voice=2, chord=True)
            )
            chunks.append(
                '<barline location="right"><bar-style>light-heavy</bar-style></barline>'
            )
        else:
            for midi in bass_for_measure(m):
                chunks.append(
                    note_xml(midi, duration=4, typ="half", staff=2, voice=2)
                )
        chunks.append("</measure>\n")

    chunks.append("</part></score-partwise>\n")
    return "".join(chunks)


def main() -> None:
    xml = build_fixed()
    OUT_ASSET.parent.mkdir(parents=True, exist_ok=True)
    OUT_SRC.parent.mkdir(parents=True, exist_ok=True)
    OUT_ASSET.write_text(xml, encoding="utf-8")
    OUT_SRC.write_text(xml, encoding="utf-8")
    print(f"wrote {OUT_ASSET}")
    print(f"wrote {OUT_SRC}")


if __name__ == "__main__":
    main()
