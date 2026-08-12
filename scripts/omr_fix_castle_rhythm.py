# -*- coding: utf-8 -*-
"""Stubs restored for score-specific OMR rhythm fixes (invoke via _fix_omr_openings)."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "scripts"))


def main() -> None:
    print(
        "[PianoFlow/omr] Use: python scripts/_fix_omr_openings.py <target>\n"
        "  e.g. castle_mid | suzume | moonlight helpers live in _fix_*.py"
    )


if __name__ == "__main__":
    main()
