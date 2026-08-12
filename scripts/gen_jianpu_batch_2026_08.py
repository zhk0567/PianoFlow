# -*- coding: utf-8 -*-
"""Generate MusicXML from jianpu PDFs (batch 2026-08) and print import commands."""
from __future__ import annotations

from pathlib import Path

from jianpu_to_musicxml import build_musicxml, write

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "third_party" / "scores_musicxml" / "_omr_work"


def _q(*tokens: str) -> list[str]:
    return list(tokens)


def gen_xiao_xing_xing() -> None:
    # Twinkle — from 简谱网 piano jianpu preview
    rh = [
        _q("1^", "1^", "5^", "5^"),
        _q("6^", "6^", "5^", "-"),
        _q("4^", "4^", "3^", "3^"),
        _q("2^", "2^", "1^", "-"),
        _q("5^", "5^", "4^", "4^"),
        _q("3^", "3^", "2^", "-"),
        _q("5^", "5^", "4^", "4^"),
        _q("3^", "3^", "2^", "-"),
        _q("1^", "1^", "5^", "5^"),
        _q("6^", "6^", "5^", "-"),
        _q("4^", "4^", "3^", "3^"),
        _q("2^", "2^", "1^", "-"),
    ]
    alberti = _q("1/", "5/", "3/", "5/", "1/", "5/", "3/", "5/")
    lh = [
        alberti,
        _q("1/", "6_/", "4_/", "6_/", "1/", "5/", "3/", "5/"),
        _q("1/", "6_/", "4_/", "6_/", "1/", "5/", "3/", "5/"),
        _q("7_/", "5_/", "4_/", "5_/", "1/", "5/", "3/", "5/"),
        _q("1/", "5/", "3/", "5/", "1/", "6_/", "4_/", "6_/"),
        _q("1/", "5/", "3/", "5/", "7_/", "5_/", "4_/", "5_/"),
        _q("1/", "5/", "3/", "5/", "1/", "6_/", "4_/", "6_/"),
        _q("1/", "5/", "3/", "5/", "7_/", "5_/", "4_/", "5_/"),
        alberti,
        _q("1/", "6_/", "4_/", "6_/", "1/", "5/", "3/", "5/"),
        _q("1/", "6_/", "4_/", "6_/", "1/", "5/", "3/", "5/"),
        _q("7_/", "5_/", "4_/", "5_/", "1", "-", "-", "-"),
    ]
    xml = build_musicxml(
        title="小星星",
        artist="Traditional / Twinkle Twinkle Little Star",
        key="C",
        tempo=60,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "xiao_xing_xing" / "jianpu_draft.musicxml", xml)


def gen_fen_shua_jiang() -> None:
    rh = [
        _q("5", "3", "5", "3"),
        _q("5", "3", "1", "-"),
        _q("2", "4", "3", "2"),
        _q("5", "-", "-", "-"),
        _q("5", "3", "5", "3"),
        _q("5", "3", "1", "-"),
        _q("2", "4", "3", "2"),
        _q("1", "-", "-", "-"),
        _q("2", "2", "4", "4"),
        _q("3", "2", "5", "-"),
        _q("2", "4", "3", "2"),
        _q("5", "-", "-", "-"),
        _q("5", "3", "5", "3"),
        _q("5", "3", "1", "-"),
        _q("2", "4", "3", "2"),
        _q("1^", "-", "-", "-"),
    ]
    # simplified LH: root - third - as half notes (preview showed 1+5 / 3+5)
    bass = _q("1", "-", "3", "-")
    lh = [bass] * 15 + [_q("1", "-", "-", "-")]
    xml = build_musicxml(
        title="粉刷匠",
        artist="Traditional / Polish folk",
        key="C",
        tempo=120,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "fen_shua_jiang" / "jianpu_draft.musicxml", xml)


def gen_blowin() -> None:
    # melody-only jianpu; LH rests
    rh = [
        _q("5", "-", "5", "5"),
        _q("6", "-", "6", "6"),
        _q("5", "-", "3", "2"),
        _q("1", "-", "0", "3"),
        _q("5", "-", "0", "5"),
        _q("6", "-", "5", "4"),
        _q("5", "-", "-", "-"),
        _q("0", "0", "3", "4"),
        _q("5", "-", "5", "5"),
        _q("6", "-", "6", "6"),
        _q("5", "-", "3", "2"),
        _q("1", "-", "0", "3"),
        _q("5", "-", "5", "3"),
        _q("4", "-", "4", "3"),
        _q("2", "-", "-", "-"),
        _q("0", "0", "0", "3"),
        _q("4", "-", "4", "3"),
        _q("2", "-", "0", "2"),
        _q("3", "3", "3", "2"),
        _q("1", "-", "0", "3"),
        _q("4", "-", "4", "3"),
        _q("2", "2", "1", "2"),
        _q("1", "-", "-", "-"),
    ]
    lh = [_q("0", "-", "-", "-")] * len(rh)
    xml = build_musicxml(
        title="Blowin' In The Wind",
        artist="Bob Dylan",
        key="C",
        tempo=120,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "blowin_in_the_wind" / "jianpu_draft.musicxml", xml)


