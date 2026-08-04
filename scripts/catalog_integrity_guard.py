#!/usr/bin/env python3
"""Catalog asset integrity: id/bpm/asset/MusicXML must stay consistent.

UI uses catalog.bpm; practice engine uses score JSON bpm — drift breaks feel.
Missing asset / MusicXML → empty practice or Verovio fallback.
Packaged MusicXML must match third_party byte-for-byte (sha256).

Usage (PowerShell, from repo root):
  python .\\scripts\\catalog_integrity_guard.py

Exit 0 = ok; exit 1 = violations.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "assets" / "scores" / "catalog.json"
ASSET_XML_DIR = REPO / "assets" / "scores" / "musicxml"
SRC_XML_DIR = REPO / "third_party" / "scores_musicxml"


def _resolve_score_xml(score_id: str, directory: Path) -> Path | None:
    for ext in (".musicxml", ".xml", ".mxl", ".MusicXML"):
        p = directory / f"{score_id}{ext}"
        if p.is_file():
            return p
    return None


def integrity_violations(
    catalog_path: Path = CATALOG,
    repo: Path = REPO,
    *,
    require_third_party: bool = True,
) -> list[str]:
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    songs = data.get("songs") or []
    violations: list[str] = []
    seen_ids: set[str] = set()

    for song in songs:
        sid = song.get("id")
        if not sid:
            violations.append("catalog entry missing id")
            continue
        if sid in seen_ids:
            violations.append(f"{sid}: duplicate catalog id")
        seen_ids.add(sid)

        title = (song.get("title") or "").strip()
        artist = (song.get("artist") or "").strip()
        if not title:
            violations.append(f"{sid}: catalog.title missing")
        if not artist:
            violations.append(f"{sid}: catalog.artist missing")

        asset_rel = song.get("asset")
        if not asset_rel:
            violations.append(f"{sid}: missing catalog.asset")
            continue
        expect_asset = f"assets/scores/{sid}.json"
        if str(asset_rel).replace("\\", "/") != expect_asset:
            violations.append(
                f"{sid}: catalog.asset={asset_rel!r} expected {expect_asset!r}"
            )
        asset_path = repo / Path(*str(asset_rel).replace("\\", "/").split("/"))
        if not asset_path.is_file():
            violations.append(f"{sid}: asset missing ({asset_rel})")
            continue

        try:
            score = json.loads(asset_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as e:
            violations.append(f"{sid}: asset unreadable ({e})")
            continue

        json_id = score.get("id")
        if json_id != sid:
            violations.append(f"{sid}: json.id={json_id!r} != catalog.id")

        notes = score.get("notes")
        if not isinstance(notes, list) or len(notes) < 1:
            violations.append(f"{sid}: score JSON notes empty or missing")
        else:
            for i, n in enumerate(notes):
                if not isinstance(n, dict):
                    violations.append(f"{sid}: notes[{i}] not an object")
                    continue
                hand = n.get("hand")
                if hand not in ("left", "right"):
                    violations.append(
                        f"{sid}: notes[{i}].hand={hand!r} "
                        f"(expected left|right)"
                    )
                midi = n.get("midi")
                try:
                    m = int(midi)
                    if m < 21 or m > 108:
                        violations.append(
                            f"{sid}: notes[{i}].midi={midi} out of piano 21-108"
                        )
                except (TypeError, ValueError):
                    violations.append(
                        f"{sid}: notes[{i}].midi={midi!r} must be int 21-108"
                    )
                try:
                    dur = float(n.get("duration"))
                    if dur <= 0:
                        violations.append(
                            f"{sid}: notes[{i}].duration={n.get('duration')!r} must be > 0"
                        )
                except (TypeError, ValueError):
                    violations.append(
                        f"{sid}: notes[{i}].duration={n.get('duration')!r} must be number > 0"
                    )
                try:
                    start = float(n.get("start"))
                    if start < 0:
                        violations.append(
                            f"{sid}: notes[{i}].start={n.get('start')!r} must be >= 0"
                        )
                except (TypeError, ValueError):
                    violations.append(
                        f"{sid}: notes[{i}].start={n.get('start')!r} must be number >= 0"
                    )

        cat_bpm = song.get("bpm")
        json_bpm = score.get("bpm")
        if cat_bpm is None:
            violations.append(f"{sid}: catalog.bpm missing")
        elif json_bpm is None:
            violations.append(f"{sid}: json.bpm missing")
        elif int(cat_bpm) != int(json_bpm):
            violations.append(
                f"{sid}: bpm drift catalog={cat_bpm} json={json_bpm}"
            )
        else:
            try:
                bpm_i = int(cat_bpm)
                if bpm_i < 30 or bpm_i > 300:
                    violations.append(
                        f"{sid}: bpm={bpm_i} out of practice range 30-300"
                    )
            except (TypeError, ValueError):
                violations.append(f"{sid}: bpm={cat_bpm!r} must be int")

        packaged = _resolve_score_xml(sid, ASSET_XML_DIR)
        if packaged is None:
            violations.append(
                f"{sid}: packaged MusicXML missing "
                f"(assets/scores/musicxml/{sid}.musicxml)"
            )

        if require_third_party:
            src = _resolve_score_xml(sid, SRC_XML_DIR)
            if src is None:
                violations.append(
                    f"{sid}: source MusicXML missing "
                    f"(third_party/scores_musicxml/{sid}.musicxml)"
                )
            elif packaged is not None:
                try:
                    ha = hashlib.sha256(packaged.read_bytes()).hexdigest()
                    hs = hashlib.sha256(src.read_bytes()).hexdigest()
                    if ha != hs:
                        violations.append(
                            f"{sid}: MusicXML drift packaged≠third_party "
                            f"(re-sync via import-score / convert)"
                        )
                except OSError as e:
                    violations.append(f"{sid}: MusicXML unreadable ({e})")

        genre = song.get("genre") or ""
        known = {"Classical", "Anime", "Pop", "Game"}
        if not genre:
            violations.append(f"{sid}: catalog.genre missing")
        elif genre not in known:
            violations.append(
                f"{sid}: unknown genre {genre!r} "
                f"(expected one of {sorted(known)}; add UI map if intentional)"
            )

        known_kinds = {"formal", "simplified", "omrDraft"}
        kind = song.get("scoreKind")
        if kind not in known_kinds:
            violations.append(
                f"{sid}: invalid scoreKind {kind!r} "
                f"(expected one of {sorted(known_kinds)})"
            )

        diff = song.get("difficulty")
        try:
            d = int(diff)
            if d < 1 or d > 5:
                violations.append(
                    f"{sid}: difficulty {diff!r} out of range 1-5"
                )
        except (TypeError, ValueError):
            violations.append(
                f"{sid}: difficulty {diff!r} must be int 1-5"
            )

    return violations


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Guard catalog ↔ score JSON ↔ packaged MusicXML integrity"
    )
    ap.add_argument("--catalog", type=Path, default=CATALOG)
    ap.add_argument(
        "--skip-third-party",
        action="store_true",
        help="Do not require third_party/scores_musicxml/{id}.musicxml",
    )
    args = ap.parse_args()

    violations = integrity_violations(
        args.catalog,
        REPO,
        require_third_party=not args.skip_third_party,
    )
    if violations:
        print("CATALOG_INTEGRITY_GUARD FAIL")
        for v in violations:
            print(f"  - {v}")
        print(
            "Fix: align catalog.bpm with score JSON, ensure assets exist, "
            "and sync MusicXML via musicxml_to_score / import-score."
        )
        return 1

    songs = json.loads(args.catalog.read_text(encoding="utf-8")).get("songs") or []
    print(f"CATALOG_INTEGRITY_GUARD OK songs={len(songs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
