# SOP 开/中/尾签字 — `hisaishi_castle_in_the_sky`

日期：2026-08-07（第二轮：m21–24 多源对照）  
对照 PDF：`third_party/scores_pdf/hisaishi_castle_in_the_sky.pdf`（2 页，♩=80，key=0，4/4）  
对照 MusicXML：`assets/scores/musicxml/hisaishi_castle_in_the_sky.musicxml`  
裁切：`docs/omr_audit/_castle_sop/`（p1/p2 400dpi + `proof_m19`–`proof_m24` + sys bands）  
结论：**未通过 — 禁止 formal**

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML，不是 MIDI
- [x] 调号 / 拍号 / 速度：key=0、4/4、♩=80
- [ ] 开篇 / 中段 / 尾段 **全部**逐音通过（见下 — 中段/尾段未齐）
- [ ] `catalog.json` → `scoreKind: formal`（**未晋升**）
- [x] `assets/scores/musicxml/` ≡ `third_party/scores_musicxml/`（同 sha）
- [x] 护栏：`catalog_score_kind_guard` / `catalog_integrity_guard` / `score_kind_policy_sync --check`（仍 omrDraft×22）

## 抽检范围

| 段 | PDF | 小节（MusicXML number） | 结论 |
|----|-----|-------------------------|------|
| OPEN | p1 sys1 | m0 pickup + m1–6 | **部分通过**（时值已修；音高沿用既有 PDF 对齐稿） |
| MID | p1 sys4–5 | m19–30（含 **m21–24**） | **未通过**（多源读音不一致，未猜改） |
| END | p2 | m40–49 | **部分通过**（仅 **m49=A4/A2** 对照 `castle_p2_bot` / `end_band4`；**m40–48 未逐音重签**） |

## 本轮（m21–24）证据

1. 已渲染：`p1_400.png` / `p2_400.png`、`proof_m19.png`–`proof_m24.png`、既有 `p1_sys4.png` + `_open_fix/castle_s4_m*.png`。
2. 已 dump：`docs/omr_audit/_castle_sop/_dump_m19_30_and_m40_49.txt`（当前稿）。
3. **当前稿 m21–24**（未改）：
   - m21 RH A4 whole / LH G3 whole
   - m22 RH C5 D5 E5 D5 E5 F5 / LH C3 half + G2 half
   - m23 RH A4 dotted-q G4 e A4 half / LH F2 whole
   - m24 RH B4 A4 G4 F4 quarters / LH G2 whole
4. **多源不同意**：同一 `p1_sys4` / `castle_sys4_ann` / `castle_s4_m*` / `castle_full_p1` 上，自动视觉读音在多次对照中给出互相矛盾的 RH/LH（例如 m21 被读成 A4/G3、E5/C3、C5/E3、A5/F3、F5/G2 等）；staff 几何估音漏检空心符头且八度漂移。**无第二权威源**（无 DCMLab 类对照）。按规则 **禁止猜改音高** → **未重写**。
5. 重转：`musicxml_to_score.py --score-kind omrDraft` → JSON 213 notes，仍 **omrDraft**。

## 先前已修（仍有效）

1. 开篇时值：m1/m3/m5 → eighth=3、quarter=6（`divisions=6`）。
2. 终小节 m49：RH A4 whole + LH A2 whole + light-heavy。

## 阻塞 formal（精确剩余）

| 小节 | 状态 | 需要 |
|------|------|------|
| **m21–24** | 读图不确定 | MuseScore 对 PDF 逐音签字（或第二权威 MusicXML 交叉一致） |
| **m40–48** | 未本轮逐音重签 | MuseScore 对 PDF p2 逐音签字 |
| m19–20 / m25–30 | 沿用既有桥段稿 | 建议与 m21–24 一并目视确认 |
| m49 | 已通过 | — |

## 晋升条件（未满足）

```powershell
# 仅在开/中/尾 SOP 全部逐音通过后：
python .\scripts\omr_promote_formal.py --id hisaishi_castle_in_the_sky --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
