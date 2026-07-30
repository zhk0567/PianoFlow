#!/usr/bin/env python3
"""Write public-domain reference MusicXML for the first textbook batch.

These are formal grand-staff encodings of well-known PD editions so the
converter pipeline can run before MuseScore downloads replace them.
"""

from __future__ import annotations

from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "third_party" / "scores_musicxml"

# pitch: (step, octave, alter?)  alter: -1 flat, 1 sharp
# duration in divisions (div=2 → quarter=2, eighth=1)


def note_xml(
    step: str,
    octave: int,
    dur: int,
    *,
    alter: int | None = None,
    staff: int = 1,
    chord: bool = False,
    backup: bool = False,
) -> str:
    alter_xml = f"<alter>{alter}</alter>" if alter is not None else ""
    chord_xml = "<chord/>" if chord else ""
    return f"""<note>{chord_xml}<pitch><step>{step}</step>{alter_xml}<octave>{octave}</octave></pitch><duration>{dur}</duration><voice>{staff}</voice><type></type><staff>{staff}</staff></note>"""


def rest_xml(dur: int, staff: int = 1) -> str:
    return f"""<note><rest/><duration>{dur}</duration><voice>{staff}</voice><staff>{staff}</staff></note>"""


def backup_xml(dur: int) -> str:
    return f"<backup><duration>{dur}</duration></backup>"


def measure(number: int, body: str, *, attrs: str = "") -> str:
    return f'<measure number="{number}">{attrs}{body}</measure>'


def wrap(
    score_id: str,
    title: str,
    *,
    fifths: int,
    beats: int,
    beat_type: int,
    divisions: int,
    tempo: int,
    measures: str,
) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>{title}</work-title></work>
  <identification>
    <creator type="composer">Public Domain</creator>
    <rights>Public Domain textbook reference for PianoFlow import</rights>
  </identification>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>{divisions}</divisions>
        <key><fifths>{fifths}</fifths></key>
        <time><beats>{beats}</beats><beat-type>{beat_type}</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>{tempo}</per-minute></metronome></direction-type><sound tempo="{tempo}"/></direction>
{measures}
  </part>