def gen_bella_ciao() -> None:
    # 2/4 — use beats=2; tokens in half-measure units still as quarters relative to beat_type
    # Represent each measure as total duration 2.0 quarters
    rh = [
        _q("0/", "3/", "6/", "7/", "1^/", "6/", "-", "6/"),  # too long — fix properly
    ]
    # Better: each measure duration sum = 2
    rh = [
        _q("0/", "3/", "6/", "7/"),  # 2
        _q("1^/", "6/", "6/", "6/"),  # approximate i 6 - 6
        _q("0/", "3/", "6/", "7/"),
        _q("1^/", "6/", "6/", "6/"),
        _q("0/", "3/", "6/", "7/"),
        _q("1^/", "7/", "6/", "6/"),
        _q("1^/", "7/", "6/", "6/"),
        _q("3", "3"),
        _q("3/", "3/", "2/", "3/"),
        _q("4", "4"),
        _q("4", "4"),
        _q("0/", "4/", "3/", "2/"),
        _q("4", "3"),
        _q("3", "3"),
        _q("0/", "3/", "2/", "1^/"),
        _q("7", "3"),
        _q("0/", "3/", "6/", "7/"),
        _q("1^/", "6/", "6/", "6/"),
        _q("0/", "3/", "6/", "7/"),
        _q("1^/", "6/", "6/", "6/"),
        _q("0/", "3/", "6/", "7/"),
        _q("1^/", "6/", "6/", "6/"),
    ]
    lh = [_q("0", "-")] * len(rh)
    xml = build_musicxml(
        title="Bella Ciao",
        artist="Traditional / Italian folk",
        key="G",
        beats=2,
        beat_type=4,
        tempo=120,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "bella_ciao" / "jianpu_draft.musicxml", xml)


def gen_when_you_wish() -> None:
    # Compact simplified melody (first phrase cycle) — honest draft
    rh = [
        _q("5", "-", "5/", "6/"),
        _q("5", "-", "3", "2"),
        _q("1", "-", "-", "-"),
        _q("0", "0", "3", "4"),
        _q("5", "-", "5/", "6/"),
        _q("5", "-", "3", "2"),
        _q("1", "-", "-", "-"),
        _q("0", "0", "5", "5"),
        _q("6", "-", "6/", "5/"),
        _q("4", "-", "-", "-"),
        _q("0", "0", "4", "4"),
        _q("5", "-", "5/", "4/"),
        _q("3", "-", "-", "-"),
        _q("0", "0", "1", "2"),
        _q("3", "-", "3/", "2/"),
        _q("1", "-", "-", "-"),
    ]
    lh = [_q("1", "-", "5_", "-")] * len(rh)
    xml = build_musicxml(
        title="When You Wish Upon a Star",
        artist="Leigh Harline / Ned Washington",
        key="C",
        tempo=100,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "when_you_wish_upon_a_star" / "jianpu_draft.musicxml", xml)


def gen_whistle() -> None:
    # Hook motif draft
    motif = [
        _q("6/", "5/", "3/", "5/", "3", "-"),
        _q("3/", "2/", "1/", "2/", "3", "-"),
        _q("6/", "5/", "3/", "5/", "3", "-"),
        _q("5/", "3/", "2/", "1/", "2", "-"),
    ]
    rh = motif * 4
    lh = [_q("1/", "5_/", "1/", "5_/", "1/", "5_/", "1/", "5_/")] * len(rh)
    xml = build_musicxml(
        title="Whistle",
        artist="Flo Rida",
        key="C",
        tempo=120,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "whistle" / "jianpu_draft.musicxml", xml)


def gen_pure_imagination() -> None:
    rh = [
        _q("5", "-", "3/", "5/"),
        _q("6", "-", "-", "-"),
        _q("5", "-", "3/", "1/"),
        _q("2", "-", "-", "-"),
        _q("3", "-", "5/", "6/"),
        _q("5", "-", "-", "-"),
        _q("3", "-", "2/", "1/"),
        _q("2", "-", "-", "-"),
        _q("5", "-", "3/", "5/"),
        _q("6", "-", "-", "-"),
        _q("1^", "-", "6/", "5/"),
        _q("3", "-", "-", "-"),
        _q("5", "-", "4/", "3/"),
        _q("2", "-", "-", "-"),
        _q("1", "-", "-", "-"),
        _q("0", "-", "-", "-"),
    ]
    lh = [_q("1/", "5_/", "3_/", "5_/", "1/", "5_/", "3_/", "5_/")] * len(rh)
    xml = build_musicxml(
        title="Pure Imagination",
        artist="Leslie Bricusse / Anthony Newley",
        key="Eb",
        tempo=100,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "pure_imagination" / "jianpu_draft.musicxml", xml)


