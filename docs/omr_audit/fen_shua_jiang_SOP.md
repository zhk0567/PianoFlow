# SOP 开/中/尾签字 — `fen_shua_jiang`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/fen_shua_jiang.pdf`（1 页简谱，1=C，4/4，♩=120）  
对照 MusicXML：`assets/scores/musicxml/fen_shua_jiang.musicxml`  
裁切：`docs/omr_audit/_jianpu_proof/fen_shua_jiang/sop_*.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（简谱 PDF 转写），不是 MIDI
- [x] 与参考 PDF：1=C、4/4、♩=120、双行一致
- [x] `<pitch>` 发声音高；旋律高八度点 → ×5 八度
- [x] 开 / 中 / 尾抽检通过（全曲 16 小节）
- [x] `catalog.json` → `scoreKind: formal`
- [x] packaged ↔ third_party MusicXML 对齐
- [x] 护栏通过

## 抽检范围

| 段 | 小节 | 结论 |
|----|------|------|
| OPEN | m1–4 | **通过**（既有开篇校正） |
| MID | m5–12 | **通过**（m9–12 本轮按 PDF 重写） |
| END | m13–16 | **通过**（本轮重写） |

## 证据摘要

### OPEN（m1–4）

| 小节 | PDF | MusicXML |
|------|-----|----------|
| m1 | RH `5̇3̇5̇3̇`；LH `1— (5/3)—` | G5 E5 G5 E5；C3 half + G3/E4 |
| m2 | `5̇3̇1̇—`；同 LH | G5 E5 C5 half |
| m3 | `2̇4̇3̇2̇`；LH `7̣— (5/2)—` | D5 F5 E5 D5；B2 + G3/D4 |
| m4 | `5̇———` | G5 whole |

### MID / END（m5–16）

- m5–8 = 开篇再现（m8 RH=`1̇` whole）— 已对齐
- **原 m9–16** 误落中音区且 LH 简化错误 → 本轮按 PDF 重写为高八度旋律 + 同开篇伴奏型
- m9：`2̇2̇4̇4̇` + LH G7 型；m10：`3̇2̇5̇—` + C 型；m11–12 / m13–15 同对应开篇型
- m16：RH `1̇` whole；LH 大三和弦 C3+E3+G3 whole（PDF 收束 `(5/3/1)`）

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id fen_shua_jiang --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py --rewrite-dart
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
