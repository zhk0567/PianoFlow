#!/usr/bin/env python3
"""Audit practice JSON ↔ packaged MusicXML onset sync across catalog.

Compares chord sets at quantized quarter-note stamps (first N beats + full-piece
sample). Also checks whether json_score_to_musicxml / songScoreToMusicXml-style
engraving would drop onsets (polyphony skip bug).

Usage (PowerShell, repo root):
  python .\\scripts\\audit_json_musicxml_sync.py
  python .\\scripts\\audit_json_musicxml_sync.py --id merry_christmas_mr_lawrence
  python .\\scripts\\audit_json_musicxml_sync.py --write-md docs\\_audit_sync.md

Exit 0 always (report). Use --fail-on-mismatch for CI-style exit 1.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from musicxml_to_score import load_xml_root, parse_musicxml  # noqa: E402

CATALOG = REPO / "assets" / "scores" / "catalog.json"
SCORES = REPO / "assets" / "scores"
MUSICXML = SCORES / "musicxml"

# Quantize to 1/16 quarter (matches songScoreToMusicXml divisions=16)
Q = 16


def qstamp(beat: float) -> int:
    return int(round(float(beat) * Q))


def qstamp_tol_match(a: dict[int, set[int]], b: dict[int, set[int]], *, tol: int = 1) -> dict:
    """Compare chord maps allowing ±tol qstamp buckets (quantization slack)."""
    used_b: set[int] = set()
    only_a = 0
    pitch_mismatch = 0
    matched = 0
    samples: list[str] = []
    for k in sorted(a):
        sa = a[k]
        found = None
        for dk in range(0, tol + 1):
            for cand in ((k - dk) if dk else k, (k + dk) if dk else k):
                if cand in b and cand not in used_b:
                    found = cand
                    break
            if found is not None:
                break
        if found is None:
            only_a += 1
            if len(samples) < 20:
                samples.append(f"onlyJSON q={k/Q:.4f} {sorted(sa)[:6]}")
            continue
        used_b.add(found)
        sb = b[found]
        if sa == sb:
            matched += 1
        else:
            pitch_mismatch += 1
            if len(samples) < 20:
                samples.append(
                    f"pitch q={k/Q:.4f} json={sorted(sa)[:6]} xml={sorted(sb)[:6]}"
                )
    only_b = len([k for k in b if k not in used_b])
    return {
        "onset_json": len(a),
        "onset_xml": len(b),
        "only_json": only_a,
        "only_xml": only_b,
        "pitch_mismatch": pitch_mismatch,
        "matched": matched,
        "samples": samples,
    }


def chords_from_notes(notes: list[dict], *, until_beat: float | None = None) -> dict[int, set[int]]:
    out: dict[int, set[int]] = defaultdict(set)
    for n in notes:
        st = float(n["start"])
        if until_beat is not None and st > until_beat:
            continue
        out[qstamp(st)].add(int(n["midi"]))
    return dict(out)


def simulate_staff_kept_onsets(
    notes: list[dict],
    *,
    time_num: int,
    time_den: int,
    hand: str | None = None,
) -> set[int]:
    """Mirror the OLD buggy songScoreToMusicXml onset keep-set (for diagnosis).

    New fixed logic should keep all onsets that fall in measures; this helper
    reproduces skip-on-overlap to count how many songs were affected.
    """
    bpm_measure = time_num * (4.0 / time_den)
    filtered = notes
    if hand == "right":
        filtered = [n for n in notes if n.get("hand") != "left"]
    elif hand == "left":
        filtered = [n for n in notes if n.get("hand") == "left"]

    end_beat = 0.0
    for n in filtered:
        end_beat = max(end_beat, float(n["start"]) + float(n["duration"]))
    if end_beat <= 0:
        end_beat = bpm_measure
    measure_count = max(1, min(512, math.ceil(end_beat / bpm_measure)))

    kept: set[int] = set()
    for mi in range(measure_count):
        m_start = mi * bpm_measure
        m_notes = [
            n
            for n in filtered
            if max(0, min(measure_count - 1, int(math.floor(float(n["start"]) / bpm_measure))))
            == mi
        ]
        m_notes.sort(key=lambda n: float(n["start"]))
        # Split RH/LH like Dart (staff 1 = non-left)
        for staff_notes in (
            [n for n in m_notes if n.get("hand") != "left"],
            [n for n in m_notes if n.get("hand") == "left"],
        ):
            cursor = 0.0
            i = 0
            while i < len(staff_notes):
                n = staff_notes[i]
                onset = max(0.0, min(bpm_measure, float(n["start"]) - m_start))
                if onset <= cursor - 0.001:
                    i += 1
                    continue
                if onset > cursor + 0.001:
                    rest_beats = onset - cursor
                    d = max(1, min(9999, int(round(rest_beats * 4))))
                    cursor += d / 4.0
                group = [n]
                j = i + 1
                while (
                    j < len(staff_notes)
                    and abs(float(staff_notes[j]["start"]) - float(n["start"])) < 0.02
                ):
                    group.append(staff_notes[j])
                    j += 1
                remain = max(0.0, bpm_measure - cursor)
                if remain < 0.05:
                    break
                dur_beats = max(0.05, min(remain, float(n["duration"])))
                d = max(1, min(9999, int(round(dur_beats * 4))))
                if cursor + d / 4.0 > bpm_measure + 0.001:
                    d = max(1, int(round((bpm_measure - cursor) * 4)))
                kept.add(qstamp(float(n["start"])))
                cursor += d / 4.0
                i = j
                if cursor >= bpm_measure - 0.001:
                    break
    return kept


def simulate_staff_kept_onsets_fixed(
    notes: list[dict],
    *,
    time_num: int,
    time_den: int,
) -> set[int]:
    """Fixed engraving: never skip onsets; advance by gap to next onset / shortest."""
    bpm_measure = time_num * (4.0 / time_den)
    end_beat = 0.0
    for n in notes:
        end_beat = max(end_beat, float(n["start"]) + float(n["duration"]))
    if end_beat <= 0:
        end_beat = bpm_measure
    measure_count = max(1, min(512, math.ceil(end_beat / bpm_measure)))
    kept: set[int] = set()
    for mi in range(measure_count):
        m_start = mi * bpm_measure
        m_notes = [
            n
            for n in notes
            if max(0, min(measure_count - 1, int(math.floor(float(n["start"]) / bpm_measure))))
            == mi
        ]
        for staff_notes in (
            [n for n in m_notes if n.get("hand") != "left"],
            [n for n in m_notes if n.get("hand") == "left"],
        ):
            staff_notes = sorted(staff_notes, key=lambda n: (float(n["start"]), int(n["midi"])))
            i = 0
            cursor = 0.0
            while i < len(staff_notes):
                n = staff_notes[i]
                onset = max(0.0, min(bpm_measure, float(n["start"]) - m_start))
                group = [n]
                j = i + 1
                while (
                    j < len(staff_notes)
                    and abs(float(staff_notes[j]["start"]) - float(n["start"])) < 0.02
                ):
                    group.append(staff_notes[j])
                    j += 1
                next_onset = bpm_measure
                if j < len(staff_notes):
                    next_onset = max(
                        0.0, min(bpm_measure, float(staff_notes[j]["start"]) - m_start)
                    )
                if onset > cursor + 0.001:
                    rest_beats = onset - cursor
                    d = max(1, int(round(rest_beats * 4)))
                    cursor += d / 4.0
                elif onset < cursor - 0.001:
                    cursor = onset  # conceptual backup
                shortest = min(float(g["duration"]) for g in group)
                gap = max(0.05, next_onset - onset)
                dur_beats = max(0.05, min(shortest, gap, bpm_measure - onset))
                d = max(1, int(round(dur_beats * 4)))
                kept.add(qstamp(float(n["start"])))
                cursor = onset + d / 4.0
                i = j
    return kept


def compare_chords(
    a: dict[int, set[int]], b: dict[int, set[int]], *, sample_limit: int = 40
) -> dict:
    keys = sorted(set(a) | set(b))
    missing_in_b = 0
    missing_in_a = 0
    pitch_mismatch = 0
    octave_skew = 0
    samples: list[str] = []
    for k in keys:
        sa, sb = a.get(k, set()), b.get(k, set())
        if not sa and sb:
            missing_in_a += 1
            if len(samples) < sample_limit:
                samples.append(f"q={k/Q:.3f} onlyXML={sorted(sb)[:8]}")
            continue
        if sa and not sb:
            missing_in_b += 1
            if len(samples) < sample_limit:
                samples.append(f"q={k/Q:.3f} onlyJSON={sorted(sa)[:8]}")
            continue
        if sa != sb:
            # octave skew heuristic: same pitch class sets after % 12
            if {m % 12 for m in sa} == {m % 12 for m in sb} and sa != sb:
                octave_skew += 1
            else:
                pitch_mismatch += 1
            if len(samples) < sample_limit:
                samples.append(
                    f"q={k/Q:.3f} json={sorted(sa)[:6]} xml={sorted(sb)[:6]}"
                )
    return {
        "onset_json": len(a),
        "onset_xml": len(b),
        "only_json": missing_in_b,
        "only_xml": missing_in_a,
        "pitch_mismatch": pitch_mismatch,
        "octave_skew": octave_skew,
        "samples": samples,
    }


def audit_one(song: dict, *, window_beats: float = 32.0) -> dict:
    sid = song["id"]
    kind = song.get("scoreKind", "?")
    title = song.get("title", sid)
    json_path = SCORES / f"{sid}.json"
    xml_path = MUSICXML / f"{sid}.musicxml"
    if not xml_path.is_file():
        xml_path = MUSICXML / f"{sid}.xml"

    row: dict = {
        "id": sid,
        "title": title,
        "kind": kind,
        "status": "Fail",
        "reasons": [],
    }

    if not json_path.is_file():
        row["reasons"].append("missing_json")
        return row
    data = json.loads(json_path.read_text(encoding="utf-8"))
    notes = list(data.get("notes") or [])
    ts = data.get("timeSignature") or {}
    time_num = int(ts.get("num", 4))
    time_den = int(ts.get("den", 4))
    bpm_json = int(data.get("bpm") or song.get("bpm") or 0)
    row["bpm_json"] = bpm_json
    row["bpm_catalog"] = int(song.get("bpm") or 0)
    row["notes"] = len(notes)
    row["rh"] = sum(1 for n in notes if n.get("hand") != "left")
    row["lh"] = sum(1 for n in notes if n.get("hand") == "left")

    if not notes:
        row["reasons"].append("empty_json")
        return row
    if row["rh"] == 0:
        row["reasons"].append("empty_rh")
    if row["lh"] == 0:
        row["reasons"].append("empty_lh")

    # Engraving drop rate (old buggy algorithm)
    all_onsets = {qstamp(float(n["start"])) for n in notes}
    kept_old = simulate_staff_kept_onsets(notes, time_num=time_num, time_den=time_den)
    kept_new = simulate_staff_kept_onsets_fixed(notes, time_num=time_num, time_den=time_den)
    drop_old = len(all_onsets - kept_old)
    drop_new = len(all_onsets - kept_new)
    row["engrave_drop_old"] = drop_old
    row["engrave_drop_fixed"] = drop_new
    row["onset_count"] = len(all_onsets)
    if drop_old > max(2, int(0.02 * len(all_onsets))):
        row["reasons"].append(f"staff_polyphony_drop_old={drop_old}/{len(all_onsets)}")
    if drop_new > max(2, int(0.02 * len(all_onsets))):
        row["reasons"].append(f"staff_polyphony_drop_fixed={drop_new}/{len(all_onsets)}")

    if not xml_path.is_file():
        row["reasons"].append("missing_musicxml")
        row["status"] = "Fail"
        return row

    try:
        root = load_xml_root(xml_path)
        parsed = parse_musicxml(root)
    except Exception as e:  # noqa: BLE001
        row["reasons"].append(f"xml_parse_error:{e}")
        return row

    xml_notes = list(parsed.get("notes") or [])
    bpm_xml = int(parsed.get("bpm") or 0)
    row["bpm_xml"] = bpm_xml
    row["xml_notes"] = len(xml_notes)
    if bpm_json and bpm_xml and abs(bpm_json - bpm_xml) > 2:
        row["reasons"].append(f"bpm_mismatch json={bpm_json} xml={bpm_xml}")

    j_ch = chords_from_notes(notes, until_beat=window_beats)
    x_ch = chords_from_notes(xml_notes, until_beat=window_beats)
    cmp_w = compare_chords(j_ch, x_ch)
    row["window"] = cmp_w

    j_all = chords_from_notes(notes)
    x_all = chords_from_notes(xml_notes)
    # Allow ±1/16q slack — JSON↔simplified MusicXML quantization
    cmp_a = qstamp_tol_match(j_all, x_all, tol=1)
    row["full"] = {
        k: cmp_a[k]
        for k in (
            "onset_json",
            "onset_xml",
            "only_json",
            "only_xml",
            "pitch_mismatch",
            "matched",
        )
    }
    row["full_samples"] = cmp_a["samples"]

    only_j = cmp_a["only_json"]
    only_x = cmp_a["only_xml"]
    pitch = cmp_a["pitch_mismatch"]
    onset_n = max(1, cmp_a["onset_json"])
    drift_ratio = (only_j + only_x + pitch) / onset_n

    if drift_ratio > 0.12 or only_j > max(30, int(0.05 * onset_n)):
        row["reasons"].append(
            f"json_xml_onset_drift onlyJ={only_j} onlyX={only_x} pitch={pitch} "
            f"ratio={drift_ratio:.2%}"
        )

    # Status: Fail on missing files / bpm / json↔xml drift / residual engraving drop.
    # staff_polyphony_drop_old is informational (pre-fix Dart/Python bug).
    hard = [
        r
        for r in row["reasons"]
        if not r.startswith("staff_polyphony_drop_old")
        and not r.startswith("empty_lh")
        and not r.startswith("empty_rh")
    ]
    row["reasons_all"] = list(row["reasons"])
    row["reasons"] = hard
    if not hard:
        row["status"] = "Pass"
        # Keep old-drop note for the report when relevant
        if drop_old > max(2, int(0.02 * len(all_onsets))):
            row["reasons"] = [f"(fixed) had_polyphony_drop_old={drop_old}"]
    else:
        row["status"] = "Fail"

    return row


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", default="")
    ap.add_argument("--window-beats", type=float, default=32.0)
    ap.add_argument("--write-md", type=Path, default=None)
    ap.add_argument("--fail-on-mismatch", action="store_true")
    ap.add_argument("--json-out", type=Path, default=None)
    args = ap.parse_args()

    songs = json.loads(CATALOG.read_text(encoding="utf-8")).get("songs") or []
    if args.id:
        songs = [s for s in songs if s.get("id") == args.id]
        if not songs:
            print(f"[PianoFlow/audit] unknown id {args.id}", file=sys.stderr)
            return 1

    rows = [audit_one(s, window_beats=args.window_beats) for s in songs]
    passed = sum(1 for r in rows if r["status"] == "Pass")
    failed = sum(1 for r in rows if r["status"] == "Fail")

    print(f"[PianoFlow/audit] catalog={len(rows)} Pass={passed} Fail={failed}")
    for r in rows:
        mark = "PASS" if r["status"] == "Pass" else "FAIL"
        reasons = "; ".join(r.get("reasons") or []) or "ok"
        drop = r.get("engrave_drop_old", "?")
        print(
            f"  [{mark}] {r['id']} ({r['kind']}) notes={r.get('notes','?')} "
            f"engrave_drop_old={drop} :: {reasons}"
        )

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"[PianoFlow/audit] wrote {args.json_out}")

    if args.write_md:
        lines = [
            "# JSON ↔ MusicXML sync audit",
            "",
            f"Pass **{passed}** / Fail **{failed}** / Total **{len(rows)}**",
            "",
            "| Status | Id | Kind | Notes | EngraveDrop(old) | Reasons |",
            "| --- | --- | --- | ---: | ---: | --- |",
        ]
        for r in rows:
            reasons = ", ".join(r.get("reasons") or []) or "ok"
            lines.append(
                f"| {r['status']} | `{r['id']}` | {r['kind']} | {r.get('notes','')} | "
                f"{r.get('engrave_drop_old','')} | {reasons} |"
            )
        args.write_md.parent.mkdir(parents=True, exist_ok=True)
        args.write_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"[PianoFlow/audit] wrote {args.write_md}")

    if args.fail_on_mismatch and failed:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