def gen_ju_hua_tai() -> None:
    # Opening melody sketch in F (1=F)
    rh = [
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3/", "5/", "6/", "5/", "3", "-"),
        _q("2/", "3/", "5/", "3/", "2", "-"),
        _q("1", "-", "-", "-"),
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3/", "5/", "6/", "1^/", "6", "-"),
        _q("5/", "3/", "2/", "1/", "2", "-"),
        _q("1", "-", "-", "-"),
        _q("6/", "1^/", "2^/", "1^/", "6", "-"),
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3/", "5/", "6/", "5/", "3", "-"),
        _q("2", "-", "-", "-"),
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3/", "2/", "1/", "2/", "3", "-"),
        _q("5", "-", "-", "-"),
        _q("1", "-", "-", "-"),
    ]
    lh = [_q("1/", "5_/", "1/", "5_/", "1/", "5_/", "1/", "5_/")] * len(rh)
    xml = build_musicxml(
        title="菊花台",
        artist="周杰伦",
        key="F",
        tempo=70,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "ju_hua_tai" / "jianpu_draft.musicxml", xml)


def gen_ye_de() -> None:
    rh = [
        _q("6", "-", "-", "-"),
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3", "-", "-", "-"),
        _q("2/", "3/", "5/", "3/", "2", "-"),
        _q("1", "-", "-", "-"),
        _q("6_/", "1/", "2/", "1/", "6_", "-"),
        _q("5", "-", "-", "-"),
        _q("3/", "5/", "6/", "5/", "3", "-"),
        _q("6", "-", "-", "-"),
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3", "-", "-", "-"),
        _q("5", "-", "-", "-"),
        _q("6/", "1^/", "2^/", "1^/", "6", "-"),
        _q("5", "-", "-", "-"),
        _q("3", "-", "-", "-"),
        _q("1", "-", "-", "-"),
    ]
    lh = [_q("4/", "1/", "5/", "6/", "1", "-")] * len(rh)
    xml = build_musicxml(
        title="夜的钢琴曲五",
        artist="石进",
        key="C",
        tempo=100,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "ye_de_gang_qin_qu_5" / "jianpu_draft.musicxml", xml)


def gen_an_he_qiao() -> None:
    rh = [
        _q("3/", "5/", "6/", "5/", "3", "-"),
        _q("2/", "3/", "5/", "3/", "2", "-"),
        _q("1/", "2/", "3/", "2/", "1", "-"),
        _q("6_", "-", "-", "-"),
        _q("3/", "5/", "6/", "1^/", "6", "-"),
        _q("5/", "3/", "2/", "1/", "2", "-"),
        _q("3", "-", "-", "-"),
        _q("0", "-", "-", "-"),
        _q("5/", "6/", "1^/", "6/", "5", "-"),
        _q("3/", "5/", "6/", "5/", "3", "-"),
        _q("2/", "3/", "5/", "6/", "5", "-"),
        _q("3", "-", "-", "-"),
        _q("1/", "2/", "3/", "5/", "3", "-"),
        _q("2/", "1/", "6_/", "1/", "2", "-"),
        _q("1", "-", "-", "-"),
        _q("1", "-", "-", "-"),
    ]
    lh = [_q("1/", "5_/", "1/", "5_/", "1/", "5_/", "1/", "5_/")] * len(rh)
    xml = build_musicxml(
        title="安和桥",
        artist="宋冬野",
        key="C",
        tempo=100,
        rh_measures=rh,
        lh_measures=lh,
    )
    write(OUT / "an_he_qiao" / "jianpu_draft.musicxml", xml)


MANIFEST = [
    ("xiao_xing_xing", "小星星", "Traditional / Twinkle Twinkle Little Star", "Classical", 1, gen_xiao_xing_xing),
    ("fen_shua_jiang", "粉刷匠", "Traditional / Polish folk", "Pop", 1, gen_fen_shua_jiang),
    ("blowin_in_the_wind", "Blowin' In The Wind", "Bob Dylan", "Pop", 2, gen_blowin),
    ("bella_ciao", "Bella Ciao", "Traditional / Italian folk", "Pop", 2, gen_bella_ciao),
    ("when_you_wish_upon_a_star", "When You Wish Upon a Star", "Leigh Harline / Ned Washington", "Pop", 2, gen_when_you_wish),
    ("whistle", "Whistle", "Flo Rida", "Pop", 3, gen_whistle),
    ("pure_imagination", "Pure Imagination", "Leslie Bricusse / Anthony Newley", "Pop", 3, gen_pure_imagination),
    ("ju_hua_tai", "菊花台", "周杰伦", "Pop", 3, gen_ju_hua_tai),
    ("ye_de_gang_qin_qu_5", "夜的钢琴曲五", "石进", "Classical", 3, gen_ye_de),
    ("an_he_qiao", "安和桥", "宋冬野", "Pop", 2, gen_an_he_qiao),
]


def main() -> None:
    for sid, title, artist, genre, diff, fn in MANIFEST:
        print("generate", sid)
        fn()
        xml = OUT / sid / "jianpu_draft.musicxml"
        assert xml.exists(), xml
        print(" ", xml)


if __name__ == "__main__":
    main()
