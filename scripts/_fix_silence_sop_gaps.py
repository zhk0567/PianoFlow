# -*- coding: utf-8 -*-
"""Call of Silence: close concrete SOP gaps (omrDraft only; no pitch guessing).

This round:
- m20: remove orphan forward(30)+voice6 A4 half that overflowed the bar
  (duration audit: voice6 sum≠32). RH+LH voice5 already fill 4/4.
- m11–14 / 8va / ending: PDF vision+staff-geometry disagree → NO rewrite.
"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, measures, save  # noqa: E402


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def fix_m20_orphan(tree: ET.ElementTree, root: ET.Element, ns: str) -> bool:
    by = {m.get("number"): m for m in measures(root, ns)}
    m20 = by.get("20")
    if m20 is None:
        return False
    els = list(m20)
    backups = [i for i, e in enumerate(els) if local(e.tag) == "backup"]
    if len(backups) < 2:
        print("[PianoFlow/omr] silence m20: no second backup — skip")
        return False
    cut = backups[1]
    for e in els[cut:]:
        m20.remove(e)
    print("[PianoFlow/omr] silence m20: removed orphan backup+forward+voice6")
    return True


def main() -> None:
    sid = "sawano_call_of_silence"
    tree, root, ns = load(sid)
    changed = fix_m20_orphan(tree, root, ns)
    if changed:
        save(sid, tree)
        convert(sid)
    print(
        "[PianoFlow/omr] silence SOP gaps: m20 duration closed; "
        "m11-14/8va/end NOT rewritten (no pitch consensus); still omrDraft"
    )


if __name__ == "__main__":
    main()
