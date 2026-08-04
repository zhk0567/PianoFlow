#!/usr/bin/env python3
"""OMR / score accuracy audit — does NOT promote to formal.

Compares packaged MusicXML ↔ practice JSON, flags conversion drift and
common OMR-risk signals (missing key/tempo, clef-octave-change, huge leaps,
odd durations). Writes a markdown report for human PDF proofreading.

Usage (PowerShell, from repo root):
  python .\\scripts\\omr_audit_score.py --id hisaishi_castle_in_the_sky
  python .\\scripts\\omr_audit_score.py --all-omr
  python .\\scripts\\omr_audit_score.py --all-omr --fail-on-drift

Exit 0 = ok (or report-only default). With --fail-on-drift, exit 1 if any
JSON ≢ MusicXML reparse (conversion drift). Never promotes to formal.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from musicxml_to_score import (  # noqa: E402
    load_xml_root,
    local,
    parse_musicxml,
)

CATALOG = REPO / "assets" / "scores" / "catalog.json"
SCORES = REPO / "assets" / "scores"
MUSICXML = SCORES / "musicxml"
PDF_DIR = REPO / "third_party" / "scores_pdf"
DEFAULT_OUT = REPO / "docs" / "omr_audit"


def catalog_songs() -> list[dict]:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return list(data.get("songs") or [])


def find_pdf(score_id: str) -> Path | None:
    for name in (f"{score_id}.pdf",):
        p = PDF_DIR / name
        if p.is_file():
            return p
    return None


def xml_structure_flags(root: ET.Element) -> dict:
    clefs: list[tuple] = []
    keys: list[str | None] = []
    times: list[tuple] = []
    oct_changes: list[str] = []
    tempos: list[float] = []
    for el in root.iter():
        tag = local(el.tag)
        if tag == "clef":
            sign = line = ch = None
            for c in el:
                ct = local(c.tag)
                if ct == "sign":
                    sign = c.text
                elif ct == "line":
                    line = c.text
                elif ct == "clef-octave-change":
                    ch = (c.text or "").strip()
                    if ch:
                        oct_changes.append(ch)
            clefs.append((sign, line, ch))
        elif tag == "key":
            fifths = None
            for c in el:
                if local(c.tag) == "fifths":
                    fifths = c.text
            keys.append(fifths)
        elif tag == "time":
            n = d = None
            for c in el:
                if local(c.tag) == "beats":
                    n = c.text
                elif local(c.tag) == "beat-type":
                    d = c.text
            times.append((n, d))
        elif tag == "sound" and "tempo" in el.attrib:
            try:
                tempos.append(float(el.attrib["tempo"]))
            except ValueError:
                pass
    return {
        "clefs": sorted(set(clefs)),
        "keys": Counter(keys),
        "times": Counter(times),
        "octave_changes": Counter(oct_changes),
        "tempos": tempos,
        "has_key": any(k is not None for k in keys),
        "has_tempo": bool(tempos),
    }


def note_tuple(n: dict) -> tuple:
    return (
        int(n["midi"]),
        round(float(n["start"]), 6),
        round(float(n["duration"]), 6),
        str(n["hand"]),
    )


def leap_flags(notes: list[dict], semitones: int = 12) -> list[str]:
    out: list[str] = []
    for hand in ("right", "left"):
        seq = sorted(
            (n for n in notes if n["hand"] == hand),
            key=lambda n: (n["start"], n["midi"]),
        )
        for i in range(1, len(seq)):
            d = abs(seq[i]["midi"] - seq[i - 1]["midi"])
            if d >= semitones:
                out.append(
                    f"{hand} leap {d}st @ beat {seq[i]['start']:.3f}: "
                    f"{seq[i - 1]['midi']}→{seq[i]['midi']}"
                )
    return out


def odd_duration_flags(notes: list[dict]) -> list[str]:
    """Flag durations that look like OMR/float residue (not clean binary/triplet)."""
    ok = {
        0.0625,
        0.125,
        0.25,
        0.333333,
        0.375,
        0.5,
        0.666667,
        0.75,
        1.0,
        1.5,
        2.0,
        3.0,
        4.0,
        6.0,
        8.0,
    }
    flags: list[str] = []
    for n in notes:
        d = round(float(n["duration"]), 6)
        if d in ok:
            continue
        # allow near-triplet
        if abs(d - 1 / 3) < 1e-5 or abs(d - 2 / 3) < 1e-5:
            continue
        flags.append(f"odd duration {d} midi={n['midi']} start={n['start']}")
    return flags[:40]


def audit_one(score_id: str) -> dict:
    issues: list[str] = []
    warnings: list[str] = []
    catalog = {s["id"]: s for s in catalog_songs()}
    cat = catalog.get(score_id)
    if not cat:
        issues.append("missing from catalog.json")
    kind = (cat or {}).get("scoreKind", "?")

    json_path = SCORES / f"{score_id}.json"
    xml_path = MUSICXML / f"{score_id}.musicxml"
    if not xml_path.is_file():
        xml_path = MUSICXML / f"{score_id}.xml"
    pdf = find_pdf(score_id)

    result: dict = {
        "id": score_id,
        "scoreKind": kind,
        "json_path": str(json_path.relative_to(REPO)) if json_path.is_file() else None,
        "xml_path": str(xml_path.relative_to(REPO)) if xml_path.is_file() else None,
        "pdf_path": str(pdf.relative_to(REPO)) if pdf else None,
        "issues": issues,
        "warnings": warnings,
        "can_promote_formal": False,
    }

    if kind == "formal":
        warnings.append("already formal — audit is informational only")
    elif kind == "omrDraft":
        warnings.append(
            "omrDraft: PDF image proofreading required before scoreKind=formal"
        )
    if not pdf:
        warnings.append("no reference PDF under third_party/scores_pdf/")

    if not json_path.is_file():
        issues.append("missing practice JSON")
        return result
    if not xml_path.is_file():
        issues.append("missing packaged MusicXML")
        return result

    js = json.loads(json_path.read_text(encoding="utf-8"))
    root = load_xml_root(xml_path)
    parsed = parse_musicxml(root)
    struct = xml_structure_flags(root)

    a = [note_tuple(n) for n in parsed["notes"]]
    b = [note_tuple(n) for n in js["notes"]]
    result["note_count_xml_parse"] = len(a)
    result["note_count_json"] = len(b)
    result["json_equals_reparse"] = a == b
    if a != b:
        issues.append(
            f"JSON ≠ MusicXML reparse ({len(a)} vs {len(b)} after normalize)"
        )
        sa, sb = set(a), set(b)
        result["only_reparse"] = list(sa - sb)[:12]
        result["only_json"] = list(sb - sa)[:12]

    result["bpm_json"] = js.get("bpm")
    result["bpm_parse"] = parsed.get("bpm")
    result["key_json"] = js.get("keySignature")
    result["key_parse"] = parsed.get("keySignature")
    result["structure"] = {
        "clefs": struct["clefs"],
        "has_key": struct["has_key"],
        "has_tempo": struct["has_tempo"],
        "octave_changes": dict(struct["octave_changes"]),
        "times": {str(k): v for k, v in struct["times"].items()},
    }

    if not struct["has_key"]:
        warnings.append("MusicXML has no <key>/fifths — OMR often drops key signature")
    if not struct["has_tempo"]:
        warnings.append(
            f"MusicXML has no tempo; parser default bpm={parsed.get('bpm')} "
            f"(JSON bpm={js.get('bpm')}) — practice tempo may be a catalog default"
        )
    if struct["octave_changes"]:
        warnings.append(
            f"clef-octave-change present {dict(struct['octave_changes'])} — "
            "verify concert pitch vs notation (do not double-apply in JSON)"
        )

    leaps = leap_flags(js["notes"])
    result["octave_leaps"] = leaps
    if leaps:
        warnings.append(f"{len(leaps)} same-hand leap(s) ≥12 semitones (OMR risk)")

    odd = odd_duration_flags(js["notes"])
    result["odd_durations"] = odd
    if odd:
        warnings.append(f"{len(odd)} unusual duration value(s)")

    # Hard gate: never recommend formal without human PDF check + clean reparse.
    result["can_promote_formal"] = False
    result["promote_blockers"] = [
        "Human visual proofread against PDF not automated (PDF is image-only).",
        "Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md",
    ]
    if issues:
        result["promote_blockers"].append("Fix conversion issues listed above first.")

    return result


def render_markdown(report: dict) -> str:
    lines = [
        f"# OMR audit — `{report['id']}`",
        "",
        f"- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"- scoreKind: **{report.get('scoreKind')}**",
        f"- PDF: `{report.get('pdf_path') or 'MISSING'}`",
        f"- MusicXML: `{report.get('xml_path') or 'MISSING'}`",
        f"- JSON: `{report.get('json_path') or 'MISSING'}`",
        f"- JSON ≡ reparse: **{report.get('json_equals_reparse')}** "
        f"({report.get('note_count_json')}/{report.get('note_count_xml_parse')} notes)",
        f"- BPM JSON/parse: {report.get('bpm_json')} / {report.get('bpm_parse')}",
        f"- keySignature JSON/parse: {report.get('key_json')} / {report.get('key_parse')}",
        f"- Promote to formal? **NO** (automated audits never promote)",
        "",
        "## Issues",
    ]
    issues = report.get("issues") or []
    if not issues:
        lines.append("- (none)")
    else:
        lines.extend(f"- {x}" for x in issues)

    lines += ["", "## Warnings"]
    warnings = report.get("warnings") or []
    if not warnings:
        lines.append("- (none)")
    else:
        lines.extend(f"- {x}" for x in warnings)

    struct = report.get("structure") or {}
    lines += [
        "",
        "## MusicXML structure",
        f"- clefs: `{struct.get('clefs')}`",
        f"- has_key: {struct.get('has_key')}",
        f"- has_tempo: {struct.get('has_tempo')}",
        f"- octave_changes: `{struct.get('octave_changes')}`",
        f"- times: `{struct.get('times')}`",
        "",
        "## Same-hand leaps ≥12st",
    ]
    leaps = report.get("octave_leaps") or []
    if not leaps:
        lines.append("- (none)")
    else:
        lines.extend(f"- {x}" for x in leaps[:30])

    lines += ["", "## Promote blockers"]
    for b in report.get("promote_blockers") or []:
        lines.append(f"- {b}")

    lines += [
        "",
        "## Next human steps",
        "1. Open PDF + MusicXML in MuseScore side-by-side",
        "2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)",
        "3. Fix MusicXML, re-run `python .\\scripts\\musicxml_to_score.py --id ...`",
        "4. Re-run this audit; only then set `scoreKind: formal`",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--id", help="Single score id")
    ap.add_argument("--all-omr", action="store_true", help="All catalog omrDraft songs")
    ap.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUT,
        help="Directory for AUDIT markdown files",
    )
    ap.add_argument(
        "--fail-on-drift",
        action="store_true",
        help="Exit 1 if any score JSON ≠ MusicXML reparse (does not promote formal)",
    )
    args = ap.parse_args()

    if not args.id and not args.all_omr:
        ap.error("Pass --id or --all-omr")

    ids: list[str]
    if args.all_omr:
        ids = [s["id"] for s in catalog_songs() if s.get("scoreKind") == "omrDraft"]
    else:
        ids = [args.id]

    args.out_dir.mkdir(parents=True, exist_ok=True)
    index_lines = [
        "# OMR audit index",
        "",
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "",
        "| id | kind | JSON≡XML | notes | warnings | promote |",
        "|----|------|----------|-------|----------|---------|",
    ]

    drift_ids: list[str] = []
    print(f"Repo: {REPO}")
    for sid in ids:
        report = audit_one(sid)
        md = render_markdown(report)
        out = args.out_dir / f"{sid}.md"
        out.write_text(md, encoding="utf-8")
        n_warn = len(report.get("warnings") or [])
        n_iss = len(report.get("issues") or [])
        equal = bool(report.get("json_equals_reparse"))
        if not equal:
            drift_ids.append(sid)
        try:
            out_disp = str(out.relative_to(REPO))
        except ValueError:
            out_disp = str(out)
        print(
            f"SUMMARY id={sid} kind={report.get('scoreKind')} "
            f"equal={equal} "
            f"notes={report.get('note_count_json')} "
            f"issues={n_iss} warnings={n_warn} "
            f"promote=NO -> {out_disp}"
        )
        index_lines.append(
            f"| `{sid}` | {report.get('scoreKind')} | "
            f"{equal} | "
            f"{report.get('note_count_json')} | {n_warn} | NO |"
        )

    index_path = args.out_dir / "README.md"
    index_path.write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    try:
        index_disp = str(index_path.relative_to(REPO))
    except ValueError:
        index_disp = str(index_path)
    print(f"INDEX {index_disp}")

    if args.fail_on_drift and drift_ids:
        print("OMR_AUDIT FAIL drift (JSON ≠ MusicXML reparse):")
        for sid in drift_ids:
            print(f"  - {sid}")
        print("Re-run musicxml_to_score / fix MusicXML; do NOT mark formal.")
        return 1
    if args.fail_on_drift:
        print(f"OMR_AUDIT OK no-drift ids={len(ids)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
