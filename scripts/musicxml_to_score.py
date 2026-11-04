#!/usr/bin/env python3
"""Convert MusicXML (partwise) to PianoFlow SongScore JSON.

Usage:
  python scripts/musicxml_to_score.py --id pachelbel_canon_d
  python scripts/musicxml_to_score.py --id pachelbel_canon_d --update-catalog
  python scripts/musicxml_to_score.py --all --update-catalog
  python scripts/musicxml_to_score.py --id new_id --input path.musicxml --update-catalog \\
      --title "Title" --artist "Composer" --genre Classical --difficulty 3
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
SRC_DIR = REPO / "third_party" / "scores_musicxml"
OUT_DIR = REPO / "assets" / "scores"
ASSET_XML_DIR = OUT_DIR / "musicxml"
CATALOG = OUT_DIR / "catalog.json"

MIDI_MIN, MIDI_MAX = 21, 108

STEP_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# Default catalog metadata when --update-catalog and id is known.
# Note: several keys below are *presets not currently in catalog.json*
# (bach_anh*, burg_op100_2, clementi_op36_1). --all uses catalog ids only.
CATALOG_META: dict[str, dict] = {
    "bach_anh114": {
        "title": "G大调小步舞曲（BWV Anh.114）",
        "artist": "巴赫",
        "genre": "Classical",
        "difficulty": 2,
        "description": "《安娜·玛格达勒娜笔记本》正式教材谱，MusicXML 导入。",
        "scoreKind": "formal",
    },
    "bach_anh115": {
        "title": "G小调小步舞曲（BWV Anh.115）",
        "artist": "巴赫",
        "genre": "Classical",
        "difficulty": 2,
        "description": "《安娜·玛格达勒娜笔记本》正式教材谱，MusicXML 导入。",
        "scoreKind": "formal",
    },
    "bach_anh126": {
        "title": "穆塞特（BWV Anh.126）",
        "artist": "巴赫",
        "genre": "Classical",
        "difficulty": 2,
        "description": "《安娜·玛格达勒娜笔记本》穆塞特，MusicXML 导入。",
        "scoreKind": "formal",
    },
    "burg_op100_2": {
        "title": "阿拉伯风格曲（Op.100 No.2）",
        "artist": "布格缪勒",
        "genre": "Classical",
        "difficulty": 3,
        "description": "《练习曲25首》Op.100 No.2，MusicXML 导入。",
        "scoreKind": "formal",
    },
    "clementi_op36_1": {
        "title": "小奏鸣曲 Op.36 No.1（第一乐章）",
        "artist": "克莱门蒂",
        "genre": "Classical",
        "difficulty": 3,
        "description": "Op.36 No.1 第一乐章，MusicXML 导入。",
        "scoreKind": "formal",
    },
    "pachelbel_canon_d": {
        "title": "Canon in D",
        "artist": "J. Pachelbel / Arranged by Ian Cantor",
        "genre": "Classical",
        "difficulty": 2,
        "description": "Cantorion Easy Piano (Ian Cantor), note-accurate to the PDF. CC-BY-SA 2.0 — www.cantorion.org; engraving LilyPond 2.11.38.",
        "scoreKind": "formal",
    },
    "fur_elise_woo59": {
        "title": "Fur Elise",
        "artist": "Ludwig van Beethoven",
        "genre": "Classical",
        "difficulty": 3,
        "description": "Clavierstuck in A Minor - WoO 59. Public Domain.",
        "scoreKind": "formal",
    },
    # Built via encode_megalovania.py (PDF transcription; never MIDI). See README_SOURCE.txt.
    "toby_fox_megalovania": {
        "title": "Megalovania",
        "artist": "Toby Fox",
        "genre": "Game",
        "difficulty": 4,
        "description": (
            "Undertale — Toby Fox. Piano arrangement from user PDF "
            "(q=120, D minor, 8vb grand staff). © Toby Fox; local practice only — "
            "not Public Domain. Formal MusicXML (not MIDI)."
        ),
        "scoreKind": "formal",
    },
}

BATCH_IDS = list(CATALOG_META.keys())


def catalog_score_ids(catalog_path: Path = CATALOG) -> list[str]:
    """Ids from catalog.json (source of truth for --all). Falls back to BATCH_IDS."""
    if not catalog_path.is_file():
        return list(BATCH_IDS)
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    ids = [str(s["id"]) for s in (data.get("songs") or []) if s.get("id")]
    # Stable order; keep BATCH_IDS first for known formal presets when present.
    preferred = [i for i in BATCH_IDS if i in ids]
    rest = sorted(i for i in ids if i not in preferred)
    return preferred + rest


def local(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def find_child(el: ET.Element, name: str) -> ET.Element | None:
    for c in el:
        if local(c.tag) == name:
            return c
    return None


def find_text(el: ET.Element, name: str, default: str | None = None) -> str | None:
    c = find_child(el, name)
    if c is None or c.text is None:
        return default
    return c.text.strip()


def iter_named(el: ET.Element, name: str):
    for c in el:
        if local(c.tag) == name:
            yield c


def pitch_to_midi(pitch_el: ET.Element) -> int:
    step = find_text(pitch_el, "step", "C") or "C"
    octave = int(find_text(pitch_el, "octave", "4") or "4")
    alter_t = find_text(pitch_el, "alter")
    alter = float(alter_t) if alter_t is not None else 0.0
    pc = STEP_PC.get(step.upper(), 0) + int(round(alter))
    return (octave + 1) * 12 + pc


def fifths_to_key_signature(fifths: int) -> int:
    # PianoFlow: positive = sharps, negative = flats (same as MusicXML fifths).
    return int(fifths)


def resolve_input(score_id: str, explicit: Path | None) -> Path:
    if explicit is not None:
        if not explicit.exists():
            raise FileNotFoundError(f"Input not found: {explicit}")
        return explicit
    candidates = [
        SRC_DIR / f"{score_id}.musicxml",
        SRC_DIR / f"{score_id}.xml",
        SRC_DIR / f"{score_id}.mxl",
        SRC_DIR / f"{score_id}.MusicXML",
    ]
    for p in candidates:
        if p.exists():
            return p
    raise FileNotFoundError(
        f"Missing MusicXML for '{score_id}'. Place one of:\n"
        + "\n".join(f"  - {c}" for c in candidates)
    )


def load_xml_root(path: Path) -> ET.Element:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path, "r") as zf:
            names = [
                n
                for n in zf.namelist()
                if n.lower().endswith((".xml", ".musicxml"))
                and not n.startswith("META-INF")
            ]
            if not names:
                raise ValueError(f"No MusicXML inside {path}")
            # Prefer container root; else first xml
            data = zf.read(names[0])
        return ET.fromstring(data)
    return ET.parse(path).getroot()


def parse_musicxml(root: ET.Element) -> dict:
    if local(root.tag) != "score-partwise":
        # Accept with namespace
        if "score-partwise" not in local(root.tag):
            raise ValueError("Only MusicXML score-partwise is supported")

    title = "Untitled"
    movement = find_child(root, "movement-title")
    if movement is not None and movement.text:
        title = movement.text.strip()
    else:
        work = find_child(root, "work")
        if work is not None:
            wt = find_text(work, "work-title")
            if wt:
                title = wt

    bpm = 100
    direction_tempo = None

    notes_out: list[dict] = []
    warnings: list[str] = []

    time_num, time_den = 4, 4
    key_sig = 0
    divisions = 1
    # Staff number → clef-octave-change (parsed for future tooling; not applied).
    # MusicXML <pitch> is concert/sounding. Verovio uses clef-octave-change to
    # displace notation to the written staff position (8vb etc.). Applying
    # `+ 12 * clef_octave` here double-transposes vs the orange playhead and
    # was the root cause of staff↔audio octave mismatch on Megalovania.
    clef_octave: dict[int, int] = {1: 0, 2: 0}

    # Absolute time in quarter-note beats for each voice+staff cursor.
    # MusicXML backup/forward adjust the cursor within a measure.
    parts = list(iter_named(root, "part"))
    multi_part_piano = len(parts) == 2

    for part_index, part in enumerate(parts):
        abs_beat = 0.0  # start of current measure in score
        measure_cursor = 0.0  # within-measure position in divisions units
        last_onset = 0.0

        for measure in iter_named(part, "measure"):
            measure_cursor = 0.0
            measure_max = 0.0
            last_onset = 0.0

            for el in measure:
                tag = local(el.tag)

                if tag == "attributes":
                    div_t = find_text(el, "divisions")
                    if div_t:
                        divisions = int(div_t)
                    time_el = find_child(el, "time")
                    if time_el is not None:
                        beats = find_text(time_el, "beats")
                        beat_type = find_text(time_el, "beat-type")
                        if beats:
                            time_num = int(beats)
                        if beat_type:
                            time_den = int(beat_type)
                    key_el = find_child(el, "key")
                    if key_el is not None:
                        fifths = find_text(key_el, "fifths")
                        if fifths is not None:
                            key_sig = fifths_to_key_signature(int(fifths))
                    for clef_el in iter_named(el, "clef"):
                        num_t = clef_el.attrib.get("number", "1")
                        try:
                            staff_n = int(num_t)
                        except ValueError:
                            staff_n = 1
                        ch = find_text(clef_el, "clef-octave-change")
                        if ch is not None:
                            try:
                                clef_octave[staff_n] = int(ch)
                            except ValueError:
                                pass
                    continue

                if tag == "direction":
                    sound = find_child(el, "sound")
                    if sound is not None and "tempo" in sound.attrib:
                        try:
                            direction_tempo = int(round(float(sound.attrib["tempo"])))
                        except ValueError:
                            pass
                    for dt in el.iter():
                        if local(dt.tag) == "sound" and "tempo" in dt.attrib:
                            try:
                                direction_tempo = int(
                                    round(float(dt.attrib["tempo"]))
                                )
                            except ValueError:
                                pass
                    continue

                if tag == "backup":
                    dur = int(find_text(el, "duration", "0") or "0")
                    measure_cursor = max(0.0, measure_cursor - dur)
                    continue

                if tag == "forward":
                    dur = int(find_text(el, "duration", "0") or "0")
                    measure_cursor += dur
                    measure_max = max(measure_max, measure_cursor)
                    continue

                if tag != "note":
                    continue

                # Grace notes: skip
                if find_child(el, "grace") is not None:
                    continue

                is_chord = find_child(el, "chord") is not None
                is_rest = find_child(el, "rest") is not None
                dur_div = int(find_text(el, "duration", "0") or "0")
                if dur_div <= 0 and not is_chord:
                    continue

                staff_t = find_text(el, "staff", "1") or "1"
                staff = int(staff_t)
                if multi_part_piano and staff <= 1:
                    # Separate RH/LH parts (no <staff>2) — Mutopia / music21 MIDI.
                    hand = "left" if part_index >= 1 else "right"
                else:
                    hand = "left" if staff >= 2 else "right"

                if is_chord:
                    onset_div = last_onset
                else:
                    onset_div = measure_cursor
                    last_onset = onset_div
                    measure_cursor += dur_div
                    measure_max = max(measure_max, measure_cursor)

                if is_rest:
                    continue

                pitch_el = find_child(el, "pitch")
                if pitch_el is None:
                    continue

                midi = pitch_to_midi(pitch_el)
                if midi < MIDI_MIN or midi > MIDI_MAX:
                    warnings.append(f"skip out-of-range midi={midi}")
                    continue

                start = abs_beat + onset_div / float(divisions)
                duration = dur_div / float(divisions)
                if duration <= 0:
                    continue

                # MusicXML <tie type="start|stop"> — merge for practice JSON so a
                # tied continuation is not a second wait-hit / waterfall onset.
                tie_start = False
                tie_stop = False
                for child in el:
                    if local(child.tag) != "tie":
                        continue
                    t = (child.attrib.get("type") or "").lower()
                    if t == "start":
                        tie_start = True
                    elif t == "stop":
                        tie_stop = True

                notes_out.append(
                    {
                        "midi": midi,
                        "start": round(start, 6),
                        "duration": round(duration, 6),
                        "hand": hand,
                        "tieStart": tie_start,
                        "tieStop": tie_stop,
                    }
                )

            # Advance absolute time by written measure length (max cursor / divisions)
            # Prefer time signature length when measure is empty of notes.
            # For multi-voice piano OMR, written cursor can exceed the bar (bad backups);
            # clamp to the notated meter so downstream beats stay on the bar grid.
            beats_per_measure = time_num * (4.0 / time_den)
            written = measure_max / float(divisions) if divisions else 0.0
            if written > 0.01:
                # Allow short pickups; do not let a bloated voice cursor stretch the bar.
                if beats_per_measure > 0 and written > beats_per_measure * 1.01:
                    written = beats_per_measure
                abs_beat += written
            else:
                abs_beat += beats_per_measure

    if direction_tempo:
        bpm = direction_tempo

    notes_out.sort(key=lambda n: (n["start"], n["midi"]))

    # Deduplicate exact overlaps
    deduped: list[dict] = []
    seen: set[tuple] = set()
    for n in notes_out:
        key = (
            n["midi"],
            n["start"],
            n["duration"],
            n["hand"],
            n.get("tieStart"),
            n.get("tieStop"),
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(n)

    # Merge tied notes: stop extends the open start (same midi+hand).
    merged: list[dict] = []
    open_tie: dict[tuple[int, str], int] = {}
    for n in deduped:
        key = (int(n["midi"]), str(n["hand"]))
        tie_stop = bool(n.pop("tieStop", False))
        tie_start = bool(n.pop("tieStart", False))
        if tie_stop and key in open_tie:
            i = open_tie[key]
            end = float(n["start"]) + float(n["duration"])
            start0 = float(merged[i]["start"])
            merged[i]["duration"] = round(end - start0, 6)
            if tie_start:
                open_tie[key] = i
            else:
                open_tie.pop(key, None)
            continue
        merged.append(
            {
                "midi": n["midi"],
                "start": n["start"],
                "duration": n["duration"],
                "hand": n["hand"],
            }
        )
        if tie_start:
            open_tie[key] = len(merged) - 1

    return {
        "title": title,
        "bpm": bpm,
        "tempoFromXml": bool(direction_tempo),
        "timeNum": time_num,
        "timeDen": time_den,
        "keySignature": key_sig,
        "notes": merged,
        "warnings": warnings,
    }


def sync_packaged_musicxml(score_id: str, source_xml: Path) -> Path:
    """Copy notation XML into assets/scores/musicxml for Verovio packaging."""
    ASSET_XML_DIR.mkdir(parents=True, exist_ok=True)
    dest = ASSET_XML_DIR / f"{score_id}.musicxml"
    if source_xml.resolve() != dest.resolve():
        shutil.copy2(source_xml, dest)
    print(f"[{score_id}] synced {dest}")
    return dest


def install_source_musicxml(score_id: str, source_xml: Path) -> Path:
    """Ensure canonical third_party MusicXML exists (prefer .musicxml)."""
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    dest = SRC_DIR / f"{score_id}.musicxml"
    if source_xml.suffix.lower() == ".mxl":
        # Expand first XML entry to plain MusicXML for stable tooling.
        with zipfile.ZipFile(source_xml, "r") as zf:
            names = [
                n
                for n in zf.namelist()
                if n.lower().endswith((".xml", ".musicxml"))
                and not n.startswith("META-INF")
            ]
            if not names:
                raise ValueError(f"No MusicXML inside {source_xml}")
            dest.write_bytes(zf.read(names[0]))
    elif source_xml.resolve() != dest.resolve():
        shutil.copy2(source_xml, dest)
    return dest


def resolve_catalog_meta(
    score_id: str,
    *,
    parsed: dict,
    overrides: dict | None,
    existing: dict | None = None,
) -> dict | None:
    """Merge existing catalog → CATALOG_META → CLI overrides.

    Existing catalog wins over CATALOG_META defaults so re-running convert on
    OMR drafts does not rewrite scoreKind to simplified / wipe descriptions.
    """
    base: dict = {}
    if existing:
        for k in (
            "title",
            "artist",
            "genre",
            "difficulty",
            "description",
            "scoreKind",
            "bpm",
        ):
            if existing.get(k) is not None and existing.get(k) != "":
                base[k] = existing[k]
    for k, v in CATALOG_META.get(score_id, {}).items():
        base.setdefault(k, v)
    ov = overrides or {}
    for k, v in ov.items():
        if v is not None and v != "":
            base[k] = v
    title = base.get("title") or parsed.get("title") or score_id
    artist = base.get("artist") or "Unknown"
    if score_id not in CATALOG_META and not ov.get("title") and not base.get("title"):
        print(
            f"[catalog] no preset meta for {score_id}; "
            f"using title={title!r} artist={artist!r} (pass --title/--artist to customize)"
        )
    kind = base.get("scoreKind") or "simplified"
    kind_zh = {
        "formal": "正式谱",
        "omrDraft": "OMR草稿",
        "simplified": "简编谱",
        "userImport": "自导入",
    }.get(kind, kind)
    default_desc = f"MusicXML 导入（{kind_zh}；{score_id}）。"
    return {
        "title": title,
        "artist": artist,
        "genre": base.get("genre") or "Classical",
        "difficulty": int(base.get("difficulty") or 3),
        "description": base.get("description") or default_desc,
        "scoreKind": kind,
        "bpm": base.get("bpm"),
    }


def write_score(
    score_id: str,
    parsed: dict,
    title_override: str | None = None,
    *,
    out_dir: Path | None = None,
) -> Path:
    dest_dir = out_dir or OUT_DIR
    dest_dir.mkdir(parents=True, exist_ok=True)
    meta = CATALOG_META.get(score_id, {})
    title = title_override or meta.get("title") or parsed["title"]
    payload = {
        "id": score_id,
        "title": title,
        "bpm": parsed["bpm"],
        "timeSignature": {"num": parsed["timeNum"], "den": parsed["timeDen"]},
        "keySignature": parsed["keySignature"],
        "notes": parsed["notes"],
    }
    out = dest_dir / f"{score_id}.json"
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return out


def _existing_catalog_entry(score_id: str) -> dict | None:
    if not CATALOG.exists():
        return None
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    for s in data.get("songs") or []:
        if s.get("id") == score_id:
            return s
    return None


def _apply_preserved_bpm(score_id: str, parsed: dict) -> None:
    """Keep hand-tuned BPM when MusicXML has no <sound tempo> (common for OMR)."""
    if parsed.get("tempoFromXml"):
        return
    existing = _existing_catalog_entry(score_id)
    if not existing or existing.get("bpm") is None:
        json_path = OUT_DIR / f"{score_id}.json"
        if json_path.is_file():
            try:
                prev = json.loads(json_path.read_text(encoding="utf-8"))
                if prev.get("bpm") is not None:
                    old = int(prev["bpm"])
                    if old != int(parsed["bpm"]):
                        print(
                            f"[{score_id}] preserving json bpm={old} "
                            f"(MusicXML had no tempo; parser default={parsed['bpm']})"
                        )
                        parsed["bpm"] = old
                return
            except (OSError, json.JSONDecodeError, TypeError, ValueError):
                return
        return
    old = int(existing["bpm"])
    if old != int(parsed["bpm"]):
        print(
            f"[{score_id}] preserving catalog bpm={old} "
            f"(MusicXML had no tempo; parser default={parsed['bpm']})"
        )
        parsed["bpm"] = old


def update_catalog(
    score_id: str,
    parsed: dict,
    json_path: Path,
    *,
    meta_overrides: dict | None = None,
) -> None:
    existing = _existing_catalog_entry(score_id)
    meta = resolve_catalog_meta(
        score_id,
        parsed=parsed,
        overrides=meta_overrides,
        existing=existing,
    )
    if meta is None:
        print(f"[catalog] skip auto-update for {score_id}")
        return
    if not CATALOG.exists():
        raise FileNotFoundError(CATALOG)

    kind = meta.get("scoreKind", "formal")
    try:
        from catalog_score_kind_guard import refuse_formal_import  # noqa: WPS433

        refuse = refuse_formal_import(
            source=json_path,
            score_kind=str(kind),
            score_id=score_id,
        )
        if refuse:
            raise SystemExit(f"[catalog] {refuse}")
    except ImportError:
        pass

    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    songs = data.get("songs", [])
    duration_beats = 0.0
    for n in parsed["notes"]:
        duration_beats = max(duration_beats, n["start"] + n["duration"])
    bpm = int(parsed["bpm"])
    duration_hint = max(8, int(round(duration_beats * 60 / max(bpm, 1))))

    entry = {
        "id": score_id,
        "title": meta["title"],
        "artist": meta["artist"],
        "genre": meta["genre"],
        "difficulty": meta["difficulty"],
        "bpm": bpm,
        "asset": f"assets/scores/{score_id}.json",
        "description": meta["description"],
        "durationHint": duration_hint,
        "scoreKind": kind,
    }

    replaced = False
    for i, s in enumerate(songs):
        if s.get("id") == score_id:
            songs[i] = entry
            replaced = True
            break
    if not replaced:
        songs.append(entry)
    data["songs"] = songs
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[catalog] {'updated' if replaced else 'added'} {score_id} scoreKind={kind}")


def update_user_catalog(
    user_dir: Path,
    score_id: str,
    parsed: dict,
    json_path: Path,
    meta_overrides: dict | None = None,
) -> None:
    """Upsert ApplicationDocuments-style user_catalog.json (never formal)."""
    catalog_path = user_dir / "user_catalog.json"
    if catalog_path.exists():
        data = json.loads(catalog_path.read_text(encoding="utf-8"))
    else:
        data = {"songs": []}
    songs = data.get("songs") or []
    existing = next((s for s in songs if s.get("id") == score_id), None)
    meta = resolve_catalog_meta(
        score_id,
        parsed=parsed,
        overrides={
            **(meta_overrides or {}),
            "scoreKind": "userImport",
        },
        existing=existing,
    )
    if meta is None:
        meta = {
            "title": parsed.get("title") or score_id,
            "artist": "自导入",
            "genre": "Classical",
            "difficulty": 3,
            "description": "工坊 MusicXML 自导入（非正式谱）。",
            "scoreKind": "userImport",
        }
    meta["scoreKind"] = "userImport"
    duration_beats = 0.0
    for n in parsed["notes"]:
        duration_beats = max(duration_beats, n["start"] + n["duration"])
    bpm = int(parsed["bpm"])
    duration_hint = max(8, int(round(duration_beats * 60 / max(bpm, 1))))
    entry = {
        "id": score_id,
        "title": meta["title"],
        "artist": meta["artist"],
        "genre": meta["genre"],
        "difficulty": int(meta["difficulty"]),
        "bpm": bpm,
        "asset": str(json_path.resolve()),
        "description": meta.get("description")
        or "工坊 MusicXML 自导入（非正式谱）。",
        "durationHint": duration_hint,
        "scoreKind": "userImport",
    }
    replaced = False
    for i, s in enumerate(songs):
        if s.get("id") == score_id:
            songs[i] = entry
            replaced = True
            break
    if not replaced:
        songs.append(entry)
    data["songs"] = songs
    catalog_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"[user-catalog] {'updated' if replaced else 'added'} {score_id} scoreKind=userImport")


def convert_one(
    score_id: str,
    *,
    input_path: Path | None,
    update_catalog_flag: bool,
    meta_overrides: dict | None = None,
    sync_assets: bool = True,
    user_import_dir: Path | None = None,
) -> int:
    path = resolve_input(score_id, input_path)
    print(f"[{score_id}] reading {path}")
    if user_import_dir is None:
        # Always land on third_party/{id}.musicxml (expands .mxl).
        path = install_source_musicxml(score_id, path)
        print(f"[{score_id}] source {path}")
    root = load_xml_root(path)
    parsed = parse_musicxml(root)
    if not parsed["notes"]:
        print(f"[{score_id}] ERROR: no notes parsed", file=sys.stderr)
        return 1
    _apply_preserved_bpm(score_id, parsed)
    title_ov = (meta_overrides or {}).get("title")

    if user_import_dir is not None:
        user_dir = Path(user_import_dir)
        user_dir.mkdir(parents=True, exist_ok=True)
        xml_dir = user_dir / "musicxml"
        xml_dir.mkdir(parents=True, exist_ok=True)
        # Expand mxl into user musicxml folder
        src = path
        if src.suffix.lower() == ".mxl":
            # reuse install logic into temp then copy
            src = install_source_musicxml(score_id, src)
        dest_xml = xml_dir / f"{score_id}.musicxml"
        shutil.copy2(src, dest_xml)
        overrides = dict(meta_overrides or {})
        overrides["scoreKind"] = "userImport"
        out = write_score(
            score_id, parsed, title_override=title_ov, out_dir=user_dir
        )
        update_user_catalog(user_dir, score_id, parsed, out, meta_overrides=overrides)
        print(
            f"[{score_id}] user-import wrote {out}  notes={len(parsed['notes'])}  "
            f"bpm={parsed['bpm']}  scoreKind=userImport"
        )
        return 0

    out = write_score(score_id, parsed, title_override=title_ov)
    print(
        f"[{score_id}] wrote {out}  notes={len(parsed['notes'])}  "
        f"bpm={parsed['bpm']}  {parsed['timeNum']}/{parsed['timeDen']}  "
        f"key={parsed['keySignature']}"
    )
    if sync_assets:
        sync_packaged_musicxml(score_id, path)
    if parsed["warnings"]:
        uniq = sorted(set(parsed["warnings"]))
        print(f"[{score_id}] warnings ({len(uniq)}):")
        for w in uniq[:20]:
            print(f"  - {w}")
    if update_catalog_flag:
        update_catalog(score_id, parsed, out, meta_overrides=meta_overrides)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="MusicXML → PianoFlow score JSON")
    ap.add_argument("--id", help="Score id (e.g. pachelbel_canon_d)")
    ap.add_argument("--input", type=Path, help="Explicit MusicXML/MXL path")
    ap.add_argument(
        "--all",
        action="store_true",
        help="Convert every id in assets/scores/catalog.json (not only CATALOG_META)",
    )
    ap.add_argument(
        "--update-catalog",
        action="store_true",
        help="Upsert entry in assets/scores/catalog.json",
    )
    ap.add_argument("--title", help="Catalog title override")
    ap.add_argument("--artist", help="Catalog artist override")
    ap.add_argument(
        "--genre",
        choices=("Classical", "Anime", "Pop", "Game"),
        help="Catalog genre override (UI maps to 古典/动画/流行/游戏)",
    )
    ap.add_argument(
        "--difficulty",
        type=int,
        choices=(1, 2, 3, 4, 5),
        help="Catalog difficulty 1-5 (5=极难)",
    )
    ap.add_argument("--description", help="Catalog description override")
    ap.add_argument(
        "--score-kind",
        dest="score_kind",
        choices=("formal", "simplified", "omrDraft", "userImport"),
        help="Catalog scoreKind (use omrDraft for unproofread PDF→OMR imports)",
    )
    ap.add_argument(
        "--user-import-dir",
        type=Path,
        help="Write JSON + user_catalog.json here (forces scoreKind=userImport; no assets sync)",
    )
    ap.add_argument(
        "--no-sync-assets",
        action="store_true",
        help="Do not copy MusicXML into assets/scores/musicxml/",
    )
    args = ap.parse_args()

    if args.user_import_dir is not None and args.score_kind == "formal":
        raise SystemExit("[user-import] refusing scoreKind=formal for self-import")

    if args.all:
        ids = catalog_score_ids()
        print(f"[batch] --all catalog ids={len(ids)}")
    elif args.id:
        ids = [args.id]
    else:
        ap.error("Provide --id or --all")
        return 2

    meta_overrides = {
        "title": args.title,
        "artist": args.artist,
        "genre": args.genre,
        "difficulty": args.difficulty,
        "description": args.description,
        "scoreKind": (
            "userImport" if args.user_import_dir is not None else args.score_kind
        ),
    }

    SRC_DIR.mkdir(parents=True, exist_ok=True)
    missing: list[str] = []
    rc = 0
    for sid in ids:
        try:
            inp = args.input if (args.id and not args.all) else None
            code = convert_one(
                sid,
                input_path=inp,
                update_catalog_flag=args.update_catalog,
                meta_overrides=meta_overrides,
                sync_assets=not args.no_sync_assets and args.user_import_dir is None,
                user_import_dir=args.user_import_dir,
            )
            rc = rc or code
        except FileNotFoundError as e:
            print(str(e), file=sys.stderr)
            missing.append(sid)
            rc = 1
        except Exception as e:
            print(f"[{sid}] ERROR: {e}", file=sys.stderr)
            rc = 1

    if missing:
        print("\nStill missing MusicXML for:", ", ".join(missing))
        print(f"Place files under: {SRC_DIR}")
        print("See docs/曲谱导入SOP.md for the fast accurate import path.")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
