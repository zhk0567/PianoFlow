# -*- coding: utf-8 -*-
"""Direct Python import path (bypasses fragile PowerShell Unicode)."""
from __future__ import annotations

import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "third_party" / "scores_pdf"
WORK = ROOT / "third_party" / "scores_musicxml" / "_omr_work"
TP_XML = ROOT / "third_party" / "scores_musicxml"
AS_XML = ROOT / "assets" / "scores" / "musicxml"
DOWNLOADS = Path(r"C:\Users\32834\Downloads")


def run(cmd: list[str]) -> None:
    print("+", " ".join(str(c) for c in cmd))
    p = subprocess.run(cmd, cwd=str(ROOT))
    if p.returncode != 0:
        raise RuntimeError(f"cmd failed ({p.returncode}): {cmd}")


def ensure_musicxml(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.suffix.lower() == ".mxl":
        with zipfile.ZipFile(src) as zf:
            names = [
                n
                for n in zf.namelist()
                if n.lower().endswith((".musicxml", ".xml"))
                and not n.startswith("META-INF")
            ]
            if not names:
                raise RuntimeError(f"no xml in {src}")
            data = zf.read(names[0])
        dest.write_bytes(data)
    else:
        shutil.copy2(src, dest)


def import_score(
    *,
    sid: str,
    source: Path,
    title: str,
    artist: str,
    genre: str,
    difficulty: int,
    description: str,
    pdf_src: Path | None = None,
) -> None:
    run(
        [
            sys.executable,
            str(ROOT / "scripts" / "catalog_score_kind_guard.py"),
            "--check-source",
            str(source),
            "--score-kind",
            "omrDraft",
            "--id",
            sid,
        ]
    )

    tp = TP_XML / f"{sid}.musicxml"
    ensure_musicxml(source, tp)
    AS_XML.mkdir(parents=True, exist_ok=True)
    shutil.copy2(tp, AS_XML / f"{sid}.musicxml")

    if pdf_src is not None and pdf_src.exists():
        PDF_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pdf_src, PDF_DIR / f"{sid}.pdf")

    run(
        [
            sys.executable,
            str(ROOT / "scripts" / "musicxml_to_score.py"),
            "--id",
            sid,
            "--input",
            str(tp),
            "--update-catalog",
            "--score-kind",
            "omrDraft",
            "--genre",
            genre,
            "--difficulty",
            str(difficulty),
            "--title",
            title,
            "--artist",
            artist,
            "--description",
            description,
        ]
    )
    run(
        [
            sys.executable,
            str(ROOT / "scripts" / "score_kind_policy_sync.py"),
            "--add-id",
            sid,
        ]
    )


def main() -> int:
    items = [
        {
            "id": "rush_e",
            "title": "Rush E",
            "artist": "Sheet Music Boss / Andrew Wrangell",
            "genre": "Classical",
            "difficulty": 5,
            "source": WORK / "rush_e" / "omr_draft.mxl",
            "pdf": DOWNLOADS / "Rush E.pdf",
            "desc": "OMR draft from staff PDF via Audiveris. Not proofread. Local practice only.",
        },
        {
            "id": "xiao_xing_xing",
            "title": "小星星",
            "artist": "Traditional / Twinkle Twinkle Little Star",
            "genre": "Classical",
            "difficulty": 1,
            "source": WORK / "xiao_xing_xing" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "小星星.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "fen_shua_jiang",
            "title": "粉刷匠",
            "artist": "Traditional / Polish folk",
            "genre": "Pop",
            "difficulty": 1,
            "source": WORK / "fen_shua_jiang" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "粉刷匠.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "blowin_in_the_wind",
            "title": "Blowin' In The Wind",
            "artist": "Bob Dylan",
            "genre": "Pop",
            "difficulty": 2,
            "source": WORK / "blowin_in_the_wind" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "Blowin' In The Wind.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "bella_ciao",
            "title": "Bella Ciao",
            "artist": "Traditional / Italian folk",
            "genre": "Pop",
            "difficulty": 2,
            "source": WORK / "bella_ciao" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "Bella Ciao.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "when_you_wish_upon_a_star",
            "title": "When You Wish Upon a Star",
            "artist": "Leigh Harline / Ned Washington",
            "genre": "Pop",
            "difficulty": 2,
            "source": WORK / "when_you_wish_upon_a_star" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "When You Wish Upon a Star.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "whistle",
            "title": "Whistle",
            "artist": "Flo Rida",
            "genre": "Pop",
            "difficulty": 3,
            "source": WORK / "whistle" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "Whistle.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "pure_imagination",
            "title": "Pure Imagination",
            "artist": "Leslie Bricusse / Anthony Newley",
            "genre": "Pop",
            "difficulty": 3,
            "source": WORK / "pure_imagination" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "Pure Imagination.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "ju_hua_tai",
            "title": "菊花台",
            "artist": "周杰伦",
            "genre": "Pop",
            "difficulty": 3,
            "source": WORK / "ju_hua_tai" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "菊花台.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "ye_de_gang_qin_qu_5",
            "title": "夜的钢琴曲五",
            "artist": "石进",
            "genre": "Classical",
            "difficulty": 3,
            "source": WORK / "ye_de_gang_qin_qu_5" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "夜的钢琴曲五.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
        {
            "id": "an_he_qiao",
            "title": "安和桥",
            "artist": "宋冬野",
            "genre": "Pop",
            "difficulty": 2,
            "source": WORK / "an_he_qiao" / "jianpu_draft.musicxml",
            "pdf": DOWNLOADS / "安和桥.pdf",
            "desc": "Jianpu PDF transcribed to MusicXML (draft). Not Audiveris. omrDraft.",
        },
    ]

    ok, fail = [], []
    for it in items:
        sid = it["id"]
        print(f"======== {sid} ========")
        try:
            if not it["source"].exists():
                raise FileNotFoundError(it["source"])
            import_score(
                sid=sid,
                source=it["source"],
                title=it["title"],
                artist=it["artist"],
                genre=it["genre"],
                difficulty=it["difficulty"],
                description=it["desc"],
                pdf_src=it["pdf"],
            )
            ok.append(sid)
        except Exception as e:
            print("FAIL", sid, e)
            fail.append(sid)

    print("Running guards...")
    try:
        run([sys.executable, str(ROOT / "scripts" / "catalog_score_kind_guard.py")])
        run([sys.executable, str(ROOT / "scripts" / "catalog_integrity_guard.py")])
        run([sys.executable, str(ROOT / "scripts" / "score_kind_policy_sync.py"), "--check"])
    except Exception as e:
        print("guard fail", e)
        return 1

    print("OK:", ", ".join(ok))
    print("FAIL:", ", ".join(fail))
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
