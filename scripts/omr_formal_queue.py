"""Enterprise P4 formal-promotion queue helper.

Never promotes automatically. Lists queue status and validates SOP gate files
before allowing a call to omr_promote_formal.py.

Usage:
  python scripts/omr_formal_queue.py
  python scripts/omr_formal_queue.py --check-sop jue_bie_shu
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets/scores/catalog.json"
SOP_DIR = REPO / "docs/omr_audit"
PROOF = REPO / "docs/omr_audit/PROOFREAD_STATUS.md"

# Fixed priority from 战役-企业级验收勾选 / plan P4
QUEUE = [
    ("jue_bie_shu", "收口进行中 — 新 PDF 六页版须整曲重签"),
    ("radwimps_suzume", "点名债 m27–29 不可猜改"),
    ("sawano_call_of_silence", "点名债 m11–14；新 PDF 覆盖后重抽检"),
    ("hisaishi_castle_in_the_sky", "点名债 m21–24 不可猜改"),
]


def catalog_kinds() -> dict[str, str]:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return {s["id"]: s.get("scoreKind", "?") for s in data["songs"]}


def sop_path(score_id: str) -> Path:
    return SOP_DIR / f"{score_id}_SOP.md"


def sop_allows_promote(score_id: str) -> tuple[bool, str]:
    p = sop_path(score_id)
    if not p.is_file():
        return False, f"missing SOP {p.name}"
    text = p.read_text(encoding="utf-8")
    if "禁止 formal" in text or "未晋升" in text or "未通过" in text:
        return False, "SOP marks not ready / 禁止 formal"
    # Require open/mid/end checkboxes ticked for formal line
    if re.search(r"- \[ \] .*formal", text):
        return False, "formal checkbox still open"
    if not re.search(r"- \[x\] .*formal|scoreKind:\s*\*\*formal\*\*", text, re.I):
        # also accept explicit 已通过
        if "已通过" not in text and "可晋升" not in text:
            return False, "SOP missing 已通过/可晋升 or formal [x]"
    pdf = REPO / "third_party/scores_pdf" / f"{score_id}.pdf"
    if not pdf.is_file():
        return False, "missing PDF archive"
    return True, "SOP gate OK — run: python scripts/omr_promote_formal.py --id " + score_id + " --confirm-sop-passed"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check-sop", metavar="ID")
    args = ap.parse_args()
    kinds = catalog_kinds()

    if args.check_sop:
        ok, msg = sop_allows_promote(args.check_sop)
        print(("PASS" if ok else "BLOCK"), args.check_sop, msg)
        return 0 if ok else 2

    print("P4 formal queue (honest — no auto promote)\n")
    for sid, note in QUEUE:
        kind = kinds.get(sid, "MISSING")
        ok, msg = sop_allows_promote(sid)
        flag = "READY" if ok else "WAIT"
        print(f"  [{flag}] {sid}  kind={kind}  — {note}")
        print(f"         {msg}")
    print("\nAll other omrDraft ids: promote only after SOP + --confirm-sop-passed.")
    print("See", PROOF)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
