#!/usr/bin/env python3
"""Apply PDF-proofread metadata (and known pitch fixes) to OMR MusicXML.

Never sets scoreKind=formal. After patching, re-run:
  python .\\scripts\\musicxml_to_score.py --id <id> --update-catalog --score-kind omrDraft
  python .\\scripts\\omr_audit_score.py --id <id>

PDF tempos read from third_party/scores_pdf page-1 metronome marks (image proofread 2026-08-04).
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from musicxml_to_score import local  # noqa: E402

ASSETS_XML = REPO / "assets" / "scores" / "musicxml"
THIRD_XML = REPO / "third_party" / "scores_musicxml"
CATALOG = REPO / "assets" / "scores" / "catalog.json"

# Quarter-note BPM as printed on PDF (or practice default when only Vivace etc.).
PDF_TEMPO: dict[str, int] = {
    "hisaishi_castle_in_the_sky": 80,
    "radwimps_suzume": 80,
    "ru_yuan": 66,
    "christina_perri_a_thousand_years": 50,
    "haruhikage": 97,
    "rimsky_flight_of_the_bumblebee": 160,  # Vivace; no numeric mark — keep practice BPM
    "beethoven_moonlight_sonata": 44,
    "jay_chou_qing_tian": 68,
    "clayderman_reve_damour": 72,
    "sawano_call_of_silence": 60,
    "xiang_yun_duan": 70,
    "jue_bie_shu": 96,
}


def indent_xml(elem: ET.Element, level: int = 0) -> None:
    # Keep Audiveris formatting loose; only ensure readable new nodes.
    pass


def find_first_measure(root: ET.Element) -> ET.Element | None:
    for el in root.iter():
        if local(el.tag) == "measure":
            return el
    return None


def find_attributes(measure: ET.Element) -> ET.Element | None:
    for el in list(measure):
        if local(el.tag) == "attributes":
            return el
    return None


def ensure_time(attrs: ET.Element, beats: str, beat_type: str) -> bool:
    for el in attrs:
        if local(el.tag) == "time":
            return False
    time_el = ET.Element("time")
    b = ET.SubElement(time_el, "beats")
    b.text = beats
    bt = ET.SubElement(time_el, "beat-type")
    bt.text = beat_type
    # Insert after key if present, else after divisions
    insert_at = 0
    for i, el in enumerate(list(attrs)):
        t = local(el.tag)
        if t in ("divisions", "key"):
            insert_at = i + 1
    attrs.insert(insert_at, time_el)
    return True


def strip_existing_tempo(measure: ET.Element) -> None:
    for el in list(measure):
        if local(el.tag) == "direction":
            texts = " ".join(el.itertext())
            has_metro = any(local(c.tag) == "per-minute" for c in el.iter())
            has_sound_tempo = any(
                local(c.tag) == "sound" and "tempo" in c.attrib for c in el.iter()
            )
            if has_metro or has_sound_tempo:
                measure.remove(el)
        elif local(el.tag) == "sound" and "tempo" in el.attrib:
            measure.remove(el)


def insert_tempo(measure: ET.Element, bpm: int) -> None:
    strip_existing_tempo(measure)
    direction = ET.Element("direction", placement="above")
    dtype = ET.SubElement(direction, "direction-type")
    metro = ET.SubElement(dtype, "metronome")
    beat_unit = ET.SubElement(metro, "beat-unit")
    beat_unit.text = "quarter"
    per = ET.SubElement(metro, "per-minute")
    per.text = str(bpm)
    sound = ET.SubElement(direction, "sound", tempo=str(bpm))
    # Place after attributes/print
    idx = 0
    for i, el in enumerate(list(measure)):
        if local(el.tag) in ("print", "attributes"):
            idx = i + 1
    measure.insert(idx, direction)


def remove_moonlight_spurious_gsharp5(measure: ET.Element) -> bool:
    """Measure 1 OMR put a G#5 quarter in voice 1; PDF is triplets only (+pp)."""
    removed = False
    children = list(measure)
    i = 0
    while i < len(children):
        el = children[i]
        if local(el.tag) == "note":
            step = alter = octv = voice = None
            for c in el:
                t = local(c.tag)
                if t == "pitch":
                    for p in c:
                        pt = local(p.tag)
                        if pt == "step":
                            step = p.text
                        elif pt == "alter":
                            alter = p.text
                        elif pt == "octave":
                            octv = p.text
                elif t == "voice":
                    voice = c.text
            if step == "G" and alter == "1" and octv == "5" and voice == "1":
                measure.remove(el)
                removed = True
                # Also drop following backup of same duration if present
                if i + 1 < len(children) and local(children[i + 1].tag) == "backup":
                    measure.remove(children[i + 1])
                break
        i += 1
    return removed


