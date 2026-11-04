"""Retry failed Downloads OMR imports with fixed preprocess + sheet-merge."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(r"F:\commercial\PianoFlow")
sys.path.insert(0, str(REPO / "scripts"))
from _batch_import_downloads_pdfs import SCORES, find_pdf, finish_import, run_audiveris  # noqa: E402


def main() -> int:
    report = REPO / "docs/omr_audit/_batch_import_report.json"
    fail = json.loads(report.read_text(encoding="utf-8")).get("fail") or []
    cat = {
        s["id"]
        for s in json.loads((REPO / "assets/scores/catalog.json").read_text(encoding="utf-8"))["songs"]
    }
    # Always retry ids not yet in catalog; also accept CLI ids.
    todo = [a for a in sys.argv[1:] if a] or [sid for sid in fail if sid not in cat]
    # kuusou may already have a merged draft from manual pilot
    meta = {r[0]: r for r in SCORES}
    ok, bad = [], []
    for sid in todo:
        row = meta[sid]
        pdf = find_pdf(row[5])
        print(f"\n### {sid} ← {pdf.name if pdf else None}", flush=True)
        if pdf is None:
            bad.append(sid)
            continue
        work = REPO / "third_party/scores_musicxml/_omr_work" / sid
        for name in ("source_staff300.pdf",):
            p = work / name
            if p.exists():
                try:
                    p.unlink()
                except OSError:
                    pass
        try:
            draft = run_audiveris(sid, pdf)
            if draft is None:
                bad.append(sid)
                continue
            code = finish_import(sid, row[1], row[2], row[3], row[4])
            if code == 0:
                ok.append(sid)
            else:
                print(f"  import exit={code}", flush=True)
                bad.append(sid)
        except Exception as e:
            print(f"  ERROR {e}", flush=True)
            bad.append(sid)

    out = REPO / "docs/omr_audit/_batch_retry_report.json"
    out.write_text(json.dumps({"ok": ok, "fail": bad}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nRETRY DONE ok={len(ok)} fail={len(bad)} → {out}", flush=True)
    return 0 if not bad else 2


if __name__ == "__main__":
    raise SystemExit(main())
