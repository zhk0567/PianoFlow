"""Copy Downloads PDFs → scores_pdf, run Audiveris OMR, import as omrDraft.

Duplicates in the catalog are overwritten (-ForceOmr). Same-piece duplicates
in this batch prefer the Animenz / A叔「原版」PDF when both are present.

Cover / non-staff pages are stripped and remaining pages are re-rendered at
~300 DPI so Audiveris can export MusicXML.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

import fitz
from PIL import Image

REPO = Path(r"F:\commercial\PianoFlow")
DL = Path(r"C:\Users\32834\Downloads")
PDF_DIR = REPO / "third_party/scores_pdf"
OMR_WORK = REPO / "third_party/scores_musicxml/_omr_work"
AUDIVERIS = REPO / (
    "third_party/omr/Audiveris-5.11.0-windows-x86_64/SourceDir/Audiveris/Audiveris.exe"
)
PS = "powershell.exe"

# (id, title, artist, genre, difficulty, preferred_filename_substrings…)
# Later rows with the same id overwrite earlier PDF choices.
SCORES: list[tuple] = [
    ("animenz_hikaru_nara", "Hikaru Nara / 若能绽放光芒", "Animenz", "Anime", 4,
     ["【A叔原版】Hikaru Nara", "若能绽放光芒 四月是你的谎言【Animenz】"]),
    ("queen_bohemian_rhapsody", "波西米亚狂想曲", "Queen", "Classical", 5,
     ["波西米亚狂想曲.pdf"]),
    ("merry_christmas_mr_lawrence", "圣诞快乐，劳伦斯先生", "Ryuichi Sakamoto", "Classical", 3,
     ["圣诞快乐劳伦斯先生"]),
    ("justin_bieber_love_yourself", "Love Yourself", "Justin Bieber", "Pop", 3,
     ["JustinBieber.pdf"]),
    ("animenz_unravel", "unravel", "Animenz", "Anime", 4,
     ["unravel【Animenz】"]),
    ("animenz_kuusou_mesorogiwi", "狂六 / 空想メソロギヰ", "Animenz", "Anime", 5,
     ["狂六.pdf"]),
    ("i_really_want_to_stay_at_your_house", "I Really Want to Stay at Your House", "Rosa Walton / Hallie Coggins", "Anime", 4,
     ["I Really Want to Stay at Your House"]),
    ("animenz_key_trilogy", "Key社三组曲", "Animenz", "Anime", 4,
     ["Key社三组曲"]),
    ("long_zu_theme", "龙族", "Unknown", "Anime", 3,
     ["龙族.pdf"]),
    ("jojo_steel_ball_run_dance", "Dance with STEEL BALL RUN", "Yugo Kanno", "Anime", 4,
     ["STEEL BALL RUN"]),
    ("are_you_lost", "Are You Lost", "park bird", "Pop", 3,
     ["Are You Lost"]),
    ("utada_beautiful_world", "Beautiful World", "Utada Hikaru", "Anime", 3,
     ["Beautiful World"]),
    ("animenz_merry_go_round_of_life", "Merry-Go-Round of Life / 人生的旋转木马", "Animenz", "Anime", 4,
     ["Merry-Go-Round of Life"]),
    ("chu_bu_ke_ji", "触不可及", "Unknown", "Pop", 3,
     ["触不可及"]),
    ("jue_bie_shu", "诀别书", "Unknown", "Pop", 3,
     ["诀别书.pdf"]),
    ("truth_that_you_leave", "你离开的真相 / The Truth That You Leave", "Pianoboy", "Pop", 3,
     ["你离开的真相", "你离开的事实"]),
    ("sawano_call_of_silence", "Call of Silence", "Hiroyuki Sawano / Animenz", "Anime", 3,
     ["Call of silence"]),
    ("animenz_uchiage_hanabi", "打上花火", "Animenz", "Anime", 4,
     ["打上花火"]),
    ("utada_one_last_kiss", "One Last Kiss", "Utada Hikaru", "Anime", 3,
     ["One Last Kiss.pdf"]),
    ("animenz_akuma_no_ko", "恶魔之子", "Animenz", "Anime", 4,
     ["恶魔之子"]),
    ("animenz_guren_no_yumiya", "红莲的弓矢", "Animenz", "Anime", 4,
     ["红莲的弓矢"]),
    ("animenz_aoi_tori", "青鸟", "Animenz", "Anime", 4,
     ["青鸟【Animenzzz】"]),
    ("animenz_secret_base", "未闻花名 / secret base", "Animenz", "Anime", 3,
     ["未闻花名"]),
    ("animenz_grand_escape", "Grand Escape", "Animenz", "Anime", 4,
     ["【A叔原版】Grand Escape", "Animenz_Grand_Escape"]),
    ("bios_guilty_crown", "Bios（十周年版）", "Hiroyuki Sawano", "Anime", 4,
     ["Bios（十周年版）"]),
    ("animenz_my_dearest", "My Dearest", "Animenz", "Anime", 4,
     ["My Dearest"]),
    ("tori_no_uta", "鸟之诗", "Lia / Key", "Anime", 3,
     ["鸟之诗.pdf"]),
    ("animenz_dango_daikazoku", "团子大家族", "Animenz", "Anime", 3,
     ["dango daikazoku"]),
    ("animenz_will", "WILL", "Animenz", "Anime", 4,
     ["【A叔原版】WILL"]),
    ("rachmaninoff_op32_no5", "Prelude Op.32 No.5", "Sergei Rachmaninoff", "Classical", 4,
     ["Op.32 no.5"]),
    ("chopin_nocturne_accordion", "肖邦夜曲（手风琴谱）", "Frédéric Chopin", "Classical", 3,
     ["肖邦夜曲手风琴"]),
    ("kexi_mei_ruguo", "可惜没如果", "Roman Ye Zhuo / JJ Lin", "Pop", 3,
     ["可惜没如果"]),
    ("everyday_world_oregairu", "Everyday World", "Yanagi Nagi", "Anime", 3,
     ["Everyday World"]),
    ("rachmaninoff_prelude_g_minor", "g小调前奏曲 Op.23 No.5", "Sergei Rachmaninoff", "Classical", 5,
     ["拉赫玛尼诺夫g小调前奏曲.pdf", "拉赫玛尼诺夫g小调前奏曲 (1).pdf"]),
    ("animenz_iris_out", "IRIS OUT", "Animenz", "Anime", 4,
     ["IRIS OUT"]),
    ("wang_leehom_ai_cuo", "爱错", "王力宏", "Pop", 3,
     ["爱错"]),
    ("ye_de_gang_qin_qu_5", "夜的钢琴曲五", "石进", "Classical", 2,
     ["夜的钢琴曲五"]),
    ("shan_yichun_zhu_yu", "珠玉", "单依纯", "Pop", 3,
     ["珠玉"]),
    ("guo_jing_aiqing_xunxi", "爱情讯息", "郭静", "Pop", 3,
     ["爱情讯息"]),
    ("matryoshka_sacred_play", "Matryoshka / Sacred Play Secret Place", "Unknown", "Game", 4,
     ["matryoshka"]),
    ("zhou_shen_lian_min", "怜悯", "周深", "Pop", 3,
     ["怜悯"]),
    ("sa_ye", "撒野", "凯瑟喵", "Pop", 3,
     ["撒野"]),
    ("sincerely_violet_evergarden", "Sincerely", "TRUE", "Anime", 3,
     ["Sincerely"]),
    ("animenz_avid", "Avid", "Animenz", "Anime", 4,
     ["Avid 不存在的战区"]),
]


def find_pdf(subs: list[str]) -> Path | None:
    """Prefer the first matching substring that hits exactly one/latest file."""
    pdfs = list(DL.glob("*.pdf"))
    for sub in subs:
        hits = [p for p in pdfs if sub in p.name]
        if not hits:
            continue
        # Prefer A叔原版 / larger file when several match.
        hits.sort(key=lambda p: (("【A叔原版】" not in p.name), -p.stat().st_size))
        return hits[0]
    return None


def _page_has_staves(pix: fitz.Pixmap) -> bool:
    """Heuristic: enough dark near-horizontal runs → likely staff page."""
    img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples).convert("L")
    # Downsample for speed (keep enough vertical resolution for thin staff lines)
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
                if run > best:
                    best = run
            else:
                run = 0
        if best >= w * 0.28:
            dark_rows += 1
    return dark_rows >= 12


def _render_zoom_for_page(page: fitz.Page, dpi: int = 300, max_pixels: int = 18_000_000) -> float:
    """Choose zoom so Audiveris stays under its ~20MP image limit.

    Many Chinese pop sheet PDFs store each page as a full-resolution image with
    the MediaBox already in pixel units (e.g. 2279×3401 pt). Applying 300 DPI
    on top of that blows past Audiveris limits — use zoom≈1 for those.
    """
    w, h = float(page.rect.width), float(page.rect.height)
    if w <= 0 or h <= 0:
        return 1.0
    # Heuristic: MediaBox already pixel-sized
    if w >= 1500 or h >= 1500 or (w * h) >= 1_500_000:
        zoom = 1.0
    else:
        zoom = dpi / 72.0
    # Raise tiny pages (e.g. accordion scans ~216×291 pt) toward ~2400px width
    if w * zoom < 1800:
        zoom = max(zoom, 2400.0 / w)
    while (w * zoom) * (h * zoom) > max_pixels and zoom > 0.2:
        zoom *= 0.85
    return zoom


def preprocess_pdf_for_omr(src_pdf: Path, dest_pdf: Path, dpi: int = 300) -> tuple[int, int]:
    """Rasterize staff pages into a clean PDF under Audiveris pixel limits."""
    doc = fitz.open(src_pdf)
    out = fitz.open()
    kept = 0
    max_pixels = 18_000_000
    for i in range(len(doc)):
        page = doc[i]
        zoom = _render_zoom_for_page(page, dpi=dpi, max_pixels=max_pixels)
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        # Hard cap: Audiveris rejects sheets above ~20MP
        while pix.width * pix.height > max_pixels and zoom > 0.15:
            zoom *= 0.85
            pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        if not _page_has_staves(pix):
            continue
        # Audiveris rasterizes from MediaBox at ~300 DPI. Size the page so that
        # (MediaBox_pt * 300/72) == pixmap pixels — otherwise it upscales past 20MP.
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
    # Drop obvious non-exports / intermediates
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
    """Concatenate partwise scores: append measures from later pages into parts."""
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


def _export_sheets_and_merge(omr: Path, work: Path, max_sheets: int = 40) -> Path | None:
    """When whole-book export fails (one bad sheet), export sheets 1..N and merge."""
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
                    str(AUDIVERIS),
                    "-batch",
                    "-export",
                    "-force",
                    "-sheets",
                    str(n),
                    "-output",
                    str(omr.parent),
                    str(omr),
                ],
                cwd=str(AUDIVERIS.parent),
                stdout=lf,
                stderr=subprocess.STDOUT,
                timeout=60 * 5,
            )
            chunk = Path(log).read_text(encoding="utf-8", errors="replace")
            # Only inspect the section we just wrote
            section = chunk.rsplit(f"--- sheet {n} ---", 1)[-1]
            if f"No sheet #{n}" in section:
                lf.write(f"stop: no sheet #{n}\n")
                break
            cands = list(omr.parent.glob("*.mxl"))
            if not cands:
                lf.write(f"sheet {n}: no mxl (exit={proc.returncode})\n")
                # If early sheets exist but export nothing, keep trying a few;
                # stop after a streak of empty exports past known page count.
                if n >= 3 and not ok:
                    # All early sheets invalid — abort
                    break
                continue
            src = max(cands, key=lambda p: p.stat().st_mtime)
            dest = parts_dir / f"p{n:02d}.mxl"
            shutil.copy2(src, dest)
            ok.append(dest)
            lf.write(f"sheet {n}: OK {dest.stat().st_size} bytes\n")
    if not ok:
        return None
    merged = work / "omr_draft.musicxml"
    if len(ok) == 1:
        # keep as mxl
        dest = work / "omr_draft.mxl"
        shutil.copy2(ok[0], dest)
        return dest
    merge_partwise(ok, merged)
    return merged


def run_audiveris(score_id: str, pdf: Path) -> Path | None:
    work = OMR_WORK / score_id
    out = work / "audiveris_out"
    work.mkdir(parents=True, exist_ok=True)
    if out.exists():
        shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True, exist_ok=True)

    # Keep original PDF in scores_pdf; feed Audiveris a cleaned raster PDF.
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
                str(AUDIVERIS),
                "-batch",
                "-export",
                "-force",
                "-output",
                str(out),
                str(feed),
            ],
            cwd=str(AUDIVERIS.parent),
            stdout=lf,
            stderr=subprocess.STDOUT,
            timeout=60 * 45,
        )
    elapsed = time.time() - t0
    print(f"  exit={proc.returncode} in {elapsed:.0f}s", flush=True)

    best = _find_export(work, out)
    if best is None:
        # Retry: export from saved .omr with sheet ranges that often skip covers
        omrs = [p for p in (list(out.rglob("*.omr")) + list(work.rglob("*.omr"))) if "sheet_parts" not in p.parts]
        if omrs:
            omr = max(omrs, key=lambda p: p.stat().st_mtime)
            for sheets in ("2-99", "1-99"):
                print(f"  retry export {omr.name} -sheets {sheets}", flush=True)
                with open(log, "a", encoding="utf-8", errors="replace") as lf:
                    lf.write(f"\n--- retry -sheets {sheets} ---\n")
                    subprocess.run(
                        [
                            str(AUDIVERIS),
                            "-batch",
                            "-export",
                            "-force",
                            "-sheets",
                            sheets,
                            "-output",
                            str(out),
                            str(omr),
                        ],
                        cwd=str(AUDIVERIS.parent),
                        stdout=lf,
                        stderr=subprocess.STDOUT,
                        timeout=60 * 20,
                    )
                best = _find_export(work, out)
                if best is not None:
                    break
            if best is None:
                print(f"  sheet-merge export from {omr.name} …", flush=True)
                best = _export_sheets_and_merge(omr, work)

    if best is None:
        print(f"  FAIL: no MusicXML for {score_id}", flush=True)
        return None
    dest = work / f"omr_draft{best.suffix.lower()}"
    if best.resolve() != dest.resolve():
        shutil.copy2(best, dest)
    print(f"  draft: {dest.name} ({dest.stat().st_size} bytes)", flush=True)
    return dest


def finish_import(score_id: str, title: str, artist: str, genre: str, difficulty: int) -> int:
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
    r = subprocess.run(cmd, cwd=str(REPO))
    return r.returncode


def main() -> int:
    if not AUDIVERIS.is_file():
        print("Audiveris missing:", AUDIVERIS, file=sys.stderr)
        return 1
    PDF_DIR.mkdir(parents=True, exist_ok=True)

    plan = []
    missing = []
    for row in SCORES:
        sid, title, artist, genre, diff, subs = row
        pdf = find_pdf(subs)
        if pdf is None:
            missing.append((sid, subs))
            continue
        plan.append((sid, title, artist, genre, diff, pdf))

    print(f"planned {len(plan)} scores; missing {len(missing)}")
    for sid, subs in missing:
        print(f"  MISSING {sid}: {subs}")

    ok, fail = [], []
    for i, (sid, title, artist, genre, diff, pdf) in enumerate(plan, 1):
        print(f"\n[{i}/{len(plan)}] {sid} ← {pdf.name}", flush=True)
        try:
            draft = run_audiveris(sid, pdf)
            if draft is None:
                fail.append(sid)
                continue
            code = finish_import(sid, title, artist, genre, diff)
            if code != 0:
                print(f"  import failed exit={code}", flush=True)
                fail.append(sid)
            else:
                ok.append(sid)
        except subprocess.TimeoutExpired:
            print(f"  TIMEOUT {sid}", flush=True)
            fail.append(sid)
        except Exception as e:
            print(f"  ERROR {sid}: {e}", flush=True)
            fail.append(sid)

    report = REPO / "docs/omr_audit/_batch_import_report.json"
    report.write_text(
        json.dumps({"ok": ok, "fail": fail, "missing": [m[0] for m in missing]}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nDONE ok={len(ok)} fail={len(fail)} missing={len(missing)}")
    print("report:", report)
    return 0 if not fail and not missing else 2


if __name__ == "__main__":
    raise SystemExit(main())
