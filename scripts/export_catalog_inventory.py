# -*- coding: utf-8 -*-
"""Export catalog inventory to docs/曲库曲目清单.md (bilingual)."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets" / "scores" / "catalog.json"
OUT = ROOT / "docs" / "曲库曲目清单.md"

# id -> (title_zh, title_en)
TITLE_BI: dict[str, tuple[str, str]] = {
    "fur_elise_woo59": ("致爱丽丝", "Für Elise"),
    "pachelbel_canon_d": ("卡农（D大调）", "Canon in D"),
    "toby_fox_megalovania": ("Megalovania", "Megalovania"),
    "hisaishi_castle_in_the_sky": ("天空之城", "Castle in the Sky"),
    "radwimps_suzume": ("铃芽之旅", "Suzume"),
    "ru_yuan": ("如愿", "As You Wish / Ru Yuan"),
    "christina_perri_a_thousand_years": ("一千年", "A Thousand Years"),
    "haruhikage": ("春日影", "Haruhikage"),
    "rimsky_flight_of_the_bumblebee": ("野蜂飞舞", "Flight of the Bumblebee"),
    "beethoven_moonlight_sonata": ("月光奏鸣曲", "Moonlight Sonata"),
    "jay_chou_qing_tian": ("晴天", "Clear Day / Qing Tian"),
    "clayderman_reve_damour": ("梦中的婚礼", "Mariage d'Amour / Dream Wedding"),
    "sawano_call_of_silence": ("Call of Silence", "Call of Silence"),
    "xiang_yun_duan": ("向云端", "Toward the Clouds / Xiang Yun Duan"),
    "jue_bie_shu": ("诀别书", "Farewell Letter / Jue Bie Shu"),
    "rush_e": ("Rush E", "Rush E"),
    "blowin_in_the_wind": ("飘向远方的风", "Blowin' In The Wind"),
    "when_you_wish_upon_a_star": ("当你许愿时", "When You Wish Upon a Star"),
    "whistle": ("Whistle", "Whistle"),
    "bella_ciao": ("Bella Ciao", "Bella Ciao"),
    "pure_imagination": ("纯真的想象", "Pure Imagination"),
    "fen_shua_jiang": ("粉刷匠", "The House Painter"),
    "ye_de_gang_qin_qu_5": ("夜的钢琴曲五", "Melody of the Night No.5"),
    "ju_hua_tai": ("菊花台", "Chrysanthemum Terrace"),
    "an_he_qiao": ("安和桥", "Anhe Bridge"),
    "xiao_xing_xing": ("小星星", "Twinkle Twinkle Little Star"),
}

GENRE_BI = {
    "Classical": ("古典", "Classical"),
    "Anime": ("动画", "Anime"),
    "Pop": ("流行", "Pop"),
    "Game": ("游戏", "Game"),
    "Film": ("影视", "Film"),
    "Other": ("其他", "Other"),
}

KIND_BI = {
    "formal": ("正式谱", "Formal (proofread)"),
    "omrDraft": ("OMR草稿", "OMR draft (unproofed)"),
    "simplified": ("简编谱", "Simplified"),
    "userImport": ("自导入", "User import"),
}

DIFF_BI = {
    1: ("入门", "Beginner"),
    2: ("初级", "Easy"),
    3: ("中级", "Medium"),
    4: ("高级", "Hard"),
    5: ("极难", "Expert"),
}


def main() -> None:
    songs = json.loads(CATALOG.read_text(encoding="utf-8"))["songs"]
    formal = [s for s in songs if s.get("scoreKind") == "formal"]
    omr = [s for s in songs if s.get("scoreKind") == "omrDraft"]
    other = [
        s
        for s in songs
        if s.get("scoreKind") not in ("formal", "omrDraft")
    ]

    lines: list[str] = []
    lines.append("# PianoFlow 曲库曲目清单 / Score Catalog Inventory")
    lines.append("")
    lines.append("> 由 `assets/scores/catalog.json` 整理。仅含 App 曲库内建曲目，不含用户自导入。")
    lines.append(">")
    lines.append("> Generated from `assets/scores/catalog.json`. Built-in catalog only (excludes user imports).")
    lines.append("")
    lines.append(f"**合计 / Total:** {len(songs)} 首")
    lines.append("")
    lines.append(
        f"- 正式谱 / Formal: **{len(formal)}**"
    )
    lines.append(
        f"- OMR草稿 / OMR draft: **{len(omr)}**"
    )
    if other:
        lines.append(f"- 其他 / Other: **{len(other)}**")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 一览表 / Overview")
    lines.append("")
    lines.append(
        "| # | ID | 中文名 / Chinese | 英文名 / English | 作曲/艺人 / Artist | 风格 / Genre | 难度 / Diff | BPM | 谱种 / Kind |"
    )
    lines.append("|---:|---|---|---|---|---|---|---:|---|")

    for i, s in enumerate(songs, 1):
        sid = s["id"]
        zh, en = TITLE_BI.get(sid, (s["title"], s["title"]))
        genre = s.get("genre") or "Other"
        gzh, gen = GENRE_BI.get(genre, (genre, genre))
        diff = int(s.get("difficulty") or 0)
        dzh, den = DIFF_BI.get(diff, (str(diff), str(diff)))
        kind = s.get("scoreKind") or "?"
        kzh, ken = KIND_BI.get(kind, (kind, kind))
        artist = s.get("artist") or "—"
        bpm = s.get("bpm") or "—"
        lines.append(
            f"| {i} | `{sid}` | {zh} | {en} | {artist} | {gzh} / {gen} | {dzh} ({den}) · {diff} | {bpm} | {kzh} / {ken} |"
        )

    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## 正式谱 / Formal scores")
    lines.append("")
    lines.append("已校对 / 教材级 MusicXML，可标为正式精确谱。")
    lines.append("")
    lines.append("Proofread / textbook-grade MusicXML; eligible as formal exact scores.")
    lines.append("")
    _detail_section(lines, formal)

    lines.append("## OMR草稿 / OMR drafts")
    lines.append("")
    lines.append("PDF 经 Audiveris 等识谱入库，**未完成**开/中/尾逐音校对；UI 显示「OMR草稿」。禁止冒充正式谱。")
    lines.append("")
    lines.append(
        "OMR from PDF (e.g. Audiveris). **Not** fully proofread; UI shows “OMR draft”. Must not be labeled formal."
    )
    lines.append("")
    _detail_section(lines, omr)

    if other:
        lines.append("## 其他 / Other")
        lines.append("")
        _detail_section(lines, other)

    lines.append("---")
    lines.append("")
    lines.append("## 字段说明 / Field notes")
    lines.append("")
    lines.append("| 字段 / Field | 说明 / Meaning |")
    lines.append("|---|---|")
    lines.append("| ID | 曲目唯一键 / Unique song id |")
    lines.append("| 谱种 scoreKind | `formal` 正式谱；`omrDraft` OMR草稿 |")
    lines.append("| 难度 difficulty | 1 入门 … 5 极难 / 1 Beginner … 5 Expert |")
    lines.append("| durationHint | 约秒数（曲库卡片参考） / Approx. seconds (library card hint) |")
    lines.append("| asset | 练习用 JSON 乐谱路径 / Practice JSON path |")
    lines.append("")
    lines.append("## 维护")
    lines.append("")
    lines.append("- 源数据：`assets/scores/catalog.json`")
    lines.append("- 重新生成本表：`python scripts/export_catalog_inventory.py`")
    lines.append("- 谱种政策：`assets/scores/score_kind_policy.json`")
    lines.append("")

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(songs)} songs)")


def _detail_section(lines: list[str], songs: list[dict]) -> None:
    if not songs:
        lines.append("_（无） / (none)_")
        lines.append("")
        return
    for s in songs:
        sid = s["id"]
        zh, en = TITLE_BI.get(sid, (s["title"], s["title"]))
        genre = s.get("genre") or "Other"
        gzh, gen = GENRE_BI.get(genre, (genre, genre))
        kind = s.get("scoreKind") or "?"
        kzh, ken = KIND_BI.get(kind, (kind, kind))
        diff = int(s.get("difficulty") or 0)
        dzh, den = DIFF_BI.get(diff, (str(diff), str(diff)))
        lines.append(f"### {zh} / {en}")
        lines.append("")
        lines.append(f"- **ID:** `{sid}`")
        lines.append(f"- **作曲/艺人 Artist:** {s.get('artist') or '—'}")
        lines.append(f"- **风格 Genre:** {gzh} / {gen}")
        lines.append(f"- **难度 Difficulty:** {dzh} / {den} ({diff})")
        lines.append(f"- **BPM:** {s.get('bpm')}")
        lines.append(f"- **时长参考 Duration hint:** {s.get('durationHint')} s")
        lines.append(f"- **谱种 Kind:** {kzh} / {ken}")
        lines.append(f"- **资源 Asset:** `{s.get('asset')}`")
        desc = (s.get("description") or "").strip()
        if desc:
            lines.append(f"- **备注 Notes:** {desc}")
        lines.append("")


if __name__ == "__main__":
    main()