</score-partwise>
"""


def n(step, oct_, dur, staff=1, alter=None, chord=False):
    return note_xml(step, oct_, dur, alter=alter, staff=staff, chord=chord)


def build_bach_anh114() -> str:
    """Petzold / BWV Anh.114 Minuet in G — standard A+B (16+16 with written-out feel as 32 bars linear first endings)."""
    d = 2  # quarter=2
    # Helper for RH eighth = 1, quarter = 2, half = 4, dotted half = 6
    bars_rh = [
        # 1-8
        [n("D", 5, 2), n("G", 4, 1), n("A", 4, 1), n("B", 4, 1), n("C", 5, 1)],
        [n("D", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("E", 5, 2), n("C", 5, 1), n("D", 5, 1), n("E", 5, 1), n("F", 5, 1, alter=1)],
        [n("G", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("C", 5, 2), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1)],
        [n("B", 4, 2), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1), n("G", 4, 1)],
        [n("F", 4, 2, alter=1), n("G", 4, 1), n("A", 4, 1), n("B", 4, 1), n("G", 4, 1)],
        [n("A", 4, 4), n("A", 4, 2)],
        # 9-16
        [n("D", 5, 2), n("G", 4, 1), n("A", 4, 1), n("B", 4, 1), n("C", 5, 1)],
        [n("D", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("E", 5, 2), n("C", 5, 1), n("D", 5, 1), n("E", 5, 1), n("F", 5, 1, alter=1)],
        [n("G", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("C", 5, 2), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1)],
        [n("B", 4, 2), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1), n("G", 4, 1)],
        [n("A", 4, 2), n("D", 5, 1), n("B", 4, 1), n("G", 4, 2)],
        [n("G", 4, 6)],
        # 17-24 B section
        [n("B", 5, 2), n("G", 5, 1), n("A", 5, 1), n("B", 5, 1), n("G", 5, 1)],
        [n("A", 5, 2), n("D", 5, 1), n("E", 5, 1), n("F", 5, 1, alter=1), n("D", 5, 1)],
        [n("G", 5, 2), n("E", 5, 1), n("F", 5, 1, alter=1), n("G", 5, 1), n("D", 5, 1)],
        [n("C", 6, 2), n("B", 5, 1), n("A", 5, 1), n("G", 5, 1), n("F", 5, 1, alter=1)],
        [n("E", 5, 2), n("G", 5, 1), n("F", 5, 1, alter=1), n("E", 5, 1), n("D", 5, 1)],
        [n("C", 5, 2), n("E", 5, 1), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1)],
        [n("A", 4, 2), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1)],
        [n("G", 4, 2), n("B", 4, 1), n("A", 4, 1), n("G", 4, 1), n("F", 4, 1, alter=1)],
        # 25-32
        [n("E", 4, 2), n("G", 4, 1), n("A", 4, 1), n("B", 4, 1), n("C", 5, 1)],
        [n("D", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("E", 5, 2), n("C", 5, 1), n("D", 5, 1), n("E", 5, 1), n("F", 5, 1, alter=1)],
        [n("G", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("C", 5, 2), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1)],
        [n("B", 4, 2), n("C", 5, 1), n("B", 4, 1), n("A", 4, 1), n("G", 4, 1)],
        [n("A", 4, 2), n("D", 5, 1), n("B", 4, 1), n("G", 4, 2)],
        [n("G", 4, 6)],
    ]
    # LH: simple continuo-style for teaching edition
    bars_lh = [
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2), n("G", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("A", 3, 2, 2), n("C", 4, 2, 2), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("D", 3, 2, 2), n("A", 3, 2, 2), n("D", 4, 2, 2)],
        [n("D", 3, 4, 2), n("D", 3, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2), n("G", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("A", 3, 2, 2), n("C", 4, 2, 2), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("D", 3, 2, 2), n("D", 4, 2, 2), n("G", 3, 2, 2)],
        [n("G", 2, 6, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("D", 3, 2, 2), n("F", 3, 2, 2, alter=1), n("A", 3, 2, 2)],
        [n("E", 3, 2, 2), n("G", 3, 2, 2), n("B", 3, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2), n("G", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2), n("G", 4, 2, 2)],
        [n("A", 3, 2, 2), n("C", 4, 2, 2), n("E", 4, 2, 2)],
        [n("D", 3, 2, 2), n("F", 3, 2, 2, alter=1), n("A", 3, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2), n("G", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2), n("G", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("A", 3, 2, 2), n("C", 4, 2, 2), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2), n("D", 4, 2, 2)],
        [n("D", 3, 2, 2), n("D", 4, 2, 2), n("G", 3, 2, 2)],
        [n("G", 2, 6, 2)],
    ]

    parts = []
    for i, (rh, lh) in enumerate(zip(bars_rh, bars_lh), start=1):
        body = "".join(rh) + backup_xml(6) + "".join(lh)
        if i == 1:
            # attributes already in wrap's first measure — inject body only into first measure content
            parts.append(body)
        else:
            parts.append(measure(i, body))
    # First measure body is spliced into wrap template after attributes
    first = parts[0]
    rest = "\n".join(parts[1:])
    # rebuild wrap manually for first measure content
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Minuet in G major, BWV Anh. 114</work-title></work>
  <identification><rights>Public Domain</rights></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key><fifths>1</fifths></key>
        <time><beats>3</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>96</per-minute></metronome></direction-type><sound tempo="96"/></direction>
      {first}
    </measure>
    {rest}
  </part>
</score-partwise>
"""


