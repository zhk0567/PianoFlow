# -*- coding: utf-8 -*-
"""Promote omrDraft → formal ONLY after SOP checklist (refuses by default)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "assets" / "scores" / "catalog.json"
POLICY = REPO / "assets" / "scores" / "score_kind_policy.json"


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Promote scoreKind to formal (requires --i-completed-sop)"
    )
    ap.add_argument("--id", required=True)
    ap.add_argument(
        "--i-completed-sop",
        action="store_true",
        help="Confirm docs/曲谱导入SOP.md open/mid/end checklist is done",
    )
    ap.add_argument(
        "--confirm-sop-passed",
        action="store_true",
        help="Alias of --i-completed-sop",
    )
    args = ap.parse_args()
    if not (args.i_completed_sop or args.confirm_sop_passed):
        print(
            "[PianoFlow/omr] REFUSED: pass --i-completed-sop / --confirm-sop-passed "
            "only after SOP 开/中/尾 PDF 逐音校对完成。Automated tools must not promote."
        )
        return 2
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    found = False
    for s in data.get("songs") or []:
        if s.get("id") != args.id:
            continue
        found = True
        if s.get("scoreKind") == "formal":
            print(f"[PianoFlow/omr] {args.id} already formal")
            return 0
        s["scoreKind"] = "formal"
        print(f"[PianoFlow/omr] promoted {args.id} → formal")
    if not found:
        raise SystemExit(f"id not in catalog: {args.id}")
    CATALOG.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    # Remove from omr provenance policy if present
    if POLICY.exists():
        pol = json.loads(POLICY.read_text(encoding="utf-8"))
        ids = [i for i in pol.get("omrProvenanceIds") or [] if i != args.id]
        pol["omrProvenanceIds"] = ids
        POLICY.write_text(
            json.dumps(pol, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print("[PianoFlow/omr] removed from score_kind_policy omrProvenanceIds")
    print("[PianoFlow/omr] also run: python scripts/score_kind_policy_sync.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
