#!/usr/bin/env python3
"""Catalog / import guards: omrDraft provenance must never be marked formal.

Usage (PowerShell, from repo root):
  python .\\scripts\\catalog_score_kind_guard.py
  python .\\scripts\\catalog_score_kind_guard.py --check-source path\\to\\omr_draft.mxl --score-kind formal

Exit 0 = ok; exit 1 = violations (do not ship / do not import as formal).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets" / "scores" / "catalog.json"
POLICY = REPO / "assets" / "scores" / "score_kind_policy.json"

_OMR_DESC = re.compile(
    r"omr\s*draft|audiveris|pdf\s*→\s*omr|pdf->omr|未逐音校对",
    re.IGNORECASE,
)

_OMR_SOURCE_MARKERS = (
    "_omr_work",
    "omr_draft",
    "audiveris_out",
    "audiveris",
)


def load_policy(path: Path = POLICY) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    ids = data.get("omrProvenanceIds") or []
    if not isinstance(ids, list) or not ids:
        raise SystemExit(f"policy missing omrProvenanceIds: {path}")
    return data


def omr_provenance_ids(policy: dict | None = None) -> set[str]:
    p = policy or load_policy()
    return {str(x) for x in p["omrProvenanceIds"]}


def source_looks_like_omr(source: str | Path) -> bool:
    s = str(source).replace("\\", "/").lower()
    return any(m in s for m in _OMR_SOURCE_MARKERS)


def description_looks_like_omr(description: str | None) -> bool:
    if not description:
        return False
    return bool(_OMR_DESC.search(description))


def catalog_violations(
    catalog_path: Path = CATALOG,
    policy_path: Path = POLICY,
) -> list[str]:
    policy = load_policy(policy_path)
    omr_ids = omr_provenance_ids(policy)
    songs = json.loads(catalog_path.read_text(encoding="utf-8")).get("songs") or []
    violations: list[str] = []
    for song in songs:
        sid = song.get("id")
        if not sid:
            violations.append("catalog entry missing id")
            continue
        kind = song.get("scoreKind")
        known_kinds = {"formal", "simplified", "omrDraft"}
        if kind not in known_kinds:
            violations.append(
                f"{sid}: invalid scoreKind {kind!r} "
                f"(expected one of {sorted(known_kinds)})"
            )
            continue
        desc = song.get("description") or ""
        if sid in omr_ids and kind != "omrDraft":
            violations.append(
                f"{sid}: omr provenance id has scoreKind={kind!r} (expected omrDraft)"
            )
        if kind == "formal" and description_looks_like_omr(desc):
            violations.append(
                f"{sid}: formal but description looks like OMR ({desc[:80]!r}…)"
                if len(desc) > 80
                else f"{sid}: formal but description looks like OMR ({desc!r})"
            )
    # Every provenance id should appear in catalog as omrDraft (catch silent drops).
    by_id = {s.get("id"): s for s in songs if s.get("id")}
    for sid in sorted(omr_ids):
        entry = by_id.get(sid)
        if entry is None:
            violations.append(f"{sid}: listed in policy but missing from catalog")
        elif entry.get("scoreKind") != "omrDraft":
            # Already covered above; keep single message style.
            pass
    return violations


def refuse_formal_import(*, source: str | Path, score_kind: str, score_id: str = "") -> str | None:
    """Return error message if this import must not proceed as formal."""
    if score_kind != "formal":
        return None
    omr_ids = omr_provenance_ids()
    if score_id and score_id in omr_ids:
        return (
            f"refuse formal: id {score_id!r} is OMR provenance "
            f"(see assets/scores/score_kind_policy.json)"
        )
    if source_looks_like_omr(source):
        return (
            f"refuse formal: source path looks like OMR draft ({source}). "
            "Use -ScoreKind omrDraft or proofread per docs/曲谱导入SOP.md"
        )
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description="Guard catalog scoreKind vs OMR provenance")
    ap.add_argument("--catalog", type=Path, default=CATALOG)
    ap.add_argument("--policy", type=Path, default=POLICY)
    ap.add_argument("--check-source", type=Path, help="Also check import source path")
    ap.add_argument("--score-kind", default="", help="With --check-source")
    ap.add_argument("--id", default="", help="Score id for import check")
    args = ap.parse_args()

    violations = catalog_violations(args.catalog, args.policy)
    if args.check_source and args.score_kind:
        msg = refuse_formal_import(
            source=args.check_source,
            score_kind=args.score_kind,
            score_id=args.id,
        )
        if msg:
            violations.append(msg)

    if violations:
        print("CATALOG_SCORE_KIND_GUARD FAIL")
        for v in violations:
            print(f"  - {v}")
        print(
            "Policy: never mark unproofread OMR as formal. "
            "See docs/曲谱导入SOP.md and assets/scores/score_kind_policy.json"
        )
        return 1

    songs = json.loads(args.catalog.read_text(encoding="utf-8")).get("songs") or []
    omr_n = sum(1 for s in songs if s.get("scoreKind") == "omrDraft")
    formal_n = sum(1 for s in songs if s.get("scoreKind") == "formal")
    print(
        f"CATALOG_SCORE_KIND_GUARD OK "
        f"songs={len(songs)} formal={formal_n} omrDraft={omr_n} "
        f"policyOmr={len(omr_provenance_ids(load_policy(args.policy)))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
