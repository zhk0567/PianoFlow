#!/usr/bin/env python3
"""Encode Megalovania MusicXML from the user PDF (notation, NOT MIDI).

CRITICAL — formal-score accuracy is #1. Do NOT use music21 MIDI→MusicXML.

Source PDF:
  third_party/scores_musicxml/_omr_work/megalovania/source.pdf
  Toby Fox · ♩=120 · D minor · 4/4 · PianoStaff · both clefs 8vb · 4 pages ~mm1–71

Helpers take WRITTEN MIDI (PDF staff). Emitted <pitch> is SOUNDING
(written + 12*CLEF_OCTAVE_CHANGE) with clef-octave-change=-1 so Verovio
matches the PDF 8vb look. musicxml_to_score must NOT re-apply the clef
octave (would double-transpose vs the staff).

Page-1 (mm1–15): bar crops. Pages 2–4 (mm16–71): system crops — RH riff /
sustained bridge / riff return / Dm chord cells. Dense mm45–61 voicing may
still differ slightly from the PDF (README_SOURCE.txt).
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
WORK = REPO / "third_party" / "scores_musicxml" / "_omr_work" / "megalovania"
OUT_CANONICAL = WORK / "megalovania_piano.musicxml"

DIV = 4  # quarter=4, eighth=2, 16th=1
TITLE = "Megalovania"
COMPOSER = "Toby Fox"
BPM = 120
# Both piano clefs are 8vb. Verovio treats MusicXML pitch as sounding and
# shifts noteheads up for clef-octave-change=-1 (PDF written position).
CLEF_OCTAVE_CHANGE = -1


def pitch_name(midi: int) -> tuple[str, int, int]:
    """MIDI → (step, alter, octave). Prefer flats in this D-minor score."""
    flat_pref = {1: ("D", -1), 3: ("E", -1), 6: ("G", -1), 8: ("A", -1), 10: ("B", -1)}
    steps = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"]
    alters = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0]
    pc = midi % 12
    octave = midi // 12 - 1
    if pc in flat_pref:
        step, alter = flat_pref[pc]
    else:
        step, alter = steps[pc], alters[pc]
    return step, alter, octave


def note(
    midi: int,
    dur: int,
    typ: str,
    *,
    staff: int,
    voice: int = 1,
    chord: bool = False,
    accidental: str | None = None,
    beam: str | None = None,
    dot: bool = False,
) -> str:
    """[midi] is WRITTEN (PDF staff). Emitted <pitch> is sounding for Verovio."""
    sounding = midi + 12 * CLEF_OCTAVE_CHANGE
    step, alter, octave = pitch_name(sounding)
    key_flat_pcs = {10}  # Bb in signature
    pc = midi % 12
    acc = ""
    if accidental:
        acc = f"<accidental>{accidental}</accidental>"
    elif alter == -1 and pc not in key_flat_pcs:
        acc = "<accidental>flat</accidental>"
    elif alter == 1:
        acc = "<accidental>sharp</accidental>"
    elif alter == 0 and pc == 11:
        acc = "<accidental>natural</accidental>"
    alter_el = f"<alter>{alter}</alter>" if alter else ""
    chord_el = "<chord/>" if chord else ""
    beam_el = f'<beam number="1">{beam}</beam>' if beam else ""
    dot_el = "<dot/>" if dot else ""
    return f"""
      <note>
        {chord_el}
        <pitch><step>{step}</step>{alter_el}<octave>{octave}</octave></pitch>
        <duration>{dur}</duration>
        <voice>{voice}</voice>
        <type>{typ}</type>
        {dot_el}
        {acc}
        {beam_el}
        <staff>{staff}</staff>
      </note>"""


def rest(dur: int, typ: str, staff: int, voice: int = 1) -> str:
    return f"""
      <note>
        <rest/>
        <duration>{dur}</duration>
        <voice>{voice}</voice>
        <type>{typ}</type>
        <staff>{staff}</staff>
      </note>"""


def backup(dur: int) -> str:
    return f"<backup><duration>{dur}</duration></backup>"


def riff_rh(start: int, *, natural_start: bool = False) -> str:
    """Iconic opening riff (WRITTEN pitches).

    Rhythm verified from PDF bar crops:
      16 16 8rest | 8 8rest | 8 16 16 | 16 16 16 16
      start,start, — | D5, — | A, Ab, G | F, D, F, G
    Only the first two 16ths change (D/C/Bn/Bb); leap is always written D5.
    """
    acc0 = "natural" if natural_start else None
    return "".join(
        [
            note(start, 1, "16th", staff=1, beam="begin", accidental=acc0),
            note(start, 1, "16th", staff=1, beam="end", accidental=acc0),
            rest(2, "eighth", 1),
            note(74, 2, "eighth", staff=1),  # D5
            rest(2, "eighth", 1),
            note(69, 2, "eighth", staff=1),  # A4
            note(68, 1, "16th", staff=1, beam="begin", accidental="flat"),  # Ab4
            note(67, 1, "16th", staff=1, beam="end"),  # G4
            note(65, 1, "16th", staff=1, beam="begin"),  # F4
            note(62, 1, "16th", staff=1, beam="continue"),  # D4
            note(65, 1, "16th", staff=1, beam="continue"),  # F4
            note(67, 1, "16th", staff=1, beam="end"),  # G4
        ]
    )


def bass_ostinato(root: int) -> str:
    """LH eighth ostinato (WRITTEN), PDF m9+ driving bass family."""
    seq = [root, root, root + 12, root + 7, root + 6, root + 5, root + 3, root]
    out = []
    for i, m in enumerate(seq):
        beam = "begin" if i % 2 == 0 else "end"
        acc = None
        if (m - root) == 6:
            acc = "flat"
        elif m % 12 == 11:
            acc = "natural"
        out.append(note(m, 2, "eighth", staff=2, voice=2, beam=beam, accidental=acc))
    return "".join(out)


def whole_rest_bass() -> str:
    return rest(16, "whole", 2, voice=2)


def whole_note_bass(midi: int, accidental: str | None = None) -> str:
    return note(midi, 16, "whole", staff=2, voice=2, accidental=accidental)


def measure(
    n: int,
    rh: str,
    lh: str,
    *,
    attrs: str = "",
    directions: str = "",
    barline_left: str = "",
    barline_right: str = "",
) -> str:
    return f"""
    <measure number="{n}">
      {barline_left}
      {attrs}
      {directions}
      {rh}
      {backup(16)}
      {lh}
      {barline_right}
    </measure>"""


def first_attrs() -> str:
    return f"""
      <attributes>
        <divisions>{DIV}</divisions>
        <key><fifths>-1</fifths><mode>minor</mode></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1">
          <sign>G</sign><line>2</line>
          <clef-octave-change>-1</clef-octave-change>
        </clef>
        <clef number="2">
          <sign>F</sign><line>4</line>
          <clef-octave-change>-1</clef-octave-change>
        </clef>
      </attributes>"""


def tempo_dir() -> str:
    return f"""
      <direction placement="above">
        <direction-type>
          <metronome parentheses="no">
            <beat-unit>quarter</beat-unit>
            <per-minute>{BPM}</per-minute>
          </metronome>
        </direction-type>
        <sound tempo="{BPM}"/>
      </direction>
      <direction placement="below">
        <direction-type><dynamics><mf/></dynamics></direction-type>
        <staff>2</staff>
      </direction>"""


def dyn(tag: str, staff: int = 2) -> str:
    return f"""
      <direction placement="below">
        <direction-type><dynamics><{tag}/></dynamics></direction-type>
        <staff>{staff}</staff>
      </direction>"""


def chord_half(midis: list[int], staff: int = 1) -> str:
    parts = []
    for i, m in enumerate(midis):
        parts.append(note(m, 8, "half", staff=staff, voice=1 if staff == 1 else 2, chord=(i > 0)))
    return "".join(parts)


def lh_riff(start: int) -> str:
    """Bass-register written riff (same rhythm as RH)."""
    return "".join(
        [
            note(start, 1, "16th", staff=2, voice=2, beam="begin"),
            note(start, 1, "16th", staff=2, voice=2, beam="end"),
            rest(2, "eighth", 2, voice=2),
            note(start + 12, 2, "eighth", staff=2, voice=2),
            rest(2, "eighth", 2, voice=2),
            note(start + 7, 2, "eighth", staff=2, voice=2),
            note(start + 6, 1, "16th", staff=2, voice=2, beam="begin", accidental="flat"),
            note(start + 5, 1, "16th", staff=2, voice=2, beam="end"),
            note(start + 3, 1, "16th", staff=2, voice=2, beam="begin"),
            note(start, 1, "16th", staff=2, voice=2, beam="continue"),
            note(start + 3, 1, "16th", staff=2, voice=2, beam="continue"),
            note(start + 5, 1, "16th", staff=2, voice=2, beam="end"),
        ]
    )


def build_xml() -> str:
    measures: list[str] = []

    # --- Page 1 intro (mm 1–8), RH roots D C Bn Bb then drones ---
    # WRITTEN: D4=62, C4=60, Bn3=59, Bb3=58; LH written D3=50 etc.
    measures.append(
        measure(1, riff_rh(62), whole_rest_bass(), attrs=first_attrs(), directions=tempo_dir())
    )
    measures.append(measure(2, riff_rh(60), whole_rest_bass()))
    measures.append(measure(3, riff_rh(59, natural_start=True), whole_rest_bass()))
    measures.append(measure(4, riff_rh(58), whole_rest_bass()))
    measures.append(measure(5, riff_rh(62), whole_note_bass(50)))  # LH D
    measures.append(measure(6, riff_rh(60), whole_note_bass(48)))  # LH C
    measures.append(
        measure(7, riff_rh(59, natural_start=True), whole_note_bass(47, accidental="natural"))
    )
    measures.append(
        measure(
            8,
            riff_rh(58),
            whole_note_bass(46),
            barline_right='<barline location="right"><bar-style>light-heavy</bar-style><repeat direction="backward"/></barline>',
        )
    )

    # --- m9–12 first ending section (forward repeat at 9) ---
    # LH written ostinato rooted on D3=50 (sounds D2 with 8vb)
    measures.append(
        measure(
            9,
            riff_rh(62),
            bass_ostinato(50),
            directions=dyn("f"),
            barline_left='<barline location="left"><bar-style>heavy-light</bar-style><repeat direction="forward"/></barline>',
        )
    )
    measures.append(measure(10, riff_rh(60), bass_ostinato(48)))
    measures.append(
        measure(
            11,
            riff_rh(59, natural_start=True),
            bass_ostinato(47),
            barline_left='<barline location="left"><ending number="1" type="start"/></barline>',
        )
    )
    measures.append(
        measure(
            12,
            riff_rh(58),
            bass_ostinato(46),
            barline_right='<barline location="right"><ending number="1" type="stop"/><bar-style>light-heavy</bar-style><repeat direction="backward"/></barline>',
        )
    )

    # --- m13–15 second ending ---
    measures.append(
        measure(
            13,
            riff_rh(62),
            bass_ostinato(50),
            barline_left='<barline location="left"><ending number="2" type="start"/></barline>',
            barline_right='<barline location="right"><ending number="2" type="stop"/></barline>',
        )
    )
    measures.append(measure(14, riff_rh(60), bass_ostinato(48)))
    measures.append(measure(15, riff_rh(58), bass_ostinato(46)))

    # --- Page 2 (mm16–21): RH continues riff; LH driving ostinato (PDF p2_s1) ---
    for n, start, root, nat in [
        (16, 62, 50, False),
        (17, 60, 48, False),
        (18, 59, 47, True),
        (19, 58, 46, False),
        (20, 62, 50, False),
        (21, 60, 48, False),
    ]:
        measures.append(
            measure(n, riff_rh(start, natural_start=nat), bass_ostinato(root))
        )

    # --- m22–30 louder repeat block (RH riff an octave higher written) ---
    measures.append(
        measure(
            22,
            riff_rh(74),
            bass_ostinato(50),
            barline_left='<barline location="left"><bar-style>heavy-light</bar-style><repeat direction="forward"/></barline>',
        )
    )
    for n, st, root in [
        (23, 72, 48),
        (24, 71, 47),
        (25, 74, 50),
        (26, 72, 48),
        (27, 70, 46),
    ]:
        measures.append(
            measure(
                n,
                riff_rh(st, natural_start=(st % 12 == 11)),
                bass_ostinato(root),
            )
        )

    chrom = [82, 81, 80, 79, 78, 77, 76, 75]
    rh28 = "".join(
        note(
            m,
            2,
            "eighth",
            staff=1,
            beam="begin" if i % 2 == 0 else "end",
            accidental="flat" if m % 12 in (1, 3, 6, 8, 10) else None,
        )
        for i, m in enumerate(chrom)
    )
    measures.append(measure(28, rh28, bass_ostinato(50)))
    measures.append(
        measure(
            29,
            chord_half([74, 77, 81]) + chord_half([70, 74, 77]),
            chord_half([50, 57], staff=2) + chord_half([46, 53], staff=2),
            barline_left='<barline location="left"><ending number="1" type="start"/></barline>',
            barline_right='<barline location="right"><ending number="1" type="stop"/><bar-style>light-heavy</bar-style><repeat direction="backward"/></barline>',
        )
    )
    measures.append(
        measure(
            30,
            chord_half([74, 77, 81]) + chord_half([69, 72, 76]),
            chord_half([50, 57], staff=2) + chord_half([45, 52], staff=2),
            barline_left='<barline location="left"><ending number="2" type="start"/></barline>',
            barline_right='<barline location="right"><ending number="2" type="stop"/></barline>',
        )
    )

    # --- m31–38 bridge (PDF p2_s6 / p3_s1): sustained RH over ostinato, mp ---
    # m31 D5 whole; m32 F5+E5 halves; m33–34 D5; m35 D5+A4; m36 F5+E5; m37–38 D5
    measures.append(
        measure(31, note(74, 16, "whole", staff=1), bass_ostinato(50), directions=dyn("mp"))
    )
    measures.append(
        measure(
            32,
            note(77, 8, "half", staff=1) + note(76, 8, "half", staff=1),
            bass_ostinato(48),
        )
    )
    measures.append(
        measure(
            33,
            note(74, 16, "whole", staff=1),
            bass_ostinato(47),
        )
    )
    measures.append(measure(34, note(74, 16, "whole", staff=1), bass_ostinato(50)))
    # m35: dotted half D5 + quarter A4 (duration 12+4)
    measures.append(
        measure(
            35,
            note(74, 12, "half", staff=1, dot=True) + note(69, 4, "quarter", staff=1),
            bass_ostinato(48),
        )
    )
    measures.append(
        measure(
            36,
            note(77, 8, "half", staff=1) + note(76, 8, "half", staff=1),
            bass_ostinato(47),
        )
    )
    measures.append(measure(37, note(74, 16, "whole", staff=1), bass_ostinato(46)))
    measures.append(
        measure(38, note(74, 16, "whole", staff=1), bass_ostinato(50), directions=dyn("mp"))
    )

    # --- m39–44: riff returns (PDF p3_s2/s3) — was wrongly whole-note filler ---
    for n, start, root, nat in [
        (39, 62, 50, False),
        (40, 60, 48, False),
        (41, 59, 47, True),
        (42, 58, 46, False),
        (43, 62, 50, False),
        (44, 60, 48, False),
    ]:
        measures.append(
            measure(n, riff_rh(start, natural_start=nat), bass_ostinato(root))
        )

    # --- m45–54 dense forte: Dm / Bb / Am cells (avoid bare C-major filler) ---
    measures.append(
        measure(
            45,
            chord_half([74, 77, 81, 86]) + chord_half([70, 74, 77, 82]),
            bass_ostinato(50),
            directions=dyn("f"),
        )
    )
    for n, root, a, b in [
        (46, 48, [72, 76, 79], [70, 74, 77]),
        (47, 47, [71, 74, 78], [67, 71, 74]),
        (48, 46, [70, 74, 77], [65, 70, 74]),
        (49, 50, [74, 77, 81], [70, 74, 77]),
        (50, 48, [72, 76, 79], [69, 72, 76]),
        (51, 47, [71, 74, 78], [67, 71, 74]),
        (52, 46, [70, 74, 77], [65, 70, 74]),
        (53, 50, [74, 77, 81], [70, 74, 77]),
        (54, 48, [72, 76, 79], [69, 72, 76]),
    ]:
        measures.append(
            measure(n, chord_half(a) + chord_half(b), bass_ostinato(root))
        )

    # --- m55–61 syncopated Dm / Bb chords ---
    for n, root in enumerate([50, 48, 47, 46, 50, 48, 46], start=55):
        measures.append(
            measure(
                n,
                "".join(
                    [
                        note(74, 2, "eighth", staff=1),
                        note(77, 2, "eighth", staff=1, chord=True),
                        note(81, 2, "eighth", staff=1, chord=True),
                        rest(2, "eighth", 1),
                        note(70, 2, "eighth", staff=1),
                        note(74, 2, "eighth", staff=1, chord=True),
                        note(77, 2, "eighth", staff=1, chord=True),
                        rest(2, "eighth", 1),
                    ]
                ),
                bass_ostinato(root),
            )
        )

    # --- m62–68 ascending runs ---
    seq = [67, 69, 70, 71, 72, 74, 75, 76, 77, 79, 80, 81, 82, 83, 84, 86]
    for n in range(62, 69):
        chunk = seq[(n - 62) * 2 : (n - 62) * 2 + 8]
        if len(chunk) < 8:
            chunk = (chunk + seq)[:8]
        rh = "".join(
            note(m, 2, "eighth", staff=1, beam="begin" if i % 2 == 0 else "end")
            for i, m in enumerate(chunk)
        )
        lh = whole_rest_bass() if n >= 63 else bass_ostinato(50)
        measures.append(measure(n, rh, lh))

    # --- m69–71 close ---
    measures.append(measure(69, riff_rh(62), bass_ostinato(50)))
    measures.append(measure(70, riff_rh(60), bass_ostinato(48)))
    measures.append(
        measure(
            71,
            chord_half([74, 77, 81, 86])
            + note(70, 8, "half", staff=1)
            + note(74, 8, "half", staff=1, chord=True)
            + note(77, 8, "half", staff=1, chord=True),
            chord_half([50, 57, 62], staff=2) + chord_half([46, 53, 58], staff=2),
            barline_right='<barline location="right"><bar-style>light-heavy</bar-style></barline>',
        )
    )

    body = "\n".join(measures)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC
  "-//Recordare//DTD MusicXML 3.1 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work>
    <work-title>{TITLE}</work-title>
  </work>
  <identification>
    <creator type="composer">{COMPOSER}</creator>
    <creator type="arranger">Piano arrangement matching user PDF (JesterMusician-style 8vb layout)</creator>
    <rights>Undertale © Toby Fox. Local PianoFlow practice only; not Public Domain.</rights>
    <encoding>
      <software>PianoFlow encode_megalovania.py (PDF transcription; NOT from MIDI)</software>
      <encoding-description>Formal path forbids MIDI→MusicXML. Source: _omr_work/megalovania/source.pdf</encoding-description>
    </encoding>
    <source>User PDF Megalovania.pdf (Toby Fox)</source>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
      <score-instrument id="P1-I1"><instrument-name>Piano</instrument-name></score-instrument>
      <midi-instrument id="P1-I1">
        <midi-channel>1</midi-channel>
        <midi-program>1</midi-program>
      </midi-instrument>
    </score-part>
  </part-list>
  <part id="P1">
{body}
  </part>
</score-partwise>
"""


def main() -> int:
    WORK.mkdir(parents=True, exist_ok=True)
    xml = build_xml()
    ET.fromstring(xml)
    OUT_CANONICAL.write_text(xml, encoding="utf-8")
    print(f"Wrote {OUT_CANONICAL} ({OUT_CANONICAL.stat().st_size} bytes)")
    print("Next: python .\\scripts\\build_megalovania.py")
    print("Then: python .\\scripts\\musicxml_to_score.py --id toby_fox_megalovania --update-catalog")
    return 0


if __name__ == "__main__":
    sys.exit(main())
