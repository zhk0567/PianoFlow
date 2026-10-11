"""R8: 诀别书 m9–12 staff-2 clef, and restore PDF ending m106–108.

m9–12: PDF changes the lower staff to treble at m9. The file kept bass-clef
pitches until the clef element at m13 (A2+C3 is the bass reading of F4+A4).
Shift those staff-2 pitches +12 diatonic steps and put the treble clef on m9.

m106–108: file was whole rests. PDF p5 (crops p5_bar1–3) is:
  RH under 8va, written A5 D6 A5 G5 | A5 G5 A5 G5 A5 G5 | B5
  LH treble clef, C4+E4+G4+C5 tied across the three bars.
MusicXML pitch is sounding, so RH is written+octave. octave-shift already
marks the 8va. Not a promotion to formal.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
ASSET = REPO / "assets/scores/musicxml/jue_bie_shu.musicxml"
SYNC_XML = [
    REPO / "third_party/scores_musicxml/jue_bie_shu.musicxml",
    REPO / "clients/web/scores/musicxml/jue_bie_shu.musicxml",
    REPO / "clients/android/app/src/main/assets/scores/musicxml/jue_bie_shu.musicxml",
]
SYNC_JSON = [
    REPO / "clients/web/scores/jue_bie_shu.json",
    REPO / "clients/android/app/src/main/assets/scores/jue_bie_shu.json",
]
STEPS = "CDEFGAB"


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def shift_to_treble(step: str, octave: int) -> tuple[str, int, int]:
    """Bass-clef reading → treble-clef reading of the same notehead.

    Key is one flat. No printed accidental in these bars, so the new letter
    takes the key signature only (B → Bb).
    """
    idx = octave * 7 + STEPS.index(step) + 12
    nstep = STEPS[idx % 7]
    noct = idx // 7
    nalt = -1 if nstep == "B" else 0
    return nstep, noct, nalt


def set_pitch(note: ET.Element, step: str, octave: int, alter: int) -> None:
    pitch = next(c for c in note if local(c.tag) == "pitch")
    step_el = octave_el = alter_el = None
    for c in pitch:
        t = local(c.tag)
        if t == "step":
            step_el = c
        elif t == "octave":
            octave_el = c
        elif t == "alter":
            alter_el = c
    if step_el is None or octave_el is None:
        return
    step_el.text = step
    octave_el.text = str(octave)
    if alter == 0:
        if alter_el is not None:
            pitch.remove(alter_el)
    elif alter_el is None:
        el = ET.Element("alter")
        el.text = str(alter)
        # MusicXML order: step, alter, octave
        step_el_index = list(pitch).index(step_el)
        pitch.insert(step_el_index + 1, el)
    else:
        alter_el.text = str(alter)


def staff_of(note: ET.Element) -> str | None:
    for c in note:
        if local(c.tag) == "staff":
            return c.text
    return None


def is_rest(note: ET.Element) -> bool:
    return any(local(c.tag) == "rest" for c in note)


def fix_m9_12(by_num: dict[int, ET.Element]) -> None:
    for num in (9, 10, 11, 12):
        m = by_num[num]
        if num == 9 and not any(
            local(el.tag) == "clef" for el in m.iter()
        ):
            attrs = ET.Element("attributes")
            clef = ET.SubElement(attrs, "clef", number="2")
            ET.SubElement(clef, "sign").text = "G"
            ET.SubElement(clef, "line").text = "2"
            # Before the first note.
            insert_at = 0
            for i, el in enumerate(list(m)):
                if local(el.tag) == "note":
                    insert_at = i
                    break
            m.insert(insert_at, attrs)
        for note in list(m):
            if local(note.tag) != "note" or staff_of(note) != "2":
                continue
            if is_rest(note):
                rest = next(c for c in note if local(c.tag) == "rest")
                for child in list(rest):
                    if local(child.tag) in ("display-step", "display-octave"):
                        rest.remove(child)
                continue
            pitch = next(c for c in note if local(c.tag) == "pitch")
            step = octave = None
            for c in pitch:
                if local(c.tag) == "step":
                    step = c.text
                elif local(c.tag) == "octave":
                    octave = int(c.text or "0")
            if step is None or octave is None:
                continue
            nstep, noct, nalt = shift_to_treble(step, octave)
            set_pitch(note, nstep, noct, nalt)
        print(f"shifted staff-2 pitches m{num}")


def note_el(
    step: str,
    octave: int,
    dur: int,
    typ: str,
    *,
    staff: int,
    voice: int,
    alter: int | None = None,
    chord: bool = False,
    tie: str | None = None,
) -> ET.Element:
    n = ET.Element("note")
    if chord:
        ET.SubElement(n, "chord")
    p = ET.SubElement(n, "pitch")
    ET.SubElement(p, "step").text = step
    if alter is not None:
        ET.SubElement(p, "alter").text = str(alter)
    ET.SubElement(p, "octave").text = str(octave)
    ET.SubElement(n, "duration").text = str(dur)
    if tie:
        ET.SubElement(n, "tie", type=tie)
    ET.SubElement(n, "voice").text = str(voice)
    ET.SubElement(n, "type").text = typ
    ET.SubElement(n, "staff").text = str(staff)
    if tie:
        notations = ET.SubElement(n, "notations")
        ET.SubElement(notations, "tied", type=tie)
    return n


def backup(dur: int = 16) -> ET.Element:
    b = ET.Element("backup")
    ET.SubElement(b, "duration").text = str(dur)
    return b


def chord(
    tones: list[tuple],
    dur: int,
    typ: str,
    *,
    staff: int,
    voice: int,
    tie: str | None,
) -> list[ET.Element]:
    out = []
    for i, (step, octave, alter) in enumerate(tones):
        out.append(
            note_el(
                step,
                octave,
                dur,
                typ,
                staff=staff,
                voice=voice,
                alter=alter,
                chord=i > 0,
                tie=tie,
            )
        )
    return out


def clear_sounding(m: ET.Element) -> None:
    for el in list(m):
        if local(el.tag) in ("note", "backup", "forward"):
            m.remove(el)


def fix_ending(by_num: dict[int, ET.Element]) -> None:
    # Drop the duplicate 8va start on m106; m105 already opened octave-shift.
    m106 = by_num[106]
    for el in list(m106):
        if local(el.tag) != "direction":
            continue
        if any(local(d.tag) == "octave-shift" for d in el.iter()):
            m106.remove(el)
    for el in m106.iter():
        if local(el.tag) == "clef" and el.get("number") == "2":
            for c in el:
                if local(c.tag) == "sign":
                    c.text = "G"
                elif local(c.tag) == "line":
                    c.text = "2"

    lh = [("C", 4, None), ("E", 4, None), ("G", 4, None), ("C", 5, None)]
    rh_106 = [
        note_el("A", 6, 4, "quarter", staff=1, voice=1),
        note_el("D", 7, 4, "quarter", staff=1, voice=1),
        note_el("A", 6, 4, "quarter", staff=1, voice=1),
        note_el("G", 6, 4, "quarter", staff=1, voice=1),
    ]
    rh_107 = [
        note_el("A", 6, 2, "eighth", staff=1, voice=1),
        note_el("G", 6, 2, "eighth", staff=1, voice=1),
        note_el("A", 6, 2, "eighth", staff=1, voice=1),
        note_el("G", 6, 2, "eighth", staff=1, voice=1),
        note_el("A", 6, 4, "quarter", staff=1, voice=1),
        note_el("G", 6, 4, "quarter", staff=1, voice=1),
    ]
    rh_108 = [note_el("B", 6, 16, "whole", staff=1, voice=1, alter=-1)]
    bodies = {
        106: rh_106 + [backup()] + chord(lh, 16, "whole", staff=2, voice=5, tie="start"),
        107: rh_107 + [backup()] + chord(lh, 16, "whole", staff=2, voice=5, tie="stop"),
        108: rh_108 + [backup()] + chord(lh, 16, "whole", staff=2, voice=5, tie="stop"),
    }
    # Middle bar of a 3-bar tie needs stop+start. MusicXML allows two tie elements.
    for num, els in bodies.items():
        m = by_num[num]
        clear_sounding(m)
        for el in els:
            m.append(el)
        print(f"rewrote m{num}")
    # m107 continuation: add a second tie start so the tie reaches m108.
    for note in by_num[107]:
        if local(note.tag) != "note" or staff_of(note) != "2" or is_rest(note):
            continue
        ET.SubElement(note, "tie", type="start")
        notations = next(c for c in note if local(c.tag) == "notations")
        ET.SubElement(notations, "tied", type="start")


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    part = next(el for el in root if local(el.tag) == "part")
    by_num = {
        int(m.get("number")): m for m in part if local(m.tag) == "measure"
    }
    fix_m9_12(by_num)
    fix_ending(by_num)
    tree.write(ASSET, encoding="utf-8", xml_declaration=True)
    for dest in SYNC_XML:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ASSET, dest)
    r = subprocess.run(
        [sys.executable, "-u", str(REPO / "scripts/musicxml_to_score.py"), "--id", "jue_bie_shu"],
        cwd=REPO,
    )
    if r.returncode != 0:
        return r.returncode
    src_json = REPO / "assets/scores/jue_bie_shu.json"
    for dest in SYNC_JSON:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_json, dest)
    print("synced; still omrDraft")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
