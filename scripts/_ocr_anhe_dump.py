# -*- coding: utf-8 -*-
"""OCR dump for an_he_qiao grand systems (RH/LH)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageOps
from rapidocr_onnxruntime import RapidOCR

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "omr_audit" / "_jianpu_proof" / "an_he_qiao" / "_grand2"
OUT = ROOT / "docs" / "omr_audit" / "_jianpu_proof" / "an_he_qiao" / "_ocr_dump.txt"
TMP = ROOT / "_tmp_anhe_ocr"
TMP.mkdir(exist_ok=True)


def split_rl(im: Image.Image) -> int:
    arr = np.asarray(im.convert("L"))
    h = arr.shape[0]
    ink = (arr < 200).mean(axis=1)
    mid0, mid1 = h // 5, 4 * h // 5
    return mid0 + int(np.argmin(ink[mid0:mid1]))


def prep(im: Image.Image, scale: int = 3, invert: bool = False) -> Image.Image:
    im = im.convert("L")
    im = im.resize((im.width * scale, im.height * scale), Image.Resampling.LANCZOS)
    if invert:
        im = ImageOps.invert(im)
    im = ImageEnhance.Contrast(im).enhance(2.5)
    arr = np.asarray(im)
    arr = np.where(arr < 160, 0, 255).astype(np.uint8)
    return Image.fromarray(arr).convert("RGB")


def main() -> None:
    ocr = RapidOCR()
    lines: list[str] = []
    for p in sorted(SRC.glob("p*_s*.png")):
        if "_m" in p.stem:
            continue
        im = Image.open(p)
        split = split_rl(im)
        rh = im.crop((0, 0, im.width, split + 8))
        lh = im.crop((0, split - 8, im.width, im.height))
        lines.append(f"=== {p.name} split={split} h={im.height} ===")
        for hand, crop in [("rh", rh), ("lh", lh)]:
            for tag, do_inv in [("a", False), ("b", True)]:
                img = prep(crop, scale=4 if hand == "rh" else 3, invert=do_inv)
                fp = TMP / f"{p.stem}_{hand}_{tag}.png"
                img.save(fp)
                r, _ = ocr(str(fp))
                texts = [x[1] for x in (r or [])]
                lines.append(f"  {hand}{tag}: {' | '.join(texts) if texts else '(empty)'}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
