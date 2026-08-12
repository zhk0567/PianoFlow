# -*- coding: utf-8 -*-
"""Import Rush E (Audiveris) + jianpu drafts as omrDraft."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "third_party" / "scores_pdf"
WORK = ROOT / "third_party" / "scores_musicxml" / "_omr_work"

DOWNLOADS = Path(r"C:\Users\32834\Downloads")

JIANPU = [
    {
        "id": "xiao_xing_xing",
        "title": "小星星",
        "artist": "Traditional / Twinkle Twinkle Little Star",
        "genre": "Classical",
        "difficulty": 1,
        "pdf_name": "小星星.pdf",
    },
    {
        "id": "fen_shua_jiang",
        "title": "粉刷匠",
        "artist": "Traditional / Polish folk",
        "genre": "Pop",
        "difficulty": 1,
        "pdf_name": "粉刷匠.pdf",
    },
    {
        "id": "blowin_in_the_wind",
        "title": "Blowin' In The Wind",
        "artist": "Bob Dylan",
        "genre": "Pop",
        "difficulty": 2,
        "pdf_name": "Blowin' In The Wind.pdf",
    },
    {
        "id": "bella_ciao",
        "title": "Bella Ciao",
        "artist": "Traditional / Italian folk",
        "genre": "Pop",
        "difficulty": 2,
        "pdf_name": "Bella Ciao.pdf",
    },
    {
        "id": "when_you_wish_upon_a_star",
        "title": "When You Wish Upon a Star",
        "artist": "Leigh Harline / Ned Washington",
        "genre": "Pop",
        "difficulty": 2,
        "pdf_name": "When You Wish Upon a Star.pdf",
    },
    {
        "id": "whistle",
        "title": "Whistle",
        "artist": "Flo Rida",
        "genre": "Pop",
        "difficulty": 3,
        "pdf_name": "Whistle.pdf",
    },
    {
        "id": "pure_imagination",
        "title": "Pure Imagination",
        "artist": "Leslie Bricusse / Anthony Newley",
        "genre": "Pop",
        "difficulty": 3,
        "pdf_name": "Pure Imagination.pdf",
    },
    {
        "id": "ju_hua_tai",
        "title": "菊花台",
        "artist": "周杰伦",
        "genre": "Pop",
        "difficulty": 3,
        "pdf_name": "菊花台.pdf",
    },
    {
        "id": "ye_de_gang_qin_qu_5",
        "title": "夜的钢琴曲五",
        "artist": "石进",
        "genre": "Classical",
        "difficulty": 3,
        "pdf_name": "夜的钢琴曲五.pdf",
    },
    {
        "id": "an_he_qiao",
        "title": "安和桥",
        "artist": "宋冬野",
        "genre": "Pop",
        "difficulty": 2,
        "pdf_name": "安和桥.pdf",
    },
]

DESC_JIANPU = (
    "Jianpu PDF transcribed to MusicXML (draft; not Audiveris). "
    "Not fully proofread against PDF. Local practice only — omrDraft."
)


def run(cmd: list[str]) -> int:
    print("+", " ".join(cmd))
    p = subprocess.run(cmd, cwd=str(ROOT))
    return p.returncode


def import_one(
    *,
    sid: str,
    source: Path,
    title: str,
    artist: str,
    genre: str,
    difficulty: int,
    description: str,
    pdf: Path | None,
) -> bool:
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ROOT / "scripts" / "import-score.ps1"),
        "-Id",
        sid,
        "-Source",
        str(source),
        "-Title",
        title,
        "-Artist",
        artist,
        "-Genre",
        genre,
        "-Difficulty",
        str(difficulty),
        "-Description",
        description,
        "-ScoreKind",
        "omrDraft",
    ]
    if pdf is not None:
        archived = PDF_DIR / f"{sid}.pdf"
        PDF_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pdf, archived)
        cmd += ["-Pdf", str(archived)]
    return run(cmd) == 0


def main() -> int:
    ok: list[str] = []
    fail: list[str] = []

    # Rush E via omr-finish-import
    print("======== rush_e ========")
    rc = run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ROOT / "scripts" / "omr-finish-import.ps1"),
            "-Id",
            "rush_e",
            "-Title",
            "Rush E",
            "-Artist",
            "Sheet Music Boss / Andrew Wrangell",
            "-Genre",
            "Classical",
            "-Difficulty",
            "5",
            "-Description",
            "OMR draft from staff PDF via Audiveris (batch 2026-08-05). Not proofread. Local practice only.",
            "-ForceOmr",
        ]
    )
    (ok if rc == 0 else fail).append("rush_e")

    for item in JIANPU:
        sid = item["id"]
        print(f"======== {sid} ========")
        src = WORK / sid / "jianpu_draft.musicxml"
        if not src.exists():
            print("missing", src)
            fail.append(sid)
            continue
        pdf = DOWNLOADS / item["pdf_name"]
        if not pdf.exists():
            print("missing pdf", pdf)
            fail.append(sid)
            continue
        good = import_one(
            sid=sid,
            source=src,
            title=item["title"],
            artist=item["artist"],
            genre=item["genre"],
            difficulty=item["difficulty"],
            description=DESC_JIANPU,
            pdf=pdf,
        )
        (ok if good else fail).append(sid)

    print("OK:", ", ".join(ok))
    print("FAIL:", ", ".join(fail))
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
