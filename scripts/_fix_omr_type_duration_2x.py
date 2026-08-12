# -*- coding: utf-8 -*-
"""Halve note durations when a measure is overfull and every typed note is 2× type.

Machine-only rhythm hygiene for omrDraft. Does not change pitches. No formal.
"""
from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, q, save  # noqa: E402
from _pad_omr_short_bars import pad_score  # noqa: E402

TYPE_BEATS = {
    "maxima": 32,
    "long": 16,
    "breve": 8,
    "whole": 4,
    "half": 2,
    "quarter": 1,
    "eighth": 0.5,
    "16th": 0.25,
    "32nd": 0.125,
    "64th": 0.0625,
    "128th": 0.03125,
    "256th": 0.015625,
}


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def type_duration(typ: str, dots: int, div: int) -> int | None:
    if typ not in TYPE_BEATS:
        return None
    base = TYPE_BEATS[typ] * div
    add = 0.0
    unit = float(base)
    for _ in range(dots):
        unit /= 2.0
        add += unit
    return int(round(base + add))


def expect_for(div: int | None, beats: int | None, bt: int | None) -> int | None:
    if not (div and beats and bt):
        return None
    return int(beats * (4.0 / bt) * div)


def fix_score(sid: str) -> int:
    tree, root, ns = load(sid)
    fixed = 0
    for part in root.findall(q(ns, "part")):
        div = beats = bt = None
        for m in part.findall(q(ns, "measure")):
            for el in m:
                if local(el.tag) != "attributes":
                    continue
                d = el.find(q(ns, "divisions"))
                if d is not None and d.text:
                    div = int(d.text)
                t = el.find(q(ns, "time"))
                if t is not None:
                    beats = int(t.findtext(q(ns, "beats")) or 0)
                    bt = int(t.findtext(q(ns, "beat-type")) or 0)
            exp = expect_for(div, beats, bt)
            if not exp or not div:
                continue
            by_sum: dict[tuple[str, str], int] = defaultdict(int)
            typed: list = []
            for n in m.findall(q(ns, "note")):
                if n.find(q(ns, "chord")) is not None:
                    continue
                if n.find(q(ns, "grace")) is not None:
                    continue
                dur_el = n.find(q(ns, "duration"))
                if dur_el is None or not dur_el.text:
                    continue
                st = n.findtext(q(ns, "staff")) or "1"
                vo = n.findtext(q(ns, "voice")) or "1"
                cur = int(dur_el.text)
                by_sum[(st, vo)] += cur
                typ = n.findtext(q(ns, "type"))
                if typ is None:
                    continue
                dots = len(n.findall(q(ns, "dot")))
                td = type_duration(typ, dots, div)
                typed.append((n, cur, td))
            if not by_sum or not any(sm != exp for sm in by_sum.values()):
                continue
            if not typed or not all(td is not None and cur == 2 * td for _, cur, td in typed):
                continue
            for n, cur, _td in typed:
                d = n.find(q(ns, "duration"))
                if d is not None:
                    d.text = str(max(1, cur // 2))
            # also halve untyped timed notes / chord durations in measure
            for n in m.findall(q(ns, "note")):
                if n.find(q(ns, "grace")) is not None:
                    continue
                if n.find(q(ns, "type")) is not None:
                    continue
                d = n.find(q(ns, "duration"))
                if d is not None and d.text:
                    cur = int(d.text)
                    if cur > 1 and cur % 2 == 0:
                        d.text = str(cur // 2)
            for el in m:
                if local(el.tag) in ("backup", "forward"):
                    d = el.find(q(ns, "duration"))
                    if d is not None and d.text:
                        cur = int(d.text)
                        if cur > 1 and cur % 2 == 0:
                            d.text = str(cur // 2)
            fixed += 1
            print(
                f"[PianoFlow/omr] {sid}: m{m.get('number')} "
                f"halved type-2x overfull measure"
            )
    if fixed:
        save(sid, tree)
        convert(sid)
    print(f"[PianoFlow/omr] {sid}: fixed {fixed} type-2x measures; still omrDraft")
    return fixed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", nargs="*", default=["haruhikage"])
    ap.add_argument("--pad", action="store_true")
    args = ap.parse_args()
    total = sum(fix_score(sid) for sid in args.ids)
    if args.pad:
        for sid in args.ids:
            pad_score(sid, all_parts=True)
    print(f"[PianoFlow/omr] total type-2x measures={total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
