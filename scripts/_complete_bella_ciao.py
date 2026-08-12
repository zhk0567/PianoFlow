# -*- coding: utf-8 -*-
"""Rewrite bella_ciao MusicXML from PDF jianpu (1=G 2/4 ♩=120), still omrDraft until SOP.

Evidence: docs/omr_audit/_jianpu_proof/bella_ciao/row_p*.png + RapidOCR.
Melody-only (LH rests), multi-verse sheet ≈78 bars (p1 14 rows + p2 4 rows).
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from jianpu_to_musicxml import build_musicxml, write  # noqa: E402

ASSET = ROOT / "assets" / "scores" / "musicxml" / "bella_ciao.musicxml"
THIRD = ROOT / "third_party" / "scores_musicxml" / "bella_ciao.musicxml"


def _q(*toks: str) -> list[str]:
    return list(toks)


# Motifs (each measure sums to 2.0 quarters in 2/4)
A = _q("0/", "3/", "6/", "7/")  # rest-3-6-7
B = _q("1^/", "6/", "6")  # i 6 6
C = _q("1^", "7/", "6/")  # i 7 6
D = _q("3^", "3^")  # 3. 3.
E = _q("3^/", "3^/", "2^/", "3^/")  # 3 3 2 3
F = _q("4^/", "4^/", "4^")  # 4 4 4
G = _q("0/", "4^/", "3^/", "2^/")  # 0 4 3 2
H = _q("4^/", "3^/", "3^")  # 4 3 3
I = _q("0/", "3^/", "2^/", "1^/")  # 0 3 2 1
J = _q("7", "3^")  # 7 3.
K = _q("1^", "7")  # i 7
L = _q("6", "-")  # 6 —
# p2r3 variant after cadence (PDF vision): 0 3. 2. 3. instead of 3 3 2 3
E0 = _q("0/", "3^/", "2^/", "3^/")


def cycle_verse_open() -> list[list[str]]:
    return [A, B, A, B]


def cycle_into_chorus() -> list[list[str]]:
    # 0367 | i76 | i76 | 33 | 3323 | 444 | 0432 | 433 | 032i | 73 | i7 | 6-
    return [A, C, C, D, E, F, G, H, I, J, K, L]


def main() -> None:
    rh: list[list[str]] = []
    # --- page 1 rows (from OCR+vision) ---
    # r02
    rh += cycle_verse_open()
    # r03–r04 first chorus
    rh += cycle_into_chorus()
    # r05 after 6-: restart + partial
    rh += [A, B, A]
    # r06
    rh += [B, A, C, C, D]
    # r07–r08 chorus + restart
    rh += [E, F, G, H, I, J, K, L, A, B]
    # r09
    rh += [A, B, A, C, C]
    # r10–r11 chorus + restart
    rh += [D, E, F, G, H, I, J, K, L, A]
    # r12
    rh += [B, A, B, A, C]
    # r13–r14 chorus end
    rh += [C, D, E, F, G, H, I, J, K, L]
    # r15 page-end (opens next verse; incomplete phrase continues on p2)
    rh += [A, B, A, B, A]
    # --- page 2 ---
    # r01 continues into chorus
    rh += [C, C, D, E, F]
    # r02
    rh += [G, H, I, J, K]
    # r03: 6- then PDF shows 0 3 2 3 | 444 | 0432 | 433 (vision)
    rh += [L, E0, F, G, H]
    # r04 final cadence
    rh += [I, J, K, L]

    lh = [_q("0", "-")] * len(rh)
    xml = build_musicxml(
        title="Bella Ciao",
        artist="Traditional / Italian folk",
        key="G",
        beats=2,
        beat_type=4,
        tempo=120,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(ASSET, xml)
    THIRD.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ASSET, THIRD)
    print(f"[PianoFlow/jianpu] bella_ciao wrote {len(rh)} measures → {ASSET}")
    subprocess.check_call(
        [
            sys.executable,
            str(ROOT / "scripts" / "musicxml_to_score.py"),
            "--id",
            "bella_ciao",
            "--input",
            str(ASSET),
            "--update-catalog",
            "--score-kind",
            "omrDraft",
        ],
        cwd=str(ROOT),
    )


if __name__ == "__main__":
    main()
