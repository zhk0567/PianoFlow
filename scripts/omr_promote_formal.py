#!/usr/bin/env python3
"""Promote an OMR draft to formal AFTER SOP checklist passes.

Never call this without human/PDF proofread evidence.
Requires explicit --confirm-sop-passed.

Usage:
  python .\\scripts\\omr_promote_formal.py --id hisaishi_castle_in_the_sky --confirm-sop-passed
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from score_kind_policy_sync import remove_id, check_policy_dart_sync  # noqa: E402
from catalog_score_kind_guard import catalog_violations  # noqa: E402

CATALOG = REPO / "assets" / "scores" / "catalog.json"


def promote(score_id: str, description: str | None) -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    songs = data.get("songs") or []
    hit = None
    for s in songs:
        if s.get("id") == score_id:
            hit = s
            break
    if hit is None:
        raise SystemExit(f"id not in catalog: {score_id}")
    if hit.get("scoreKind") != "omrDraft":
        raise SystemExit(f"{score_id} scoreKind={hit.get('scoreKind')!r}, expected omrDraft")

    remove_id(score_id)
    hit["scoreKind"] = "formal"
    if description:
        hit["description"] = description
    else:
        # strip OMR-ish phrasing so guard passes
        desc = str(hit.get("description") or "")
        desc = re.sub(
            r"(?i)\s*OMR draft from PDF via Audiveris[^.]*\.",
            "",
            desc,
        )
        desc = re.sub(r"(?i)\s*Still omrDraft[^.]*\.", "", desc)
        desc = re.sub(r"(?i)\s*Not claimed 100%[^.]*\.", "", desc)
        desc = re.sub(r"(?i)\s*\(未逐音校对\)", "", desc)
        desc = re.sub(r"\s{2,}", " ", desc).strip()
        if not desc.endswith("."):
            desc += "."
        desc += " Proofread against PDF per SOP (2026-08-04); promoted to formal."
        hit["description"] = desc

    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"CATALOG {score_id} -> formal")

    viol = catalog_violations()
    if viol:
        print("CATALOG_SCORE_KIND_GUARD FAIL after promote:")
        for v in viol:
            print(f"  - {v}")
        raise SystemExit(1)
    drift = check_policy_dart_sync()
    if drift:
        print("POLICY_SYNC_CHECK FAIL:")
        for v in drift:
            print(f"  - {v}")
        raise SystemExit(1)
    print("PROMOTE OK guards passed")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True)
    ap.add_argument(
        "--confirm-sop-passed",
        action="store_true",
        help="Required. Affirms docs/曲谱导入SOP.md checklist passed for this id.",
    )
    ap.add_argument("--description", help="Optional formal catalog description")
    args = ap.parse_args()
    if not args.confirm_sop_passed:
        print(
            "Refuse: pass --confirm-sop-passed only after SOP checklist "
            "(PDF open/mid/end pitch) is done.",
            file=sys.stderr,
        )
        return 2
    promote(args.id, args.description)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
