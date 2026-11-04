# SOP 开/中/尾签字 — `jue_bie_shu`（诀别书）

日期：2026-10-18（第 2 轮：对**新六页 PDF**逐小节复核并重建结尾）
对照 PDF：`third_party/scores_pdf/jue_bie_shu.pdf`（6 页，带简谱数字注解）
参照：旧五页清晰版 PDF（仅结构对照；和弦/移调不同，未照搬）
对照 MusicXML：`third_party/scores_musicxml/jue_bie_shu.musicxml`
（由 `musicxml_to_score.py` 同步到 `assets/scores/musicxml/`）
结论：**通过（SOP 开/中/尾范围）— 可晋升 formal**。

> 范围说明：本轮按 `曲谱导入SOP.md` 的最低签字范围（开/中/尾各 ≥8 小节）执行；
> 全曲其余小节未逐音签。开篇 5 处误读与结尾 m103–m106 已按 PDF 修正。

## 来源与档位

| 项 | 现状 |
|----|------|
| 谱源 | 新六页 PDF → Audiveris OMR |
| `scoreKind` | 本轮通过后由 `omrDraft` 升 `formal` |
| 旧校对债 | R5–R13 针对 5 页旧 PDF，不能直接沿用 |
| 本轮 | 修开篇 5 处；中段抽查；结尾 m103–m106 重建；8va 修正 |

## 开篇已修（均有 PDF 对照）

| 小节 | 原 OMR | PDF 实际 | 说明 |
|------|--------|----------|------|
| m3 LH | B♭4 四分音符 | 二分休止符 | 休止符被误识成 B♭4，补足 4 拍 |
| m5 LH | A♭3 + D4 | B♭3 + F4/A4 + 二分休止 | 音高与和弦都错；已按 m1 写法修正 |
| m7 LH | D3 + D4 | D3 + B♭3 + D4 | 漏掉第 2 拍 B♭3 |
| m11 LH | 第 3 拍只有 C4 | C4 + E4 | 和弦塌成单音，补 E4 |
| m19 LH | 第 1/3 拍 D4 单音 | C4 + E4 和弦 | 两处和弦都塌成中间音，已还原 |

## 结尾重建（m103–m106）

| 小节 | 原 OMR | 按 PDF 重建 |
|------|--------|-------------|
| m103 | A4+D5、G5×3、A5；LH B♭2 + F2/A2/C3 | RH D5 全音符；LH B♭2→D3→F3→B♭3 琶音 |
| m104 | A5、D6、A5、G5（无 8va） | 8va 跑动 A6–D7–A6–G6；LH A2/C3/F3 全音符 |
| m105 | A5/G5 交替（无 8va） | 8va 后 A6/G6 交替 6 音；LH D2 全音符 |
| m106 | D2+B♭2 全音符 | 保持；收尾低音 D2+B♭2 |

8va 处理：MusicXML `<pitch>` 写**发声音高**（A6/D7/G6），并保留
`octave-shift type="down" size="8"` 供 Verovio 记谱；练习 JSON 由 `pitch` 直接生成，
不会重复升八度。

## 音符数与转换

| 阶段 | 音符数 | JSON ≡ XML reparse |
|------|--------|--------------------|
| 新 OMR 初稿 | 1398 | True |
| 开篇 5 处修正后 | 1402 | True |
| 结尾 m103 重建后 | **1397** | **True** |

## 开/中/尾签字

| 段 | PDF | 小节 | 结论 |
|----|-----|------|------|
| OPEN | p1 | m1–m8 | **通过**：RH 与蓝色简谱逐音一致；LH 五处误读已修，休止与拍数对齐 |
| MID | p3 | m45–m52 | **抽查通过**：和弦、跑动、左右手层级与 PDF 一致；密织处未逐音签完 |
| END | p6 | m99–m102 | **抽查通过**：和弦/跑动结构一致 |
| END | p6 | m103–m106 | **通过**：长音、8va 跑动、A–G 交替与收尾和弦均已按 PDF 修正 |

## 升格清单

- [x] 谱源 MusicXML，非 MIDI
- [x] 开/中/尾各 ≥8 小节对照新六页 PDF
- [x] 8va 以发声音高写入 `<pitch>`，不重复升八度
- [x] `JSON ≡ MusicXML reparse = True`
- [x] 三项曲库护栏 OK
- [x] `flutter test` 217 passed
- [x] Android `assembleDebug` Pass
- [x] 本 SOP 标记「可晋升」

升格命令：

```powershell
python scripts/omr_promote_formal.py --id jue_bie_shu --confirm-sop-passed
```

## 工具

```powershell
python scripts/omr_audit_score.py --id jue_bie_shu
python scripts/omr_formal_queue.py --check-sop jue_bie_shu
python scripts/_jbs_audit.py
```

本轮使用的逐小节对照工具（临时目录，未入库）：
`_tmp_jbs_verify/annotate_measure.py`、`dump_measures.py`、`noteheads_cv.py`。
