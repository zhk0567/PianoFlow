# -*- coding: utf-8 -*-
"""Machine fix: OMR duration doubling / spurious mid-score divisions (omrDraft only).

1) Silence m29+ / Clayderman m37+: remove bogus divisions 8→4 when note durations
   still encoded for divisions=8 (voices sum to 2× expect).
2) Christina (and similar): in 6/8 measures where every voice sum == 2× expect,
   halve note durations (keep types).

Does not change pitches. Still omrDraft — no formal.
"""
from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, measures, q, save  # noqa: E402


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def expect_for(div: int | None, beats: int | None, bt: int | None) -> int | None:
    if not (div and beats and bt):
        return None
    return int(beats * (4.0 / bt) * div)


def remove_spurious_divisions(
    sid: str,
    from_measure: str,
    *,
    bad_values: tuple[str, ...] = ("4", "2"),
) -> bool:
    """Remove a mid-score <divisions> that halves expect while note durs stay old."""
    tree, root, ns = load(sid)
    by = {m.get("number"): m for m in measures(root, ns)}
    m = by.get(from_measure)
    if m is None:
        return False
    changed = False
    removed = None
    for el in list(m):
        if local(el.tag) != "attributes":
            continue
        d = el.find(q(ns, "divisions"))
        if d is not None and d.text in bad_values:
            removed = d.text
            el.remove(d)
            changed = True
    if changed:
        save(sid, tree)
        convert(sid)
        print(
            f"[PianoFlow/omr] {sid}: removed divisions={removed} at m{from_measure}"
        )
    return changed


def halve_exact_double_measures(sid: str) -> int:
    tree, root, ns = load(sid)
    div = beats = bt = None
    fixed = 0
    for m in measures(root, ns):
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
        if not exp:
            continue
        by_notes: dict[tuple[str, str], list] = defaultdict(list)
        by_sum: dict[tuple[str, str], int] = defaultdict(int)
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
            by_notes[(st, vo)].append(n)
            by_sum[(st, vo)] += int(dur_el.text)
        if not by_sum:
            continue
        if not all(sm == 2 * exp for sm in by_sum.values()):
            continue
        for notes in by_notes.values():
            for n in notes:
                d = n.find(q(ns, "duration"))
                if d is not None and d.text:
                    d.text = str(max(1, int(d.text) // 2))
        # also halve backup/forward in measure
        for el in m:
            if local(el.tag) in ("backup", "forward"):
                d = el.find(q(ns, "duration"))
                if d is not None and d.text:
                    d.text = str(max(1, int(d.text) // 2))
        fixed += 1
    if fixed:
        save(sid, tree)
        convert(sid)
    print(f"[PianoFlow/omr] {sid}: halved durations in {fixed} exact-2x measures")
    return fixed


def main() -> None:
    remove_spurious_divisions("sawano_call_of_silence", "29")
    remove_spurious_divisions("clayderman_reve_damour", "37")
    remove_spurious_divisions("rush_e", "34")
    remove_spurious_divisions("jay_chou_qing_tian", "65")
    remove_spurious_divisions("jue_bie_shu", "106")
    halve_exact_double_measures("christina_perri_a_thousand_years")
    # haruhikage P1 still doubled in places — only exact-2x all voices
    tree, root, ns = load("haruhikage")
    # apply to ALL parts
    fixed_parts = 0
    for part in root.findall(q(ns, "part")):
        # temporarily rewrite measures() scope by operating on part measures
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
            if not exp:
                continue
            by_notes: dict[tuple[str, str], list] = defaultdict(list)
            by_sum: dict[tuple[str, str], int] = defaultdict(int)
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
                by_notes[(st, vo)].append(n)
                by_sum[(st, vo)] += int(dur_el.text)
            if not by_sum or not all(sm == 2 * exp for sm in by_sum.values()):
                continue
            for notes in by_notes.values():
                for n in notes:
                    d = n.find(q(ns, "duration"))
                    if d is not None and d.text:
                        d.text = str(max(1, int(d.text) // 2))
            for el in m:
                if local(el.tag) in ("backup", "forward"):
                    d = el.find(q(ns, "duration"))
                    if d is not None and d.text:
                        d.text = str(max(1, int(d.text) // 2))
            fixed_parts += 1
    if fixed_parts:
        save("haruhikage", tree)
        convert("haruhikage")
    print(f"[PianoFlow/omr] haruhikage: halved {fixed_parts} part-measures; still omrDraft")


if __name__ == "__main__":
    main()
