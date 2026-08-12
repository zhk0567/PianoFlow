# -*- coding: utf-8 -*-
"""Restore Suzume m8–15 from git initial OMR (theme rewrite had wrong LH texture).

PDF m13 LH fingering 5-2-1 + broken-chord eighths matches initial F2–C3–F3 /
E2–B2–E3, not the half-note dyad rewrite. Still omrDraft — no formal.
"""
from __future__ import annotations

import subprocess
import sys
from copy import deepcopy
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _fix_omr_openings import convert, load, measures, q, save  # noqa: E402


def local(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def strip_ns(elem: ET.Element) -> None:
    for e in elem.iter():
        if "}" in e.tag:
            e.tag = e.tag.split("}", 1)[1]


def main() -> None:
    head_xml = subprocess.check_output(
        [
            "git",
            "show",
            "7615330:assets/scores/musicxml/radwimps_suzume.musicxml",
        ]
    )
    head_root = ET.fromstring(head_xml)
    strip_ns(head_root)
    head_by: dict[str, ET.Element] = {}
    for part in head_root:
        if local(part.tag) != "part":
            continue
        for m in part:
            if local(m.tag) != "measure":
                continue
            head_by[m.get("number") or ""] = m

    tree, root, ns = load("radwimps_suzume")
    by = {m.get("number"): m for m in measures(root, ns)}
    for num in map(str, range(8, 16)):
        cur = by[num]
        src = head_by[num]
        for child in list(cur):
            if local(child.tag) in ("note", "backup", "forward"):
                cur.remove(child)
        for child in src:
            if local(child.tag) in ("note", "backup", "forward"):
                cur.append(deepcopy(child))

    for m in measures(root, ns):
        rh = [
            n
            for n in m.findall(q(ns, "note"))
            if n.find(q(ns, "chord")) is None
            and (n.findtext(q(ns, "staff")) or "1") == "1"
            and n.findtext(q(ns, "duration"))
        ]
        sm = sum(int(n.findtext(q(ns, "duration")) or 0) for n in rh)
        if sm not in (44, 45):
            continue
        for n in rh:
            d = n.find(q(ns, "duration"))
            if d is not None and d.text == "2":
                d.text = "3"
                t = n.find(q(ns, "type"))
                if t is not None:
                    t.text = "16th"
        sm2 = sum(int(n.findtext(q(ns, "duration")) or 0) for n in rh)
        if sm2 < 48 and rh:
            last = rh[-1].find(q(ns, "duration"))
            if last is not None:
                last.text = str(int(last.text or "0") + (48 - sm2))

    save("radwimps_suzume", tree)
    tp = ROOT / "third_party" / "scores_musicxml" / "radwimps_suzume.musicxml"
    tp.write_bytes(
        (ROOT / "assets" / "scores" / "musicxml" / "radwimps_suzume.musicxml").read_bytes()
    )
    convert("radwimps_suzume")
    print("[PianoFlow/omr] suzume restored m8-15 from initial OMR; still omrDraft")


if __name__ == "__main__":
    main()
