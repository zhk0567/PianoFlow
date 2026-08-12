# -*- coding: utf-8 -*-
"""Generate open/mid/end PDF crops + MusicXML measure dumps for OMR proofreading."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from musicxml_to_score import load_xml_root, local, parse_musicxml  # noqa: E402

OUT = REPO / "docs" / "omr_audit" / "_spotcheck"
PDF_DIR = REPO / "third_party" / "scores_pdf"
XML_DIR = REPO / "assets" / "scores" / "musicxml"
CATALOG = REPO / "assets" / "scores" / "catalog.json"

# Audiveris staff OMR (not jianpu skeleton)
STAFF_OMR = [
    "hisaishi_castle_in_the_sky",
    "radwimps_suzume",
    "ru_yuan",
    "christina_perri_a_thousand_years",
    "haruhikage",
    "rimsky_flight_of_the_bumblebee",
    "beethoven_moonlight_sonata",
    "jay_chou_qing_tian",
    "clayderman_reve_damour",
    "sawano_call_of_silence",
    "xiang_yun_duan",
    "jue_bie_shu",
    "rush_e",
]

MIDI_NAME = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_label(m: int) -> str:
    return f"{MIDI_NAME[m % 12]}{(m // 12) - 1}"


def measures_from_notes(notes: list[dict], beats_per_bar: float = 4.0) -> dict[int, list[dict]]:
    bars: dict[int, list[dict]] = {}
    for n in notes:
        bar = int(n["start"] // beats_per_bar) + 1
        bars.setdefault(bar, []).append(n)
    return bars


def dump_bars(notes: list[dict], bar_ids: list[int], beats_per_bar: float = 4.0) -> str:
    bars = measures_from_notes(notes, beats_per_bar)
    lines = []
    for b in bar_ids:
        chunk = bars.get(b, [])
        if not chunk:
            lines.append(f"m{b}: (empty)")
            continue
        rh = [midi_label(n["midi"]) for n in chunk if n["hand"] == "right"]
        lh = [midi_label(n["midi"]) for n in chunk if n["hand"] == "left"]
        lines.append(f"m{b}: RH[{' '.join(rh)}] LH[{' '.join(lh)}]")
    return "\n".join(lines)


def render_pdf_pages(score_id: str, pdf: Path, dest: Path) -> list[Path]:
    import fitz

    dest.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(str(pdf))
    n = len(doc)
    idxs = sorted({0, n // 2, n - 1})
    out_paths = []
    for i in idxs:
        page = doc[i]
        pix = page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5))
        p = dest / f"{score_id}_pdf_p{i+1}.png"
        pix.save(str(p))
        out_paths.append(p)
    doc.close()
    return out_paths


def process_one(score_id: str) -> Path:
    pdf = PDF_DIR / f"{score_id}.pdf"
    xml = XML_DIR / f"{score_id}.musicxml"
    out = OUT / score_id
    out.mkdir(parents=True, exist_ok=True)

    root = load_xml_root(xml)
    parsed = parse_musicxml(root)
    notes = parsed["notes"]
    meta = parsed
    beats = float(parsed.get("timeSignature", [4, 4])[0] or 4)
    if isinstance(parsed.get("timeSignature"), list) and len(parsed["timeSignature"]) >= 1:
        try:
            beats = float(parsed["timeSignature"][0])
        except (TypeError, ValueError):
            beats = 4.0
    # fallback from attributes
    for el in root.iter():
        if local(el.tag) == "beats":
            try:
                beats = float(el.text or 4)
            except ValueError:
                pass
            break

    max_bar = max((int(n["start"] // beats) + 1 for n in notes), default=1)
    mid = max(1, max_bar // 2)
    open_bars = list(range(1, min(9, max_bar + 1)))
    mid_bars = list(range(mid, min(mid + 8, max_bar + 1)))
    end_bars = list(range(max(1, max_bar - 7), max_bar + 1))

    report = []
    report.append(f"# Spotcheck — `{score_id}`")
    report.append("")
    report.append(f"- notes: {len(notes)}")
    report.append(f"- bpm: {meta.get('bpm')}")
    report.append(f"- key: {meta.get('keySignature')}")
    report.append(f"- bars≈{max_bar} (assume {int(beats)}/4)")
    report.append("")
    report.append("## Opening")
    report.append("```")
    report.append(dump_bars(notes, open_bars, beats))
    report.append("```")
    report.append("")
    report.append("## Mid")
    report.append("```")
    report.append(dump_bars(notes, mid_bars, beats))
    report.append("```")
    report.append("")
    report.append("## Ending")
    report.append("```")
    report.append(dump_bars(notes, end_bars, beats))
    report.append("```")
    report.append("")

    if pdf.is_file():
        paths = render_pdf_pages(score_id, pdf, out)
        report.append("## PDF crops")
        for p in paths:
            report.append(f"- `{p.relative_to(REPO)}`")
    else:
        report.append("## PDF crops")
        report.append("- (missing PDF)")

    md = out / "spotcheck.md"
    md.write_text("\n".join(report) + "\n", encoding="utf-8")
    return md


def main() -> None:
    ids = STAFF_OMR
    if len(sys.argv) > 1:
        ids = sys.argv[1:]
    for sid in ids:
        try:
            p = process_one(sid)
            print("OK", sid, "->", p)
        except Exception as e:
            print("FAIL", sid, e)


if __name__ == "__main__":
    main()
