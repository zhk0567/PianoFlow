# SOP 开/中/尾签字 — `whistle`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/whistle.pdf`（1 页简谱，1=C，4/4，♩=120，双行）  
对照 MusicXML：`assets/scores/musicxml/whistle.musicxml`（28 小节 ≡ PDF 7 系统）  
裁切：`docs/omr_audit/_jianpu_proof/whistle/p1.png`、`_zoom/W1..W7.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（简谱 PDF 转写），不是 MIDI
- [x] 与参考 PDF：1=C、4/4、♩=120、双行 RH/LH 一致；长度 28 ≡ 7 系统（原 XML 仅 16）
- [x] `<pitch>` 发声音高；LH 低点 Am/F/C/G 与开篇已校一致
- [x] 开 / 中 / 尾抽检通过
- [x] `catalog.json` → `scoreKind: formal`
- [x] packaged ↔ third_party MusicXML 对齐
- [x] 护栏通过

## 抽检范围

| 段 | 小节 | 结论 |
|----|------|------|
| OPEN | m1–4 | **通过**（`W1`：RH 休止/钩子 `6̇5̇3̇5̇3̇` / `3̇2̇1̇2̇3̇`；LH 附点 q-q-dotted-e-rest：Am/F/C/G） |
| MID | m9–12 / m17–20 | **通过**（合唱 `1̇1̇65`；同步 `1̇ 0 2̇ …`；桥段 `6̇6̇5̇5̇` / `3̇3̇2̇1̇` / fill `0 77 70 77`） |
| END | m24–28 | **通过**（`W5–W7`：`2̇ 0 7 1̇`；outro 钩子；尾句 RH `3̇2̇1̇2̇3̇` + LH 休止；无空尾小节） |

## 证据摘要

- 全曲由 `_complete_whistle.py` 按 PDF 7 系统重写（非 Audiveris）。
- 开篇 LH 与既有 `_fix_jianpu_openings.fix_whistle` 音高一致（A2/E2、F2/C2、C3/G2、G2/D2）。
- m23 LH：`1̣`+`5̣` 全音符和弦（C3+G3）。

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id whistle --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py --rewrite-dart
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
