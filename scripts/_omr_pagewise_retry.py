"""Retry failed Audiveris books by OMR'ing each page separately, then merge MXL.

Usage:
  python scripts/_omr_pagewise_retry.py id1 id2 ...
  python scripts/_omr_pagewise_retry.py --from-report
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(r"F:\commercial\PianoFlow")
sys.path.insert(0, str(REPO / "scripts"))
from _batch_import_downloads_pdfs import (  # noqa: E402
    AUDIVERIS,
    OMR_WORK,
    PDF_DIR,
    SCORES,
    _find_export,
    finish_import,
    merge_partwise,
    preprocess_pdf_for_omr,
)

PS = "powershell.exe"


def _run_audiveris_one(pdf: Path, out: Path, log: Path) -> Path | None:
    out.mkdir(parents=True, exist_ok=True)
    with open(log, "a", encoding="utf-8", errors="replace") as lf:
        lf.write(f"\n--- pagewise {pdf.name} ---\n")
        proc = subprocess.run(
            [
                str(AUDIVERIS),
                "-batch",
                "-export",
                "-force",
                "-output",
                str(out),
                str(pdf),
            ],
            cwd=str(AUDIVERIS.parent),
            stdout=lf,
            stderr=subprocess.STDOUT,
            timeout=60 * 20,
        )
        lf.write(f"exit={proc.returncode}\n")
    return _find_export(out, out)


def pagewise_omr(score_id: str) -> Path | None:
    work = OMR_WORK / score_id
    work.mkdir(parents=True, exist_ok=True)
    src = work / "source.pdf"
    if not src.is_file():
        pdf_repo = PDF_DIR / f"{score_id}.pdf"
        if not pdf_repo.is_file():
            print(f"  no source pdf for {score_id}")
            return None
        shutil.copy2(pdf_repo, src)

    clean = work / "source_staff300.pdf"
    # Always rebuild — prior runs may have oversize rasters that Audiveris rejects.
    kept, total = preprocess_pdf_for_omr(src, clean, dpi=300)
    print(f"  preprocess kept {kept}/{total}")

    import fitz

    doc = fitz.open(clean)
    page_dir = work / "pages"
    if page_dir.exists():
        shutil.rmtree(page_dir)
    page_dir.mkdir()
    exports: list[Path] = []
    log = work / "audiveris_pagewise.log"
    if log.exists():
        log.unlink()

    for i in range(len(doc)):
        single = fitz.open()
        single.insert_pdf(doc, from_page=i, to_page=i)
        page_pdf = page_dir / f"p{i+1:02d}.pdf"
        single.save(page_pdf)
        single.close()
        out = page_dir / f"out_{i+1:02d}"
        print(f"  page {i+1}/{len(doc)} …", flush=True)
        t0 = time.time()
        got = _run_audiveris_one(page_pdf, out, log)
        print(f"    {'OK' if got else 'FAIL'} in {time.time()-t0:.0f}s", flush=True)
        if got:
            exports.append(got)
    doc.close()

    if not exports:
        print(f"  pagewise FAIL: zero pages for {score_id}")
        return None

    merged = work / "omr_draft.musicxml"
    if len(exports) == 1:
        data = _read_musicxml_bytes(exports[0])
        merged.write_bytes(data)
    else:
        merge_partwise(exports, merged)
    print(f"  merged {len(exports)} pages → {merged.name} ({merged.stat().st_size} bytes)")
    return merged


def meta_for(score_id: str):
    for row in SCORES:
        if row[0] == score_id:
            return row[0], row[1], row[2], row[3], row[4]
    return None


def main() -> int:
    args = sys.argv[1:]
    ids: list[str] = []
    if args == ["--from-report"] or (not args):
        report = REPO / "docs/omr_audit/_batch_import_report.json"
        if report.is_file():
            data = json.loads(report.read_text(encoding="utf-8"))
            ids = list(data.get("fail") or [])
        else:
            print("no report yet", file=sys.stderr)
            return 1
    else:
        ids = args

    ok, fail = [], []
    for sid in ids:
        print(f"\n=== pagewise {sid} ===", flush=True)
        meta = meta_for(sid)
        if not meta:
            print("  unknown id")
            fail.append(sid)
            continue
        try:
            draft = pagewise_omr(sid)
            if draft is None:
                fail.append(sid)
                continue
            code = finish_import(meta[0], meta[1], meta[2], meta[3], meta[4])
            if code != 0:
                fail.append(sid)
            else:
                ok.append(sid)
        except Exception as e:
            print(f"  ERROR: {e}")
            fail.append(sid)

    out = REPO / "docs/omr_audit/_pagewise_retry_report.json"
    out.write_text(json.dumps({"ok": ok, "fail": fail}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nPAGEWISE DONE ok={len(ok)} fail={len(fail)} → {out}")
    return 0 if not fail else 2


if __name__ == "__main__":
    raise SystemExit(main())
