# SOP 开/中/尾签字 — `beethoven_moonlight_sonata`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/beethoven_moonlight_sonata.pdf`（4 页，♩=44，4 升，4/4）  
对照 MusicXML：`assets/scores/musicxml/beethoven_moonlight_sonata.musicxml`  
学术音符表：`docs/omr_audit/_moonlight_proof/14-1.notes.tsv`（DCMLab 14-1）  
裁切：`docs/omr_audit/_moonlight_proof/sop_*.png`、`sop_open_m*.png`

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML，不是 MIDI
- [x] 与参考 PDF：调号（4 升）、拍号（4/4）、速度（♩=44）、谱号一致
- [x] `<pitch>` 为发声音高（无错误 8vb 偏移）；LH 八度以 C#2+C#3 等记写，与 DCMLab MIDI 一致
- [x] 开篇 / 中段 / 尾段抽检通过（见下）
- [x] `catalog.json` → `scoreKind: formal`（本清单签字后晋升）
- [x] `assets/scores/musicxml/` 与 `third_party/scores_musicxml/` 同 id 对齐
- [x] 护栏：`catalog_score_kind_guard.py` / `catalog_integrity_guard.py` / `score_kind_policy_sync.py --check`

## 抽检范围

| 段 | PDF 页/系统 | 小节 | 结论 |
|----|-------------|------|------|
| OPEN | p1 sys1–3 | m1–8（桥至 m15） | **通过** |
| MID | p2（约 m28 起） | m28–40 | **通过** |
| END | p3–p4 | m60–69 | **通过** |

## 证据摘要

### 方法

1. 渲染 PDF 开/中/尾裁切至 `_moonlight_proof/sop_*`。
2. 导出当前 MusicXML 各抽检小节的音高/时值。
3. 与 DCMLab `14-1.notes.tsv` 做 **MIDI 多重集合** 全曲比对。
4. 与 **git HEAD 原始 Audiveris OMR**（同仓库 PDF 识谱产物）比对开篇：原 OMR 在 m3–11、m13–15 与 DCMLab 一致；此前手写简化的 m3–8/m9–15 **偏离 PDF+DCMLab**，本轮已按 DCMLab 重写。

### OPEN（m1–8）

| 小节 | MusicXML（当前）要点 | vs DCMLab | vs 原 OMR(PDF) |
|------|----------------------|-----------|----------------|
| m1 | RH G#3–C#4–E4 ×4；LH C#2+C#3 whole | 一致 | 原 OMR 多幽灵 G#5；已删 |
| m2 | 同三连音；LH B1+B2 | 一致 | 一致 |
| m3 | A–C#–E ×2，A–D♮–F# ×2；LH A / F# | 一致 | 一致 |
| m4 | G#–B#–F# / G#–C#–E / …（DCMLab 织体） | 一致 | 一致 |
| m5 | 旋律 G# 自第 4 拍进入；LH C#–G#–C# | 一致 | 一致 |
| m6–8 | 主题续进（G# / A / F#–B 等） | 一致 | 一致 |

编订差异（诚实）：三连音数字「3」、力度/踏板线、符干方向等属刻版；**音高节奏以 PDF+DCMLab 为准**。先前误把开篇改成「简化教学版」旋律（m5 起拍即 G# 附点半音等）已回退。

### MID（m28–40）

全段 MusicXML MIDI ≡ DCMLab；代表性：

- m28：RH B# 跳进三连音 + G#/A/F# 四分强调；LH G# 八度
- m32–36：属持续上的半音攀升/下行
- m40：B#–… 进入下属；LH G#→A

原 OMR 在部分中后小节有识谱噪声；以 DCMLab（与 PDF 开篇交叉验证同源）落地。

### END（m60–69）

全段 MusicXML MIDI ≡ DCMLab；代表性：

- m60–62：收束琶音 + G# 附点节奏型
- m63/65：B# 下行经过句
- m68–69：C# 小调和弦收束

## 全曲一致性门禁（本轮）

- m1–69：**0** 小节 CUR≠DCMLab（MIDI 多重集合）
- 全部声部时值 sum=48（divisions=12，4/4）
- BPM JSON/parse = 44；keySignature = 4

## 晋升

```powershell
python .\scripts\omr_promote_formal.py --id beethoven_moonlight_sonata --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
