# SOP 开/中/尾签字 — `bella_ciao`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/bella_ciao.pdf`（2 页简谱，1=G，2/4，♩=120，单旋律）  
对照 MusicXML：`assets/scores/musicxml/bella_ciao.musicxml`（88 小节，LH 休止）  
裁切：`docs/omr_audit/_jianpu_proof/bella_ciao/sop_*.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（简谱 PDF 转写），不是 MIDI
- [x] 与参考 PDF：1=G、2/4、♩=120、单行旋律一致
- [x] `<pitch>` 发声音高；高八度点 → ×5/×6 八度
- [x] 开 / 中 / 尾抽检通过（全曲 88 小节 ≡ PDF p1+p2）
- [x] `catalog.json` → `scoreKind: formal`
- [x] packaged ↔ third_party MusicXML 对齐
- [x] 护栏通过

## 抽检范围

| 段 | 小节 | 结论 |
|----|------|------|
| OPEN | m1–4 | **通过**（`sop_open_m1-4.png` ≡ `0 3 6 7 \| 1̇ 6 6` ×2） |
| MID | m25–29 | **通过**（`sop_mid_chorus.png` ≡ `3̇3̇2̇3̇ \| 4̇4̇4̇ \| 0 4̇3̇2̇ \| 4̇3̇3̇ \| 0 3̇2̇1̇`） |
| END | m80–88 | **通过**（`sop_end_pre.png` + `sop_end_final.png`：`6— \| 0 3̇2̇3̇ \| … \| 0 3̇2̇1̇ \| 7 3̇ \| 1̇ 7 \| 6— \|\|`） |

## 证据摘要

### OPEN（m1–4，1=G）

| 小节 | PDF | MusicXML |
|------|-----|----------|
| m1 | `0 3 6 7`（均为八分） | R B4 E5 F#5 |
| m2 | `1̇ 6 6` | G5 E5 E5 |
| m3–4 | 同 m1–2 | 同 |

### MID / END

- 本轮按 PDF **全曲重写**：原 XML 仅 22 小节；p1 另有多段反复 + p2≈19 小节未入库 → 现 88 小节。
- p2 收束前出现 `6— \| 0 3̇ 2̇ 3̇`（非标准 `3̇3̇2̇3̇`），按 PDF 视觉保留。
- LH 全休止（PDF 为单行旋律简谱）。

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id bella_ciao --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py --rewrite-dart
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
