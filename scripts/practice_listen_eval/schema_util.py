from __future__ import annotations

import json
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = REPO / "testdata/practice_listen/manifest.jsonl"
SCHEMA_PATH = REPO / "testdata/practice_listen/schema.json"

LABELS = ("hit", "wrong", "miss", "extra")


def load_manifest(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        rows.append(json.loads(line))
    return rows


def resolve_wav(segment: dict[str, Any], repo: Path = REPO) -> Path:
    p = Path(segment["wav"])
    if not p.is_absolute():
        p = repo / p
    return p
