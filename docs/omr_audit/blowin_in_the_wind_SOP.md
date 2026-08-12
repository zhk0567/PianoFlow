# SOP 开/中/尾签字 — `blowin_in_the_wind`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/blowin_in_the_wind.pdf`（1 页简谱，1=C，4/4，♩=120）  
对照 MusicXML：`assets/scores/musicxml/blowin_in_the_wind.musicxml`  
裁切：`docs/omr_audit/_jianpu_proof/blowin_in_the_wind/sop_*.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（简谱单声部转写），不是 MIDI
- [x] 与参考 PDF：1=C、4/4、♩=120 一致
- [x] 开 / 中 / 尾抽检通过（全曲 23 小节，单行旋律）
- [x] `catalog.json` → `scoreKind: formal`
- [x] packaged ↔ third_party 对齐
- [x] 护栏通过

## 抽检范围

| 段 | 小节 | 结论 |
|----|------|------|
| OPEN | m1–4 | **通过** |
| MID | m5–19 | **通过** |
| END | m20–23 | **通过** |

## 证据摘要（PDF ≡ MusicXML）

| 小节 | PDF 简谱 | MusicXML |
|------|----------|----------|
| m1 | `5— 5 5` | G4 half + G4 q + G4 q |
| m2 | `6— 6 6` | A4 half + A4 + A4 |
| m3 | `5— 3 2` | G4 half + E4 + D4 |
| m4 | `1— 0 3` | C4 half + rest + E4 |
| m5–7 | `5— 0 5 \| 6— 5 4 \| 5———` | 一致 |
| m8 | `0 0 3 4` | 两休止 + E4 F4 |
| m9–15 | 主歌再现至 `2———` | 一致 |
| m16–19 | `0 0 0 3 \| 4— 4 3 \| 2— 0 2 \| 3 3 3 2` | 一致 |
| m20–23 | `1— 0 3 \| 4— 4 3 \| 2 2 1 2 \| 1———` | 一致；收束 C4 whole |

诚实：本版为 **单声部旋律简谱**（LH 休止），非钢琴织体教材谱；音高节奏与仓库 PDF 逐小节一致。

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id blowin_in_the_wind --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py --rewrite-dart
```