def build_bach_anh115() -> str:
    """BWV Anh.115 Minuet in G minor — 3/4, 2 flats."""
    bars_rh = [
        [n("G", 4, 2), n("A", 4, 1, alter=-1), n("B", 4, 1, alter=-1), n("C", 5, 2)],
        [n("D", 5, 2), n("D", 5, 2), n("D", 5, 2)],
        [n("E", 5, 2, alter=-1), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1, alter=-1), n("A", 4, 1, alter=-1)],
        [n("B", 4, 4, alter=-1), n("B", 4, 2, alter=-1)],
        [n("C", 5, 2), n("D", 5, 1), n("E", 5, 1, alter=-1), n("F", 5, 2)],
        [n("G", 5, 2), n("G", 4, 2), n("G", 4, 2)],
        [n("A", 4, 2, alter=-1), n("B", 4, 1, alter=-1), n("C", 5, 1), n("D", 5, 1), n("B", 4, 1, alter=-1)],
        [n("G", 4, 6)],
        [n("G", 4, 2), n("A", 4, 1, alter=-1), n("B", 4, 1, alter=-1), n("C", 5, 2)],
        [n("D", 5, 2), n("D", 5, 2), n("D", 5, 2)],
        [n("E", 5, 2, alter=-1), n("D", 5, 1), n("C", 5, 1), n("B", 4, 1, alter=-1), n("A", 4, 1, alter=-1)],
        [n("B", 4, 4, alter=-1), n("B", 4, 2, alter=-1)],
        [n("C", 5, 2), n("D", 5, 1), n("E", 5, 1, alter=-1), n("F", 5, 2)],
        [n("G", 5, 2), n("B", 4, 1, alter=-1), n("A", 4, 1, alter=-1), n("G", 4, 2)],
        [n("A", 4, 2, alter=-1), n("D", 5, 2), n("F", 4, 1, alter=1), n("A", 4, 1, alter=-1)],
        [n("G", 4, 6)],
    ]
    bars_lh = [
        [n("G", 3, 2, 2), n("B", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2, alter=-1), n("G", 4, 2, 2)],
        [n("G", 3, 4, 2), n("G", 3, 2, 2)],
        [n("A", 3, 2, 2, alter=-1), n("C", 4, 2, 2), n("F", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("D", 3, 2, 2), n("F", 3, 2, 2, alter=1), n("A", 3, 2, 2, alter=-1)],
        [n("G", 2, 6, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("C", 4, 2, 2), n("E", 4, 2, 2, alter=-1), n("G", 4, 2, 2)],
        [n("G", 3, 4, 2), n("G", 3, 2, 2)],
        [n("A", 3, 2, 2, alter=-1), n("C", 4, 2, 2), n("F", 4, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("D", 3, 2, 2), n("A", 3, 2, 2, alter=-1), n("D", 4, 2, 2)],
        [n("G", 2, 6, 2)],
    ]
    parts = []
    for i, (rh, lh) in enumerate(zip(bars_rh, bars_lh), start=1):
        body = "".join(rh) + backup_xml(6) + "".join(lh)
        parts.append((i, body))
    first = parts[0][1]
    rest = "\n".join(measure(i, b) for i, b in parts[1:])
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Minuet in G minor, BWV Anh. 115</work-title></work>
  <identification><rights>Public Domain</rights></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key><fifths>-2</fifths></key>
        <time><beats>3</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>88</per-minute></metronome></direction-type><sound tempo="88"/></direction>
      {first}
    </measure>
    {rest}
  </part>
</score-partwise>
"""


def build_bach_anh126() -> str:
    """Musette BWV Anh.126 — 2/4, G major, drone-like LH."""
    bars_rh = [
        [n("G", 5, 1), n("D", 5, 1), n("G", 5, 1), n("D", 5, 1)],
        [n("B", 5, 1), n("A", 5, 1), n("G", 5, 1), n("F", 5, 1, alter=1)],
        [n("G", 5, 1), n("D", 5, 1), n("G", 5, 1), n("D", 5, 1)],
        [n("B", 5, 2), n("B", 5, 2)],
        [n("C", 6, 1), n("A", 5, 1), n("F", 5, 1, alter=1), n("A", 5, 1)],
        [n("B", 5, 1), n("G", 5, 1), n("D", 5, 1), n("G", 5, 1)],
        [n("A", 5, 1), n("F", 5, 1, alter=1), n("D", 5, 1), n("F", 5, 1, alter=1)],
        [n("G", 5, 4)],
        [n("G", 5, 1), n("D", 5, 1), n("G", 5, 1), n("D", 5, 1)],
        [n("B", 5, 1), n("A", 5, 1), n("G", 5, 1), n("F", 5, 1, alter=1)],
        [n("G", 5, 1), n("D", 5, 1), n("G", 5, 1), n("D", 5, 1)],
        [n("B", 5, 2), n("B", 5, 2)],
        [n("C", 6, 1), n("A", 5, 1), n("F", 5, 1, alter=1), n("A", 5, 1)],
        [n("B", 5, 1), n("G", 5, 1), n("D", 5, 1), n("B", 4, 1)],
        [n("A", 4, 1), n("D", 5, 1), n("F", 5, 1, alter=1), n("A", 5, 1)],
        [n("G", 5, 4)],
    ]
    bars_lh = [
        [n("G", 3, 2, 2), n("D", 3, 2, 2)],
        [n("G", 3, 2, 2), n("D", 3, 2, 2)],
        [n("G", 3, 2, 2), n("D", 3, 2, 2)],
        [n("G", 3, 4, 2)],
        [n("D", 3, 2, 2), n("A", 3, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2)],
        [n("D", 3, 2, 2), n("A", 3, 2, 2)],
        [n("G", 2, 4, 2)],
        [n("G", 3, 2, 2), n("D", 3, 2, 2)],
        [n("G", 3, 2, 2), n("D", 3, 2, 2)],
        [n("G", 3, 2, 2), n("D", 3, 2, 2)],
        [n("G", 3, 4, 2)],
        [n("D", 3, 2, 2), n("A", 3, 2, 2)],
        [n("G", 3, 2, 2), n("B", 3, 2, 2)],
        [n("D", 3, 2, 2), n("D", 4, 2, 2)],
        [n("G", 2, 4, 2)],
    ]
    parts = []
    for i, (rh, lh) in enumerate(zip(bars_rh, bars_lh), start=1):
        body = "".join(rh) + backup_xml(4) + "".join(lh)
        parts.append((i, body))
    first = parts[0][1]
    rest = "\n".join(measure(i, b) for i, b in parts[1:])
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Musette, BWV Anh. 126</work-title></work>
  <identification><rights>Public Domain</rights></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key><fifths>1</fifths></key>
        <time><beats>2</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>108</per-minute></metronome></direction-type><sound tempo="108"/></direction>
      {first}
    </measure>
    {rest}
  </part>
</score-partwise>
"""


def build_burg_op100_2() -> str:
    """Burgmüller Arabesque Op.100 No.2 — A minor, 2/4, characteristic RH sixteenths simplified to eighths for practice engine."""
    # Teaching reduction keeping contour of famous opening
    bars_rh = [
        [n("E", 5, 1), n("A", 4, 1), n("C", 5, 1), n("E", 5, 1)],
        [n("A", 5, 1), n("E", 5, 1), n("C", 5, 1), n("A", 4, 1)],
        [n("B", 4, 1), n("E", 4, 1), n("G", 4, 1, alter=1), n("B", 4, 1)],
        [n("E", 5, 1), n("B", 4, 1), n("G", 4, 1, alter=1), n("E", 4, 1)],
        [n("A", 4, 1), n("C", 5, 1), n("E", 5, 1), n("A", 5, 1)],
        [n("G", 5, 1, alter=1), n("E", 5, 1), n("B", 4, 1), n("G", 4, 1, alter=1)],
        [n("A", 4, 2), n("E", 5, 2)],
        [n("A", 4, 4)],
        [n("E", 5, 1), n("A", 4, 1), n("C", 5, 1), n("E", 5, 1)],
        [n("A", 5, 1), n("E", 5, 1), n("C", 5, 1), n("A", 4, 1)],
        [n("B", 4, 1), n("E", 4, 1), n("G", 4, 1, alter=1), n("B", 4, 1)],
        [n("E", 5, 1), n("B", 4, 1), n("G", 4, 1, alter=1), n("E", 4, 1)],
        [n("A", 4, 1), n("C", 5, 1), n("E", 5, 1), n("A", 5, 1)],
        [n("B", 5, 1), n("G", 5, 1, alter=1), n("E", 5, 1), n("B", 4, 1)],
        [n("A", 5, 2), n("E", 5, 1), n("C", 5, 1)],
        [n("A", 4, 4)],
    ]
    bars_lh = [
        [n("A", 2, 2, 2), n("A", 3, 2, 2)],
        [n("A", 2, 2, 2), n("A", 3, 2, 2)],
        [n("E", 2, 2, 2), n("E", 3, 2, 2)],
        [n("E", 2, 2, 2), n("E", 3, 2, 2)],
        [n("A", 2, 2, 2), n("A", 3, 2, 2)],
        [n("E", 2, 2, 2), n("E", 3, 2, 2)],
        [n("A", 2, 2, 2), n("C", 3, 2, 2)],
        [n("A", 2, 4, 2)],
        [n("A", 2, 2, 2), n("A", 3, 2, 2)],
        [n("A", 2, 2, 2), n("A", 3, 2, 2)],
        [n("E", 2, 2, 2), n("E", 3, 2, 2)],
        [n("E", 2, 2, 2), n("E", 3, 2, 2)],
        [n("A", 2, 2, 2), n("A", 3, 2, 2)],
        [n("E", 3, 2, 2), n("G", 3, 2, 2, alter=1)],
        [n("A", 3, 2, 2), n("E", 3, 2, 2)],
        [n("A", 2, 4, 2)],
    ]
    parts = []
    for i, (rh, lh) in enumerate(zip(bars_rh, bars_lh), start=1):
        body = "".join(rh) + backup_xml(4) + "".join(lh)
        parts.append((i, body))
    first = parts[0][1]
    rest = "\n".join(measure(i, b) for i, b in parts[1:])
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Arabesque, Op.100 No.2</work-title></work>
  <identification><rights>Public Domain</rights></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>2</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>112</per-minute></metronome></direction-type><sound tempo="112"/></direction>
      {first}
    </measure>
    {rest}
  </part>
</score-partwise>
"""


def build_clementi_op36_1() -> str:
    """Clementi Sonatina Op.36 No.1 mvt I opening (exposition theme) — C major 4/4 teaching extract."""
    bars_rh = [
        [n("C", 5, 2), n("E", 5, 2), n("G", 5, 2), n("C", 6, 1), n("B", 5, 1)],
        [n("A", 5, 2), n("G", 5, 2), n("F", 5, 2), n("E", 5, 2)],
        [n("D", 5, 2), n("G", 4, 1), n("A", 4, 1), n("B", 4, 1), n("C", 5, 1), n("D", 5, 1), n("E", 5, 1)],
        [n("F", 5, 2), n("E", 5, 2), n("D", 5, 2), n("C", 5, 2)],
        [n("B", 4, 2), n("G", 4, 2), n("A", 4, 2), n("B", 4, 2)],
        [n("C", 5, 2), n("E", 5, 2), n("G", 5, 2), n("E", 5, 2)],
        [n("F", 5, 2), n("A", 5, 2), n("G", 5, 1), n("F", 5, 1), n("E", 5, 1), n("D", 5, 1)],
        [n("C", 5, 4), n("C", 5, 4)],
        [n("G", 5, 2), n("E", 5, 2), n("C", 5, 2), n("G", 4, 2)],
        [n("A", 4, 2), n("C", 5, 2), n("F", 5, 2), n("A", 5, 2)],
        [n("G", 5, 2), n("E", 5, 2), n("C", 5, 2), n("G", 4, 2)],
        [n("F", 4, 2), n("A", 4, 2), n("D", 5, 2), n("F", 5, 2)],
        [n("E", 5, 2), n("G", 5, 2), n("C", 6, 2), n("E", 5, 2)],
        [n("D", 5, 2), n("F", 5, 2), n("B", 4, 2), n("D", 5, 2)],
        [n("C", 5, 2), n("E", 5, 1), n("G", 5, 1), n("C", 6, 4)],
        [n("C", 5, 8)],
    ]
    bars_lh = [
        [n("C", 3, 2, 2), n("C", 4, 2, 2), n("E", 3, 2, 2), n("C", 4, 2, 2)],
        [n("F", 3, 2, 2), n("C", 4, 2, 2), n("C", 3, 2, 2), n("C", 4, 2, 2)],
        [n("G", 2, 2, 2), n("G", 3, 2, 2), n("G", 2, 2, 2), n("G", 3, 2, 2)],
        [n("C", 3, 2, 2), n("C", 4, 2, 2), n("G", 2, 2, 2), n("G", 3, 2, 2)],
        [n("G", 2, 2, 2), n("G", 3, 2, 2), n("G", 2, 2, 2), n("G", 3, 2, 2)],
        [n("C", 3, 2, 2), n("C", 4, 2, 2), n("E", 3, 2, 2), n("C", 4, 2, 2)],
        [n("F", 3, 2, 2), n("F", 4, 2, 2), n("G", 3, 2, 2), n("G", 2, 2, 2)],
        [n("C", 3, 4, 2), n("C", 3, 4, 2)],
        [n("C", 3, 2, 2), n("C", 4, 2, 2), n("E", 3, 2, 2), n("C", 4, 2, 2)],
        [n("F", 3, 2, 2), n("F", 4, 2, 2), n("F", 3, 2, 2), n("F", 4, 2, 2)],
        [n("C", 3, 2, 2), n("C", 4, 2, 2), n("E", 3, 2, 2), n("C", 4, 2, 2)],
        [n("D", 3, 2, 2), n("D", 4, 2, 2), n("B", 2, 2, 2), n("G", 3, 2, 2)],
        [n("C", 3, 2, 2), n("C", 4, 2, 2), n("C", 3, 2, 2), n("C", 4, 2, 2)],
        [n("G", 2, 2, 2), n("G", 3, 2, 2), n("G", 2, 2, 2), n("G", 3, 2, 2)],
        [n("C", 3, 2, 2), n("G", 3, 2, 2), n("C", 4, 4, 2)],
        [n("C", 3, 8, 2)],
    ]
    parts = []
    for i, (rh, lh) in enumerate(zip(bars_rh, bars_lh), start=1):
        body = "".join(rh) + backup_xml(8) + "".join(lh)
        parts.append((i, body))
    first = parts[0][1]
    rest = "\n".join(measure(i, b) for i, b in parts[1:])
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Sonatina Op.36 No.1, I</work-title></work>
  <identification><rights>Public Domain</rights></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <staves>2</staves>
        <clef number="1"><sign>G</sign><line>2</line></clef>
        <clef number="2"><sign>F</sign><line>4</line></clef>
      </attributes>
      <direction placement="above"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>112</per-minute></metronome></direction-type><sound tempo="112"/></direction>
      {first}
    </measure>
    {rest}
  </part>
</score-partwise>
"""


def main() -> None:
    # App catalog keeps only pachelbel_canon_d (see scripts/encode_cantor_canon_d.py).
    # Historical builders below are retained for reference but no longer written.
    print(
        "skipped: only pachelbel_canon_d is shipped; "
        "use scripts/encode_cantor_canon_d.py"
    )


if __name__ == "__main__":
    main()
