"""Enterprise batch OMR import: PDF list → omrDraft (never formal).

Usage:
  python scripts/omr_batch_import.py --manifest path.json
  python scripts/omr_batch_import.py --id foo --pdf path.pdf --title "T" --artist "A"
  python scripts/omr_batch_import.py --resume docs/omr_audit/_omr_batch_report.json

Manifest JSON:
  [{"id":"...","pdf":"...","title":"...","artist":"...","genre":"Anime","difficulty":3}, ...]
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from omr_pipeline import run_omr  # noqa: E402

PS = "powershell.exe"
REPORT = REPO / "docs/omr_audit/_omr_batch_report.json"


def finish_import(
    score_id: str,
    title: str,
    artist: str,
    genre: str,
    difficulty: int,
) -> int:
    desc = (
        f"OMR草稿（Audiveris←PDF）。对照 third_party/scores_pdf/{score_id}.pdf。"
        f"未逐音校对，不可升正式谱。非 MIDI。"
    )
    cmd = [
        PS,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(REPO / "scripts/omr-finish-import.ps1"),
        "-Id",
        score_id,
        "-Title",
        title,
        "-Artist",
        artist,
        "-Genre",
        genre,
        "-Difficulty",
        str(difficulty),
        "-Description",
        desc,
        "-ForceOmr",
    ]
    print(f"  import-score {score_id} …", flush=True)
    return subprocess.run(cmd, cwd=str(REPO)).returncode


def load_jobs(args: argparse.Namespace) -> list[dict]:
    if args.manifest:
        data = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise SystemExit("manifest must be a JSON list")
        return data
    if args.resume:
        prev = json.loads(Path(args.resume).read_text(encoding="utf-8"))
        fail = prev.get("fail") or []
        jobs = prev.get("jobs") or []
        by_id = {j["id"]: j for j in jobs}
        return [by_id[i] for i in fail if i in by_id]
    if args.id and args.pdf:
        return [
            {
                "id": args.id,
                "pdf": args.pdf,
                "title": args.title or args.id,
                "artist": args.artist or "Unknown",
                "genre": args.genre,
                "difficulty": args.difficulty,
            }
        ]
    raise SystemExit("need --manifest, --resume, or --id + --pdf")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", type=Path)
    ap.add_argument("--resume", type=Path)
    ap.add_argument("--id")
    ap.add_argument("--pdf")
    ap.add_argument("--title", default="")
    ap.add_argument("--artist", default="")
    ap.add_argument("--genre", default="Classical", choices=["Classical", "Anime", "Pop", "Game"])
    ap.add_argument("--difficulty", type=int, default=3)
    ap.add_argument("--omr-only", action="store_true", help="skip catalog import")
    args = ap.parse_args()

    jobs = load_jobs(args)
    ok, fail = [], []
    for i, job in enumerate(jobs, 1):
        sid = job["id"]
        pdf = Path(job["pdf"])
        print(f"\n[{i}/{len(jobs)}] {sid} ← {pdf}", flush=True)
        if not pdf.is_file():
            print("  MISSING pdf")
            fail.append(sid)
            continue
        try:
            draft = run_omr(sid, pdf)
            if draft is None:
                fail.append(sid)
                continue
            if args.omr_only:
                ok.append(sid)
                continue
            code = finish_import(
                sid,
                job.get("title") or sid,
                job.get("artist") or "Unknown",
                job.get("genre") or "Classical",
                int(job.get("difficulty") or 3),
            )
            if code == 0:
                ok.append(sid)
            else:
                print(f"  import exit={code}")
                fail.append(sid)
        except Exception as e:
            print(f"  ERROR {e}")
            fail.append(sid)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        json.dumps({"ok": ok, "fail": fail, "jobs": jobs}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nBATCH DONE ok={len(ok)} fail={len(fail)} → {REPORT}")
    return 0 if not fail else 2


if __name__ == "__main__":
    raise SystemExit(main())
