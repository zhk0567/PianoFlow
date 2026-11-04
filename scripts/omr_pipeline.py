"""Enterprise OMR pipeline core: preprocess → Audiveris → sheet-merge → draft.

Used by:
  - scripts/omr_batch_import.py
  - scripts/omr-from-pdf.ps1 (via --preprocess-only / full run)
  - scripts/_batch_import_downloads_pdfs.py (re-export)

Never promotes to formal. Output is always omr_draft under _omr_work/<id>/.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

import fitz
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
PDF_DIR = REPO / "third_party/scores_pdf"
OMR_WORK = REPO / "third_party/scores_musicxml/_omr_work"
AUDIVERIS = REPO / (
    "third_party/omr/Audiveris-5.11.0-windows-x86_64/SourceDir/Audiveris/Audiveris.exe"
)


def find_audiveris(preferred: str | Path | None = None) -> Path | None:
    if preferred:
        p = Path(preferred)
        if p.is_file():
            return p
    candidates = [
        AUDIVERIS,
        REPO / "third_party/omr/Audiveris/Audiveris.exe",
        REPO / "third_party/omr/audiveris/Audiveris.exe",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def _page_has_staves(pix: fitz.Pixmap) -> bool:
    img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples).convert("L")
    w, h = img.size
    target_w = 900
    if w > target_w:
        img = img.resize((target_w, max(1, h * target_w // w)), Image.Resampling.BILINEAR)
        w, h = img.size
    px = img.load()
    dark_rows = 0
    step = max(1, h // 400)
    for y in range(0, h, step):
        run = 0
        best = 0
        for x in range(w):
            if px[x, y] < 180:
                run += 1
                best = max(best, run)
            else:
                run = 0
        if best >= w * 0.28:
            dark_rows += 1
    return dark_rows >= 12


def _render_zoom_for_page(page: fitz.Page, dpi: int = 300, max_pixels: int = 18_000_000) -> float:
    w, h = float(page.rect.width), float(page.rect.height)
    if w <= 0 or h <= 0:
        return 1.0
    if w >= 1500 or h >= 1500 or (w * h) >= 1_500_000:
        zoom = 1.0
    else:
        zoom = dpi / 72.0
    if w * zoom < 1800:
        zoom = max(zoom, 2400.0 / w)
    while (w * zoom) * (h * zoom) > max_pixels and zoom > 0.2:
        zoom *= 0.85
    return zoom


def preprocess_pdf_for_omr(src_pdf: Path, dest_pdf: Path, dpi: int = 300) -> tuple[int, int]:
    """Rasterize staff pages; MediaBox sized so Audiveris @300dpi == pixmap pixels."""
    doc = fitz.open(src_pdf)
    out = fitz.open()
    kept = 0
    max_pixels = 18_000_000
    for i in range(len(doc)):
        page = doc[i]
        zoom = _render_zoom_for_page(page, dpi=dpi, max_pixels=max_pixels)
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        while pix.width * pix.height > max_pixels and zoom > 0.15:
            zoom *= 0.85
            pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        if not _page_has_staves(pix):
            continue
        w_pt = pix.width * 72.0 / 300.0
        h_pt = pix.height * 72.0 / 300.0
        npage = out.new_page(width=w_pt, height=h_pt)
        npage.insert_image(npage.rect, pixmap=pix)
        kept += 1
    total = len(doc)
    doc.close()
    if kept == 0:
        out.close()
        raise RuntimeError(f"no staff pages detected in {src_pdf.name}")
    dest_pdf.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest_pdf, deflate=True, garbage=3)
    out.close()
    return kept, total


def _find_export(work: Path, out: Path) -> Path | None:
    candidates: list[Path] = []
    for pattern in ("*.mxl", "*.musicxml"):
        candidates.extend(out.rglob(pattern))
        candidates.extend(work.rglob(pattern))
    skip = {"playlist.xml", "omr_draft.musicxml", "omr_draft.mxl"}
    candidates = [
        c
        for c in candidates
        if c.name.lower() not in skip
        and "meta" not in c.name.lower()
        and "sheet_parts" not in c.parts
        and "pages" not in c.parts
    ]
    if not candidates:
        return None
    candidates.sort(key=lambda p: (0 if p.suffix.lower() == ".mxl" else 1, -p.stat().st_size))
    return candidates[0]


def _read_musicxml_bytes(path: Path) -> bytes:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path) as zf:
            names = [
                n
                for n in zf.namelist()
                if n.endswith((".musicxml", ".xml")) and not n.startswith("META")
            ]
            if not names:
                raise RuntimeError(f"no xml in {path}")
            names.sort(key=lambda n: (0 if "score" in n.lower() else 1, len(n)))
            return zf.read(names[0])
    return path.read_bytes()


def _xml_local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def merge_partwise(xml_paths: list[Path], dest: Path) -> None:
    roots = [ET.fromstring(_read_musicxml_bytes(p)) for p in xml_paths]
    base = roots[0]
    parts = {el.get("id"): el for el in base if _xml_local(el.tag) == "part" and el.get("id")}
    if not parts:
        raise RuntimeError("base score has no parts")
    for root in roots[1:]:
        for part in root:
            if _xml_local(part.tag) != "part":
                continue
            pid = part.get("id")
            if pid not in parts:
                base.append(part)
                parts[pid] = part
                continue
            target = parts[pid]
            for child in list(part):
                if _xml_local(child.tag) == "measure":
                    target.append(child)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tree = ET.ElementTree(base)
    ET.indent(tree, space="  ")
    tree.write(dest, encoding="utf-8", xml_declaration=True)


def export_sheets_and_merge(omr: Path, work: Path, audiveris: Path, max_sheets: int = 40) -> Path | None:
    parts_dir = work / "sheet_parts"
    if parts_dir.exists():
        shutil.rmtree(parts_dir, ignore_errors=True)
    parts_dir.mkdir(parents=True, exist_ok=True)
    export_mxl = omr.with_suffix(".mxl")
    ok: list[Path] = []
    log = work / "audiveris_sheet_export.log"
    with open(log, "w", encoding="utf-8", errors="replace") as lf:
        for n in range(1, max_sheets + 1):
            if export_mxl.exists():
                try:
                    export_mxl.unlink()
                except OSError:
                    pass
            lf.write(f"\n--- sheet {n} ---\n")
            lf.flush()
            proc = subprocess.run(
                [
                    str(audiveris),
                    "-batch",
                    "-export",
                    "-force",
                    "-sheets",
                    str(n),
                    "-output",
                    str(omr.parent),
                    str(omr),
                ],
                cwd=str(audiveris.parent),
                stdout=lf,
                stderr=subprocess.STDOUT,
                timeout=60 * 5,
            )
            chunk = Path(log).read_text(encoding="utf-8", errors="replace")
            section = chunk.rsplit(f"--- sheet {n} ---", 1)[-1]
            if f"No sheet #{n}" in section:
                lf.write(f"stop: no sheet #{n}\n")
                break
            cands = list(omr.parent.glob("*.mxl"))
            if not cands:
                lf.write(f"sheet {n}: no mxl (exit={proc.returncode})\n")
                if n >= 3 and not ok:
                    break
                continue
            src = max(cands, key=lambda p: p.stat().st_mtime)
            dest = parts_dir / f"p{n:02d}.mxl"
            shutil.copy2(src, dest)
            ok.append(dest)
            lf.write(f"sheet {n}: OK {dest.stat().st_size} bytes\n")
    if not ok:
        return None
    if len(ok) == 1:
        dest = work / "omr_draft.mxl"
        shutil.copy2(ok[0], dest)
        return dest
    merged = work / "omr_draft.musicxml"
    merge_partwise(ok, merged)
    return merged


def run_omr(
    score_id: str,
    pdf: Path,
    *,
    archive_pdf: bool = True,
    audiveris_exe: Path | None = None,
) -> Path | None:
    """Full OMR → omr_draft.mxl|musicxml under _omr_work/<id>/."""
    audiveris = audiveris_exe or find_audiveris()
    if audiveris is None or not audiveris.is_file():
        print("Audiveris missing", file=sys.stderr)
        return None

    work = OMR_WORK / score_id
    out = work / "audiveris_out"
    work.mkdir(parents=True, exist_ok=True)
    if out.exists():
        shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True, exist_ok=True)

    PDF_DIR.mkdir(parents=True, exist_ok=True)
    if archive_pdf:
        shutil.copy2(pdf, PDF_DIR / f"{score_id}.pdf")
    src_copy = work / "source.pdf"
    shutil.copy2(pdf, src_copy)

    clean = work / "source_staff300.pdf"
    try:
        kept, total = preprocess_pdf_for_omr(src_copy, clean, dpi=300)
        print(f"  preprocess: kept {kept}/{total} staff pages @300dpi", flush=True)
        feed = clean
    except Exception as e:
        print(f"  preprocess fallback (raw PDF): {e}", flush=True)
        feed = src_copy

    log = work / "audiveris_batch.log"
    print(f"  Audiveris → {score_id} …", flush=True)
    t0 = time.time()
    with open(log, "w", encoding="utf-8", errors="replace") as lf:
        proc = subprocess.run(
            [
                str(audiveris),
                "-batch",
                "-export",
                "-force",
                "-output",
                str(out),
                str(feed),
            ],
            cwd=str(audiveris.parent),
            stdout=lf,
            stderr=subprocess.STDOUT,
            timeout=60 * 45,
        )
    print(f"  exit={proc.returncode} in {time.time() - t0:.0f}s", flush=True)

    best = _find_export(work, out)
    if best is None:
        omrs = [
            p
            for p in (list(out.rglob("*.omr")) + list(work.rglob("*.omr")))
            if "sheet_parts" not in p.parts
        ]
        if omrs:
            omr = max(omrs, key=lambda p: p.stat().st_mtime)
            for sheets in ("2-99", "1-99"):
                print(f"  retry export {omr.name} -sheets {sheets}", flush=True)
                with open(log, "a", encoding="utf-8", errors="replace") as lf:
                    lf.write(f"\n--- retry -sheets {sheets} ---\n")
                    subprocess.run(
                        [
                            str(audiveris),
                            "-batch",
                            "-export",
                            "-force",
                            "-sheets",
                            sheets,
                            "-output",
                            str(out),
                            str(omr),
                        ],
                        cwd=str(audiveris.parent),
                        stdout=lf,
                        stderr=subprocess.STDOUT,
                        timeout=60 * 20,
                    )
                best = _find_export(work, out)
                if best is not None:
                    break
            if best is None:
                print(f"  sheet-merge export from {omr.name} …", flush=True)
                best = export_sheets_and_merge(omr, work, audiveris)

    if best is None:
        print(f"  FAIL: no MusicXML for {score_id}", flush=True)
        return None
    dest = work / f"omr_draft{best.suffix.lower()}"
    if best.resolve() != dest.resolve():
        shutil.copy2(best, dest)
    print(f"  draft: {dest.name} ({dest.stat().st_size} bytes)", flush=True)
    return dest


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser(description="PianoFlow enterprise OMR pipeline")
    ap.add_argument("--id", required=True)
    ap.add_argument("--pdf", required=True, type=Path)
    ap.add_argument("--preprocess-only", action="store_true")
    ap.add_argument("--audiveris", type=Path, default=None)
    args = ap.parse_args()
    pdf = args.pdf.resolve()
    if not pdf.is_file():
        print("PDF not found:", pdf, file=sys.stderr)
        return 1
    work = OMR_WORK / args.id
    work.mkdir(parents=True, exist_ok=True)
    shutil.copy2(pdf, work / "source.pdf")
    if args.preprocess_only:
        clean = work / "source_staff300.pdf"
        kept, total = preprocess_pdf_for_omr(pdf, clean)
        print(f"PREPROCESS OK kept={kept}/{total} → {clean}")
        return 0
    draft = run_omr(args.id, pdf, audiveris_exe=args.audiveris)
    return 0 if draft else 2


if __name__ == "__main__":
    raise SystemExit(main())