def make_triplet_eighth(step: str, alter: str | None, octave: str, *, start: bool, stop: bool) -> ET.Element:
    note = ET.Element("note")
    pitch = ET.SubElement(note, "pitch")
    ET.SubElement(pitch, "step").text = step
    if alter is not None:
        ET.SubElement(pitch, "alter").text = alter
    ET.SubElement(pitch, "octave").text = octave
    ET.SubElement(note, "duration").text = "4"
    ET.SubElement(note, "voice").text = "1"
    ET.SubElement(note, "type").text = "eighth"
    tm = ET.SubElement(note, "time-modification")
    ET.SubElement(tm, "actual-notes").text = "3"
    ET.SubElement(tm, "normal-notes").text = "2"
    ET.SubElement(note, "stem").text = "up"
    ET.SubElement(note, "staff").text = "1"
    beam = ET.SubElement(note, "beam", number="1")
    if start:
        beam.text = "begin"
    elif stop:
        beam.text = "end"
    else:
        beam.text = "continue"
    if start or stop:
        notations = ET.SubElement(note, "notations")
        if start:
            ET.SubElement(notations, "tuplet", type="start", number="1", placement="above")
        if stop:
            ET.SubElement(notations, "tuplet", type="stop", number="1")
    return note


def fix_moonlight_plain_eighth_runs(root: ET.Element) -> int:
    """Convert staff1 eighth dur=6 runs (OMR dropped tuplet) into 3:2 triplets.

    Classic moonlight texture: 12 triplet-eighths per bar (=48 div). OMR often
    wrote duration=6 without time-modification (12×6=72 overflow).
    """
    fixed = 0
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        targets: list[ET.Element] = []
        for el in list(meas):
            if local(el.tag) != "note":
                continue
            staff = typ = dur = None
            chord = False
            has_tm = False
            for c in el:
                t = local(c.tag)
                if t == "staff":
                    staff = c.text
                elif t == "type":
                    typ = c.text
                elif t == "duration":
                    try:
                        dur = int(c.text or 0)
                    except ValueError:
                        dur = 0
                elif t == "chord":
                    chord = True
                elif t == "time-modification":
                    has_tm = True
            if staff == "1" and not chord and typ == "eighth" and dur == 6 and not has_tm:
                targets.append(el)
        if len(targets) < 3 or len(targets) % 3 != 0:
            continue
        # Only rewrite when the plain-eighth sum overfills a 4/4 bar (or exact 12).
        if len(targets) * 6 <= 48 and len(targets) != 12:
            continue
        for i, note in enumerate(targets):
            for c in note:
                if local(c.tag) == "duration":
                    c.text = "4"
            # remove old beam / notations we'll rebuild lightly
            for c in list(note):
                if local(c.tag) in ("time-modification", "beam"):
                    note.remove(c)
            tm = ET.Element("time-modification")
            ET.SubElement(tm, "actual-notes").text = "3"
            ET.SubElement(tm, "normal-notes").text = "2"
            # insert after type if possible
            insert_at = len(list(note))
            for j, c in enumerate(list(note)):
                if local(c.tag) == "type":
                    insert_at = j + 1
                    break
            note.insert(insert_at, tm)
            pos = i % 3
            beam = ET.Element("beam", number="1")
            beam.text = "begin" if pos == 0 else ("end" if pos == 2 else "continue")
            note.append(beam)
            # tuplet marks
            for c in list(note):
                if local(c.tag) == "notations":
                    for n in list(c):
                        if local(n.tag) == "tuplet":
                            c.remove(n)
            if pos in (0, 2):
                notations = None
                for c in note:
                    if local(c.tag) == "notations":
                        notations = c
                        break
                if notations is None:
                    notations = ET.SubElement(note, "notations")
                if pos == 0:
                    ET.SubElement(
                        notations, "tuplet", type="start", number="1", placement="above"
                    )
                else:
                    ET.SubElement(notations, "tuplet", type="stop", number="1")
        fixed += 1
    return fixed


