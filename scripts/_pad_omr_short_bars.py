# -*- coding: utf-8 -*-
"""Pad short voices to bar length for listed omrDraft scores (rhythm only)."""
from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, q, save  # noqa: E402

DEFAULT = [
    "ru_yuan",
    "jay_chou_qing_tian",
    "sawano_call_of_silence",
    "xiang_yun_duan",
    "jue_bie_shu",
    "rush_e",
    "christina_perri_a_thousand_years",
    "hisaishi_castle_in_the_sky",
    "radwimps_suzume",
    "haruhikage",
    "clayderman_reve_damour",
    "rimsky_flight_of_the_bumblebee",
    "when_you_wish_upon_a_star",
    "pure_imagination",
    "an_he_qiao",
]


def _update_meter(m, ns: str, div, beats, bt):
    for el in m:
        tag = el.tag.replace(ns, "") if ns else el.tag
        if tag != "attributes":
            continue
        d = el.find(q(ns, "divisions"))
        if d is not None and d.text:
            div = int(d.text)
        t = el.find(q(ns, "time"))
        if t is not None:
            beats = int(t.findtext(q(ns, "beats")))
            bt = int(t.findtext(q(ns, "beat-type")))
    return div, beats, bt


def pad_score(sid: str, *, all_parts: bool = False) -> int:
    tree, root, ns = load(sid)
    parts = (
        root.findall(q(ns, "part"))
        if all_parts
        else [root.find(q(ns, "part"))]
    )
    fixed = 0
    for part in parts:
        if part is None:
            continue
        div = beats = bt = None
        for m in part.findall(q(ns, "measure")):
            div, beats, bt = _update_meter(m, ns, div, beats, bt)
            if not (div and beats and bt):
                continue
            expect = int(beats * (4.0 / bt) * div)
            by: dict[tuple[str, str], list] = defaultdict(list)
            for n in m.findall(q(ns, "note")):
                if n.find(q(ns, "chord")) is not None:
                    continue
                if n.find(q(ns, "duration")) is None:
                    continue
                st = n.findtext(q(ns, "staff")) or "1"
                vo = n.findtext(q(ns, "voice")) or "1"
                by[(st, vo)].append(n)
            changed = False
            for notes in by.values():
                sm = sum(int(n.findtext(q(ns, "duration")) or 0) for n in notes)
                if 0 < sm < expect:
                    gap = expect - sm
                    d = notes[-1].find(q(ns, "duration"))
                    if d is not None:
                        d.text = str(int(d.text or "0") + gap)
                        changed = True
            if changed:
                fixed += 1
    if fixed:
        save(sid, tree)
        convert(sid)
    print(f"[PianoFlow/omr] {sid}: padded {fixed} measures (per-measure meter)")
    return fixed


def trim_tiny_over(
    sid: str, max_extra: int = 6, *, all_parts: bool = False
) -> int:
    """Shrink from end of voice when only slightly over expect (keep dur>=1)."""
    tree, root, ns = load(sid)
    parts = (
        root.findall(q(ns, "part"))
        if all_parts
        else [root.find(q(ns, "part"))]
    )
    nfix = 0
    for part in parts:
        if part is None:
            continue
        div = beats = bt = None
        for m in part.findall(q(ns, "measure")):
            div, beats, bt = _update_meter(m, ns, div, beats, bt)
            if not (div and beats and bt):
                continue
            expect = int(beats * (4.0 / bt) * div)
            by: dict[tuple[str, str], list] = defaultdict(list)
            for n in m.findall(q(ns, "note")):
                if n.find(q(ns, "chord")) is not None:
                    continue
                if n.find(q(ns, "grace")) is not None:
                    continue
                if n.find(q(ns, "duration")) is None:
                    continue
                st = n.findtext(q(ns, "staff")) or "1"
                vo = n.findtext(q(ns, "voice")) or "1"
                by[(st, vo)].append(n)
            for notes in by.values():
                sm = sum(int(n.findtext(q(ns, "duration")) or 0) for n in notes)
                extra = sm - expect
                if not (0 < extra <= max_extra):
                    continue
                remain = extra
                for n in reversed(notes):
                    if remain <= 0:
                        break
                    d = n.find(q(ns, "duration"))
                    if d is None or not d.text:
                        continue
                    cur = int(d.text)
                    take = min(remain, max(0, cur - 1))
                    if take > 0:
                        d.text = str(cur - take)
                        remain -= take
                if remain < extra:
                    nfix += 1
    if nfix:
        save(sid, tree)
        convert(sid)
    print(
        f"[PianoFlow/omr] {sid}: trimmed {nfix} tiny-over voices "
        f"(max_extra={max_extra})"
    )
    return nfix


def clamp_single_note_over(sid: str, *, all_parts: bool = False) -> int:
    """If a voice is a single timed note/rest over bar length, clamp to expect."""
    tree, root, ns = load(sid)
    parts = (
        root.findall(q(ns, "part"))
        if all_parts
        else [root.find(q(ns, "part"))]
    )
    nfix = 0
    for part in parts:
        if part is None:
            continue
        div = beats = bt = None
        for m in part.findall(q(ns, "measure")):
            div, beats, bt = _update_meter(m, ns, div, beats, bt)
            if not (div and beats and bt):
                continue
            expect = int(beats * (4.0 / bt) * div)
            by: dict[tuple[str, str], list] = defaultdict(list)
            for n in m.findall(q(ns, "note")):
                if n.find(q(ns, "chord")) is not None:
                    continue
                if n.find(q(ns, "grace")) is not None:
                    continue
                if n.find(q(ns, "duration")) is None:
                    continue
                st = n.findtext(q(ns, "staff")) or "1"
                vo = n.findtext(q(ns, "voice")) or "1"
                by[(st, vo)].append(n)
            for notes in by.values():
                if len(notes) != 1:
                    continue
                d = notes[0].find(q(ns, "duration"))
                if d is None or not d.text:
                    continue
                cur = int(d.text)
                if cur > expect:
                    d.text = str(expect)
                    nfix += 1
    if nfix:
        save(sid, tree)
        convert(sid)
    print(f"[PianoFlow/omr] {sid}: clamped {nfix} single-note overs to expect")
    return nfix


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", nargs="*", default=DEFAULT)
    ap.add_argument("--all-parts", action="store_true")
    ap.add_argument("--trim", type=int, default=0, help="also trim overfull <= N")
    ap.add_argument(
        "--clamp-single",
        action="store_true",
        help="clamp single-note/rest voices longer than a bar",
    )
    args = ap.parse_args()
    total = sum(pad_score(sid, all_parts=args.all_parts) for sid in args.ids)
    if args.trim:
        for sid in args.ids:
            trim_tiny_over(sid, max_extra=args.trim, all_parts=args.all_parts)
    if args.clamp_single:
        for sid in args.ids:
            clamp_single_note_over(sid, all_parts=args.all_parts)
    print(f"[PianoFlow/omr] TOTAL padded measures={total}; still omrDraft")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
