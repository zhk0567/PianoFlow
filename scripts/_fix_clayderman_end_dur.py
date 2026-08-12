# -*- coding: utf-8 -*-
"""Clayderman: m37–49 OMR used half-duration units — scale ×2 to fill 4/4. omrDraft."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, measures, q, save  # noqa: E402


def main() -> None:
    sid = "clayderman_reve_damour"
    tree, root, ns = load(sid)
    for m in measures(root, ns):
        try:
            num = int(m.get("number") or 0)
        except ValueError:
            continue
        if num < 37 or num > 49:
            continue
        for el in list(m):
            tag = el.tag.replace(ns, "") if ns else el.tag
            if tag not in ("note", "backup", "forward"):
                continue
            d = el.find(q(ns, "duration"))
            if d is not None and d.text and d.text.isdigit():
                d.text = str(int(d.text) * 2)
    save(sid, tree)
    convert(sid)
    print("[PianoFlow/omr] clayderman m37-49 duration x2; still omrDraft")


if __name__ == "__main__":
    main()
