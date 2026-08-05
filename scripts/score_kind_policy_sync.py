#!/usr/bin/env python3
"""Register OMR provenance ids into score_kind_policy.json + Dart mirror.

Keeps assets/scores/score_kind_policy.json and
lib/shared/score_kind_policy.dart::omrProvenanceIds in sync so new OMR imports
cannot miss the anti-formal lock.

Usage (PowerShell, from repo root):
  python .\\scripts\\score_kind_policy_sync.py --add-id my_new_omr_song
  python .\\scripts\\score_kind_policy_sync.py --sync-from-catalog
  python .\\scripts\\score_kind_policy_sync.py --rewrite-dart   # JSON → Dart only
  python .\\scripts\\score_kind_policy_sync.py --check          # drift → exit 1
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
POLICY = REPO / "assets" / "scores" / "score_kind_policy.json"
CATALOG = REPO / "assets" / "scores" / "catalog.json"
DART = REPO / "lib" / "shared" / "score_kind_policy.dart"

_DART_SET_RE = re.compile(
    r"static const omrProvenanceIds = <String>\{.*?\};",
    re.DOTALL,
)


def load_policy(path: Path = POLICY) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data.get("omrProvenanceIds"), list):
        raise SystemExit(f"policy missing omrProvenanceIds: {path}")
    return data


def write_policy(ids: list[str], path: Path = POLICY) -> None:
    data = load_policy(path) if path.exists() else {
        "notes": (
            "PDF→Audiveris OMR provenance. Never set scoreKind=formal until "
            "docs/曲谱导入SOP.md proofread checklist passes. Automated tools "
            "must not promote these ids."
        ),
    }
    data["omrProvenanceIds"] = sorted(set(ids))
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def rewrite_dart(ids: list[str], path: Path = DART) -> None:
    text = path.read_text(encoding="utf-8")
    sorted_ids = sorted(set(ids))
    if sorted_ids:
        body = ",\n".join(f"    '{sid}'" for sid in sorted_ids)
        block = (
            "static const omrProvenanceIds = <String>{\n"
            f"{body},\n"
            "  };"
        )
    else:
        block = "static const omrProvenanceIds = <String>{};"
    if not _DART_SET_RE.search(text):
        raise SystemExit(f"cannot find omrProvenanceIds set in {path}")
    path.write_text(_DART_SET_RE.sub(block, text, count=1), encoding="utf-8")


_DART_ID_RE = re.compile(r"'([a-z0-9_]+)'")


def dart_omr_ids(path: Path = DART) -> set[str]:
    text = path.read_text(encoding="utf-8")
    m = _DART_SET_RE.search(text)
    if not m:
        raise SystemExit(f"cannot find omrProvenanceIds set in {path}")
    return set(_DART_ID_RE.findall(m.group(0)))


def check_policy_dart_sync() -> list[str]:
    """Return human-readable drift lines (empty = OK)."""
    policy_ids = {str(x) for x in load_policy()["omrProvenanceIds"]}
    dart_ids = dart_omr_ids()
    violations: list[str] = []
    only_json = sorted(policy_ids - dart_ids)
    only_dart = sorted(dart_ids - policy_ids)
    if only_json:
        violations.append(
            f"in JSON not Dart: {', '.join(only_json)}"
        )
    if only_dart:
        violations.append(
            f"in Dart not JSON: {', '.join(only_dart)}"
        )
    return violations


def remove_id(score_id: str) -> bool:
    """Drop an id after human proofread promotion to formal."""
    if not re.fullmatch(r"[a-z0-9_]+", score_id):
        raise SystemExit(f"id must be snake_case ascii: {score_id!r}")
    policy = load_policy()
    ids = [str(x) for x in policy["omrProvenanceIds"]]
    if score_id not in ids:
        print(f"POLICY_SYNC remove skip (not present): {score_id}")
        rewrite_dart(ids)
        return False
    ids = [x for x in ids if x != score_id]
    write_policy(ids)
    rewrite_dart(ids)
    print(f"POLICY_SYNC removed: {score_id} (policyOmr={len(set(ids))})")
    return True


def add_id(score_id: str) -> bool:
    if not re.fullmatch(r"[a-z0-9_]+", score_id):
        raise SystemExit(f"id must be snake_case ascii: {score_id!r}")
    policy = load_policy()
    ids = [str(x) for x in policy["omrProvenanceIds"]]
    if score_id in ids:
        print(f"POLICY_SYNC already: {score_id}")
        rewrite_dart(ids)  # heal Dart drift even when id exists
        return False
    ids.append(score_id)
    write_policy(ids)
    rewrite_dart(ids)
    print(f"POLICY_SYNC added: {score_id} (policyOmr={len(set(ids))})")
    return True


def sync_from_catalog() -> int:
    songs = json.loads(CATALOG.read_text(encoding="utf-8")).get("songs") or []
    catalog_omr = sorted(
        {
            str(s["id"])
            for s in songs
            if s.get("id") and s.get("scoreKind") == "omrDraft"
        }
    )
    policy = load_policy()
    before = set(str(x) for x in policy["omrProvenanceIds"])
    merged = sorted(before | set(catalog_omr))
    added = sorted(set(catalog_omr) - before)
    write_policy(merged)
    rewrite_dart(merged)
    print(
        f"POLICY_SYNC from-catalog added={len(added)} "
        f"policyOmr={len(merged)} catalogOmr={len(catalog_omr)}"
    )
    for sid in added:
        print(f"  + {sid}")
    return len(added)


def main() -> int:
    ap = argparse.ArgumentParser(description="Sync OMR provenance policy + Dart")
    ap.add_argument("--add-id", help="Register one OMR id")
    ap.add_argument(
        "--remove-id",
        help="Unregister one id after promoting to formal (SOP checklist passed)",
    )
    ap.add_argument(
        "--sync-from-catalog",
        action="store_true",
        help="Union all catalog omrDraft ids into policy",
    )
    ap.add_argument(
        "--rewrite-dart",
        action="store_true",
        help="Rewrite Dart set from JSON only",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="Exit 1 if JSON omrProvenanceIds != Dart mirror",
    )
    args = ap.parse_args()

    if args.add_id:
        add_id(args.add_id)
        return 0
    if args.remove_id:
        remove_id(args.remove_id)
        return 0
    if args.sync_from_catalog:
        sync_from_catalog()
        return 0
    if args.rewrite_dart:
        ids = [str(x) for x in load_policy()["omrProvenanceIds"]]
        rewrite_dart(ids)
        print(f"POLICY_SYNC rewrite-dart policyOmr={len(ids)}")
        return 0
    if args.check:
        violations = check_policy_dart_sync()
        if violations:
            print("POLICY_SYNC_CHECK FAIL")
            for v in violations:
                print(f"  - {v}")
            print(
                "Fix: python .\\scripts\\score_kind_policy_sync.py --rewrite-dart "
                "(or edit both sides intentionally)."
            )
            return 1
        n = len(load_policy()["omrProvenanceIds"])
        print(f"POLICY_SYNC_CHECK OK policyOmr={n}")
        return 0

    ap.error(
        "Provide --add-id, --remove-id, --sync-from-catalog, --rewrite-dart, or --check"
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
