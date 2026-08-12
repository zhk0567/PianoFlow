# SOP 开/中/尾签字 — `ye_de_gang_qin_qu_5`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/ye_de_gang_qin_qu_5.pdf`（2 页简谱，1=C，4/4，♩=120，双行）  
对照 MusicXML：`assets/scores/musicxml/ye_de_gang_qin_qu_5.musicxml`（49 小节 ≡ p1 9×4 + p2 3 系统含收束和弦）  
裁切：`docs/omr_audit/_jianpu_proof/ye_de_gang_qin_qu_5/p1.png`、`p2.png`、`_zoom/Y1_*.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（简谱 PDF 转写），不是 MIDI
- [x] 与参考 PDF：1=C、4/4、♩=120、双行；长度 49（原 XML 仅 16 ≪ p1≈36）
- [x] `<pitch>` 发声音高；LH 低二点琶音与开篇已校（F2–C3 族）一致
- [x] 开 / 中 / 尾抽检通过
- [x] `catalog.json` → `scoreKind: formal`
- [x] packaged ↔ third_party MusicXML 对齐
- [x] 护栏通过

## 抽检范围

| 段 | 小节 | 结论 |
|----|------|------|
| OPEN | m1–4 | **通过**（`Y1_01`：RH `0 0 67 1̇3̇` / `6̇— 67 1̇3̇` / `6̇— 2̇1̇71̇` / `6̇———`；LH 休止→F/G/Am 琶音 F2…） |
| MID | m17–20 / m33–36 | **通过**（主题再现；p1 末行高点 `1̇7 1̇2̇3̇6̇`… `1̈`；LH 持续琶音） |
| END | m45–49 | **通过**（`p2.png` 末系统：收束后 `6̇— 0 0` + 高音 Am 和弦 `6̇3̇1̇`；LH 末小节休止） |

## 证据摘要

- 全曲由 `_complete_ye_de_gang_qin_qu_5.py` 按 PDF 两页重写。
- LH 开篇与 `_fix_jianpu_openings.fix_ye` 一致（F2 C2 G2 A2 C3 等）。
- p2 末：m49 RH A5+E5+C5 和弦，LH 全休。

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id ye_de_gang_qin_qu_5 --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py --rewrite-dart
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
