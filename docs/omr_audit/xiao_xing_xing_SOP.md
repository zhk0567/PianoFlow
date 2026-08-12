# SOP 开/中/尾签字 — `xiao_xing_xing`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/xiao_xing_xing.pdf`（1 页简谱，1=C，4/4，♩=68）  
对照 MusicXML：`assets/scores/musicxml/xiao_xing_xing.musicxml`  
裁切：`docs/omr_audit/_jianpu_proof/xiao_xing_xing/sop_*.png`、`system_*.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（由简谱 PDF 人工/脚本转写），不是 MIDI
- [x] 与参考 PDF：调号（1=C→key=0）、拍号（4/4）、速度（♩=68）、双行（旋律+伴奏）一致
- [x] `<pitch>` 为发声音高；高八度点 → C5/G5 等；低八度点 → B3 等
- [x] 开篇 / 中段 / 尾段抽检通过（见下；全曲仅 12 小节，三段覆盖整曲）
- [x] `catalog.json` → `scoreKind: formal`（本清单签字后晋升）
- [x] `assets/scores/musicxml/` 与 `third_party/scores_musicxml/` 同 id 对齐
- [x] 护栏：`catalog_score_kind_guard.py` / `catalog_integrity_guard.py` / `score_kind_policy_sync.py --check`

## 抽检范围

| 段 | PDF 系统 | 小节 | 结论 |
|----|----------|------|------|
| OPEN | sys1（RH+LH） | m1–4 | **通过** |
| MID | sys2 | m5–8 | **通过** |
| END | sys3 | m9–12 | **通过**（m12 LH 尾音已修） |

## 证据摘要

### OPEN（m1–4）

| 小节 | PDF 简谱（1=C） | MusicXML |
|------|-----------------|----------|
| m1 | RH `1̇ 1̇ 5̇ 5̇`；LH `1 5 3 5 ×2` | C5 C5 G5 G5；LH C4 G4 E4 G4 ×2 八分 |
| m2 | RH `6̇ 6̇ 5̇ —`；LH `1 6 4 6 \| 1 5 3 5` | A5 A5 G5 half；LH 一致 |
| m3 | RH `4̇ 4̇ 3̇ 3̇`；LH 同 m2 型 | F5 F5 E5 E5；LH 一致 |
| m4 | RH `2̇ 2̇ 1̇ —`；LH `7̣ 5 4 5 \| 1 5 3 5` | D5 D5 C5 half；LH B3 G3 F3 G3 + C4… |

### MID（m5–8）

| 小节 | PDF | MusicXML |
|------|-----|----------|
| m5/m7 | RH `5̇ 5̇ 4̇ 4̇` | G5 G5 F5 F5 |
| m6/m8 | RH `3̇ 3̇ 2̇ —` | E5 E5 D5 half |
| LH | 分解和弦八分与 PDF 一致 | 已对拍 |

### END（m9–12）

- m9–11 = 开篇再现，MusicXML ≡ PDF
- m12 RH：`2̇ 2̇ 1̇ —` → D5 D5 C5 half
- m12 LH：前半 `7̣ 5 4 5`，后半 `1 —`（半音符）→ **本轮将错误的 C4 whole 改为 half**

## 本轮修正

- m12 LH 收束 C4：`type=whole duration=16` → `half duration=8`（与 PDF `1 —` 对齐，避免越拍）
- `musicxml_to_score.py --id xiao_xing_xing --score-kind omrDraft` → 再晋升

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id xiao_xing_xing --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
