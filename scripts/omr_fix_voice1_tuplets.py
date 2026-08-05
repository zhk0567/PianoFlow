#!/usr/bin/env python3
"""Fix common Audiveris tuplet duration underflows on staff1 voice1.

Rules (when measure voice1 sum < expected quarters*divisions):
  - 16th + time-mod + dur==2 → dur=3, drop tuplet  (+1)
  - eighth + time-mod + dur==4 → dur=6, drop tuplet (+2)
  - single voice1 quarter filling exactly half a 2/4 bar (sum==expect/2)
    → promote to half (dur=expect)

Usage:
  python .\\scripts\\omr_fix_voice1_tuplets.py --id ru_yuan
  python .\\scripts\\omr_fix_voice1_tuplets.py --all-omr
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))
from musicxml_to_score import local  # noqa: E402

ASSETS = REPO / "assets" / "scores" / "musicxml"
THIRD = REPO / "third_party" / "scores_musicxml"
CATALOG = REPO / "assets" / "scores" / "catalog.json"


def omr_ids() -> list[str]:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    return [s["id"] for s in data.get("songs") or [] if s.get("scoreKind") == "omrDraft"]


def measure_expect(meas: ET.Element, div: int | None, beats: int | None, bt: int | None):
    d, b, t = div, beats, bt
    for el in meas:
        if local(el.tag) != "attributes":
            continue
        for c in el:
            if local(c.tag) == "divisions" and c.text:
                d = int(c.text)
            if local(c.tag) == "time":
                for x in c:
                    if local(x.tag) == "beats" and x.text:
                        b = int(x.text)
                    if local(x.tag) == "beat-type" and x.text:
                        t = int(x.text)
    expect = int(d * b * 4 / t) if d and b and t else None
    return d, b, t, expect


def iter_v1(meas: ET.Element):
    for el in list(meas):
        if local(el.tag) != "note":
            continue
        staff = voice = typ = None
        dur_el = tm_el = None
        chord = grace = rest = False
        dots = 0
        for c in list(el):
            tt = local(c.tag)
            if tt == "staff":
                staff = c.text
            elif tt == "voice":
                voice = c.text
            elif tt == "type":
                typ = c.text
            elif tt == "duration":
                dur_el = c
            elif tt == "time-modification":
                tm_el = c
            elif tt == "chord":
                chord = True
            elif tt == "grace":
                grace = True
            elif tt == "rest":
                rest = True
            elif tt == "dot":
                dots += 1
        if chord or grace or staff != "1" or (voice or "1") != "1" or dur_el is None:
            continue
        yield el, typ, dur_el, tm_el, rest, dots


def voice1_sum(meas: ET.Element) -> int:
    return sum(int(dur_el.text or 0) for _, _, dur_el, _, _, _ in iter_v1(meas))


def drop_tm(note: ET.Element, tm_el: ET.Element | None) -> None:
    if tm_el is not None and tm_el in list(note):
        note.remove(tm_el)
    for c in list(note):
        if local(c.tag) == "notations":
            for n in list(c):
                if local(n.tag) == "tuplet":
                    c.remove(n)
            if len(list(c)) == 0:
                note.remove(c)


def set_backup(meas: ET.Element, dur: int) -> None:
    for el in meas:
        if local(el.tag) == "backup":
            for c in el:
                if local(c.tag) == "duration":
                    c.text = str(dur)
            return


def fix_measure(meas: ET.Element, expect: int | None) -> int:
    if not expect:
        return 0
    before = voice1_sum(meas)
    if before == 0 or before >= expect:
        return 0
    added = 0
    notes = list(iter_v1(meas))
    for note, typ, dur_el, tm_el, rest, dots in notes:
        dur = int(dur_el.text or 0)
        if tm_el is not None and typ == "16th" and dur == 2:
            dur_el.text = "3"
            drop_tm(note, tm_el)
            added += 1
        elif (
            tm_el is not None
            and typ == "eighth"
            and dur == 4
            and before <= expect - 6
        ):
            # Only expand clearly-short bars. Do NOT touch legitimate
            # triplet eighths (e.g. moonlight) where before is already near-full.
            dur_el.text = "6"
            drop_tm(note, tm_el)
            added += 2
    after = voice1_sum(meas)
    # 2/4 (or any) half-empty single quarter → half note
    if after == expect // 2 and after > 0:
        ns = [n for n in iter_v1(meas) if not n[4]]  # non-rest
        if len(ns) == 1:
            note, typ, dur_el, tm_el, rest, dots = ns[0]
            if typ == "quarter" and dots == 0 and int(dur_el.text or 0) == expect // 2:
                for c in list(note):
                    if local(c.tag) == "type":
                        c.text = "half"
                dur_el.text = str(expect)
                drop_tm(note, tm_el)
                added += expect // 2
                after = voice1_sum(meas)
    # quarter + three 16ths = expect-3 → add one more 16th duration onto last 16th? 
    # Better: promote first quarter to dotted-quarter when after == expect-3 and pattern matches
    if after == expect - 3:
        ns = [n for n in iter_v1(meas) if not n[4]]
        if len(ns) == 4:
            n0 = ns[0]
            if n0[1] == "quarter" and n0[5] == 0 and all(n[1] == "16th" for n in ns[1:]):
                # dotted quarter + two 16ths would be expect, but we have 3 sixteenths.
                # Extend first by +3 instead (quarter→ dotted-ish 15) only if divisions allow:
                # prefer: change first to eighth and keep 3 16ths? 6+9=15 still short.
                # Safest musical for leftover beat: append duration to last note +3
                last = ns[-1]
                last[2].text = str(int(last[2].text) + 3)
                # if was 16th(3) → 16th(6) becomes eighth visually: update type
                for c in list(last[0]):
                    if local(c.tag) == "type":
                        c.text = "eighth"
                added += 3
                after = voice1_sum(meas)
    if after != before:
        set_backup(meas, after)
    return added


def patch(score_id: str) -> tuple[int, list]:
    path = ASSETS / f"{score_id}.musicxml"
    tree = ET.parse(path)
    root = tree.getroot()
    div = beats = bt = None
    fixed = 0
    still = []
    for meas in root.iter():
        if local(meas.tag) != "measure":
            continue
        div, beats, bt, expect = measure_expect(meas, div, beats, bt)
        num = meas.attrib.get("number", "?")
        before = voice1_sum(meas)
        add = fix_measure(meas, expect)
        after = voice1_sum(meas)
        if add:
            fixed += 1
        if expect and after and after != expect and num != "0":
            # allow intentional pickup/short final if after < expect/2 and last measures
            still.append((num, before, after, expect))
    tree.write(path, encoding="UTF-8", xml_declaration=True)
    dst = THIRD / f"{score_id}.musicxml"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(path.read_bytes())
    return fixed, still


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id")
    ap.add_argument("--all-omr", action="store_true")
    args = ap.parse_args()
    ids = omr_ids() if args.all_omr else ([args.id] if args.id else [])
    if not ids:
        print("Provide --id or --all-omr", file=sys.stderr)
        return 2
    rc = 0
    for sid in ids:
        # skip already-clean curated fixes if desired — still safe to run
        n, still = patch(sid)
        print(f"OK {sid}: measures_touched={n} still_short={len(still)}")
        for row in still[:8]:
            print(f"  m{row[0]} {row[1]}→{row[2]} expect {row[3]}")
        if len(still) > 8:
            print(f"  ... {len(still)-8} more")
        if still:
            rc = 1
    return 0  # report-only exit; reconvert separately


if __name__ == "__main__":
    raise SystemExit(main())