def rewrite_moonlight_measure2_triplets(root: ET.Element) -> bool:
    """PDF: bar2 continues G#-C#-E eighth triplets over B octaves. OMR collapsed to plain 8ths."""
    target = None
    for el in root.iter():
        if local(el.tag) == "measure" and el.attrib.get("number") == "2":
            target = el
            break
    if target is None:
        return False

    # Keep LH notes (staff 2); rebuild RH.
    lh: list[ET.Element] = []
    for el in list(target):
        if local(el.tag) == "note":
            staff = None
            for c in el:
                if local(c.tag) == "staff":
                    staff = c.text
            if staff == "2":
                lh.append(copy.deepcopy(el))
        elif local(el.tag) == "backup":
            continue
        # drop old RH / directions clutter for clean rewrite
    target.clear()
    pattern = [("G", "1", "3"), ("C", "1", "4"), ("E", None, "4")]
    for _ in range(4):
        for i, (st, al, oc) in enumerate(pattern):
            target.append(
                make_triplet_eighth(st, al, oc, start=(i == 0), stop=(i == 2))
            )
    # backup full measure (divisions 12 → 48)
    backup = ET.Element("backup")
    ET.SubElement(backup, "duration").text = "48"
    target.append(backup)
    if not lh:
        # recreate B1+B2 whole
        for oc in ("1", "2"):
            n = ET.Element("note")
            if oc == "2":
                ET.SubElement(n, "chord")
            pitch = ET.SubElement(n, "pitch")
            ET.SubElement(pitch, "step").text = "B"
            ET.SubElement(pitch, "octave").text = oc
            ET.SubElement(n, "duration").text = "48"
            ET.SubElement(n, "voice").text = "5"
            ET.SubElement(n, "type").text = "whole"
            ET.SubElement(n, "staff").text = "2"
            target.append(n)
    else:
        for n in lh:
            target.append(n)
    return True


def patch_file(path: Path, score_id: str) -> list[str]:
    log: list[str] = []
    tree = ET.parse(path)
    root = tree.getroot()
    m1 = find_first_measure(root)
    if m1 is None:
        raise RuntimeError(f"no measure in {path}")

    bpm = PDF_TEMPO.get(score_id)
    if bpm is not None:
        insert_tempo(m1, bpm)
        log.append(f"tempo={bpm}")

    if score_id == "beethoven_moonlight_sonata":
        attrs = find_attributes(m1)
        if attrs is not None and ensure_time(attrs, "4", "4"):
            log.append("added time 4/4")
        if remove_moonlight_spurious_gsharp5(m1):
            log.append("removed spurious G#5 voice1")
        if rewrite_moonlight_measure2_triplets(root):
            log.append("rewrote measure2 RH as triplets")
        nfix = fix_moonlight_plain_eighth_runs(root)
        if nfix:
            log.append(f"triplet-fixed measures={nfix}")

    tree.write(path, encoding="UTF-8", xml_declaration=True)
    return log


def update_catalog_bpm() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    changed = 0
    for s in data.get("songs") or []:
        sid = s.get("id")
        if sid in PDF_TEMPO and int(s.get("bpm") or 0) != PDF_TEMPO[sid]:
            s["bpm"] = PDF_TEMPO[sid]
            changed += 1
            # keep omrDraft; refresh description hint
            desc = str(s.get("description") or "")
            if "PDF metronome" not in desc:
                s["description"] = (
                    desc.rstrip(".")
                    + f". PDF metronome/BPM proofread 2026-08-04 → {PDF_TEMPO[sid]}."
                )
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"catalog bpm updates: {changed}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id")
    ap.add_argument("--all-omr", action="store_true")
    args = ap.parse_args()
    ids = list(PDF_TEMPO) if args.all_omr else ([args.id] if args.id else [])
    if not ids:
        print("Provide --id or --all-omr", file=sys.stderr)
        return 2

    for sid in ids:
        src = ASSETS_XML / f"{sid}.musicxml"
        if not src.is_file():
            print(f"MISSING {src}", file=sys.stderr)
            return 1
        log = patch_file(src, sid)
        # mirror to third_party source
        dst = THIRD_XML / f"{sid}.musicxml"
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(src.read_bytes())
        print(f"OK {sid}: {', '.join(log) if log else '(no changes)'}")

    update_catalog_bpm()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
