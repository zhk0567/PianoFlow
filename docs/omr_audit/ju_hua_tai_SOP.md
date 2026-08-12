# SOP 开/中/尾签字 — `ju_hua_tai`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/ju_hua_tai.pdf`（1 页简谱，1=F，4/4，♩=76，双行）  
对照 MusicXML：`assets/scores/musicxml/ju_hua_tai.musicxml`（24 小节 ≡ PDF 5 系统）  
裁切：`docs/omr_audit/_jianpu_proof/ju_hua_tai/pair_01..05.png`、`zoom_m16.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML（简谱 PDF 转写），不是 MIDI
- [x] 与参考 PDF：1=F、4/4、♩=76、双行 RH/LH 一致
- [x] `<pitch>` 发声音高；LH 一/二点 → oct−1/−2；F 大调 Bb 用降号拼写
- [x] 开 / 中 / 尾抽检通过（全曲 24 小节 ≡ PDF 5 系统）
- [x] `catalog.json` → `scoreKind: formal`
- [x] packaged ↔ third_party MusicXML 对齐
- [x] 护栏通过

## 抽检范围

| 段 | 小节 | 结论 |
|----|------|------|
| OPEN | m1–4 | **通过**（`pair_01`：RH `3 32 3—`…；LH `1̣ 7̣̣ \| 6̣̣ 5̣̣ \| 4̣̣ 3̣̣ \| 2̣̣ 5̣̣` → F3 E3 / D3 C3 / Bb2 A2 / G2 C3） |
| MID | m15–19 | **通过**（`pair_04` + `zoom_m16`：m16 RH `2_(0.5) 1.(1.5) 0(1) 12`；LH 全一点；m17 起 RH 高点） |
| END | m20–24 | **通过**（`pair_05`：RH 收束 `3— 2—`；LH 全一点 `2̣5̣…`） |

## 证据摘要

### OPEN（m1–4，1=F）

| 小节 | PDF LH 点位 | MusicXML LH |
|------|-------------|-------------|
| m1 | `1̣— 7̣̣—` | F3 half + E3 half |
| m2 | `6̣̣— 5̣̣—` | D3 + C3 |
| m3 | `4̣̣— 3̣̣—` | Bb2 + A2 |
| m4 | `2̣̣— 5̣̣—` | G2 + C3 |

### MID（含原阻塞项）

- **m16 RH**：PDF `2 1. 0 1 2` → eighth + dotted-quarter + quarter-rest + two eighths（满 4 拍）；先前错误填拍已纠正。
- **中段 LH 一/二点**（按系统裁切逐音）：
  - m5–9：`6̣̣3̣ \| 4̣3̣ \| 2̣2̣ \| 5̣̣5̣̣ \| 1̣7̣̣`
  - m10–14：`6̣̣5̣̣ \| 4̣3̣ \| 2̣5̣ \| 6̣̣3̣ \| 4̣3̣`
  - m15–19：全部一点（含 m16 `1̣———`）
- Bb 拼写：degree 4 → `B`+`alter=-1`（非 A#）。

### END（m20–24）

- RH / LH 与 `pair_05` 一致；尾句 `3— 2—` / LH `2̣— 5̣—`。

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id ju_hua_tai --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py --rewrite-dart
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
