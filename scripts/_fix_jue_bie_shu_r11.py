"""R11: 诀别书 m69/m89–91 左手和弦，以及 m77 按扫描重写。

m69、m85、m89–91 左手扫描同样是 C 和弦（C3 + C4/E4/G4）。
m69 旧稿 F2 + F3/A3/C4；m85/m89–91 旧稿 D2 + D3/F3/A3。
m77：扫描右手 D4、G4+B4、A4 G4 G4、G4+B4、G4+B4、G4 E4；
左手 F3 与 A3+C4 交替四次。未升 formal。
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


def pitch_of(note: ET.Element) -> tuple[str, int] | None:
    pitch = next((c for c in note if local(c.tag) == "pitch"), None)
    if pitch is None:
        return None
    step = next(c.text for c in pitch if local(c.tag) == "step")
    octave = int(next(c.text for c in pitch if local(c.tag) == "octave"))
    return step, octave


def set_pitch(note: ET.Element, step: str, octave: int) -> None:
    pitch = next(c for c in note if local(c.tag) == "pitch")
    next(c for c in pitch if local(c.tag) == "step").text = step
    next(c for c in pitch if local(c.tag) == "octave").text = str(octave)


def raise_steps(note: ET.Element, n: int) -> None:
    cur = pitch_of(note)
    if cur is None:
        return
    step, octave = cur
    i = STEPS.index(step) + n
    set_pitch(note, STEPS[i % 7], octave + i // 7)


def staff2_notes(measure: ET.Element):
    for note in measure:
        if local(note.tag) != "note":
            continue
        staff = next((c.text for c in note if local(c.tag) == "staff"), "1")
        if staff != "2":
            continue
        if any(local(c.tag) == "rest" for c in note):
            continue
        if pitch_of(note) is None:
            continue
        yield note


def note_el(step: str, octave: int, dur: int, typ: str, *, staff: int, voice: int, chord: bool = False) -> ET.Element:
    n = ET.Element("note")
    if chord:
        ET.SubElement(n, "chord")
    p = ET.SubElement(n, "pitch")
    ET.SubElement(p, "step").text = step
    ET.SubElement(p, "octave").text = str(octave)
    ET.SubElement(n, "duration").text = str(dur)
    ET.SubElement(n, "voice").text = str(voice)
    ET.SubElement(n, "type").text = typ
    ET.SubElement(n, "staff").text = str(staff)
    return n


def rewrite_m77(measure: ET.Element) -> None:
    keep = [el for el in list(measure) if local(el.tag) not in ("note", "backup")]
    for el in list(measure):
        measure.remove(el)
    for el in keep:
        measure.append(el)
    rh = [
        ("D", 4, 2, "eighth", False),
        ("G", 4, 2, "eighth", False),
        ("B", 4, 2, "eighth", True),
        ("A", 4, 1, "16th", False),
        ("G", 4, 1, "16th", False),
        ("G", 4, 2, "eighth", False),
        ("G", 4, 2, "eighth", False),
        ("B", 4, 2, "eighth", True),
        ("G", 4, 2, "eighth", False),
        ("B", 4, 2, "eighth", True),
        ("G", 4, 2, "eighth", False),
        ("E", 4, 2, "eighth", False),
    ]
    for step, octv, dur, typ, ch in rh:
        measure.append(note_el(step, octv, dur, typ, staff=1, voice=1, chord=ch))
    backup = ET.SubElement(measure, "backup")
    ET.SubElement(backup, "duration").text = "16"
    for _ in range(4):
        measure.append(note_el("F", 3, 2, "eighth", staff=2, voice=5))
        measure.append(note_el("A", 3, 2, "eighth", staff=2, voice=5))
        measure.append(note_el("C", 4, 2, "eighth", staff=2, voice=5, chord=True))


def main() -> int:
    tree = ET.parse(ASSET)
    root = tree.getroot()
    part = next(el for el in root if local(el.tag) == "part")
    by_num = {m.get("number"): m for m in part if local(m.tag) == "measure"}
    changed = 0

    m69 = by_num["69"]
    sample = next(staff2_notes(m69), None)
    if sample is not None and pitch_of(sample) == ("F", 2):
        for n in staff2_notes(m69):
            raise_steps(n, 4)
            changed += 1
        print("m69 LH +4")
    else:
        print("m69 LH already C")

    d_to_c = {("D", 2): ("C", 3), ("D", 3): ("C", 4), ("F", 3): ("E", 4), ("A", 3): ("G", 4)}
    for num in ("85", "89", "90", "91"):
        m = by_num[num]
        sample = next(staff2_notes(m), None)
        if sample is None:
            print(f"m{num} no LH")
            continue
        cur = pitch_of(sample)
        if cur == ("C", 3):
            print(f"m{num} LH already C")
            continue
        if cur != ("D", 2):
            print(f"m{num} unexpected {cur}", file=sys.stderr)
            return 1
        for n in staff2_notes(m):
            key = pitch_of(n)
            if key not in d_to_c:
                print(f"m{num} unexpected {key}", file=sys.stderr)
                return 1
            set_pitch(n, *d_to_c[key])
            changed += 1
        print(f"m{num} LH D–F–A -> C–E–G")

    m77 = by_num["77"]
    first = next((n for n in m77 if local(n.tag) == "note" and pitch_of(n)), None)
    if first is not None and pitch_of(first) == ("D", 4):
        print("m77 already rewritten")
    else:
        rewrite_m77(m77)
        changed += 1
        print("rewrote m77")

    if changed:
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
