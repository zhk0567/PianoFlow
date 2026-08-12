# SOP 开/中/尾签字 — `sawano_call_of_silence`

日期：2026-08-07  
对照 PDF：`third_party/scores_pdf/sawano_call_of_silence.pdf`（2 页，♩=60，key=0，4/4）  
对照 MusicXML：`assets/scores/musicxml/sawano_call_of_silence.musicxml`  
裁切：`docs/omr_audit/_silence_sop/`（`open_m*` / `mid_m*` / `end_m_last` + `_dump_open_mid_end.txt`）  
结论：**未通过 — 禁止 formal**  
（2026-08-09：重渲 `_silence_sop/sys1–6.png` + `bars/m11–14*.png`；RH 仍多源不一致，**未猜改音高**）

## 验收清单（`docs/曲谱导入SOP.md`）

- [x] 谱源是 MusicXML，不是 MIDI
- [x] 调号 / 拍号 / 速度：key=0、4/4、♩=60
- [ ] 开篇 / 中段 / 尾段 **全部**逐音通过（见下 — 中段桥 + 8va + 尾未齐）
- [ ] `catalog.json` → `scoreKind: formal`（**未晋升**）
- [x] `assets/scores/musicxml/` ≡ `third_party/scores_musicxml/`（同 sha）
- [x] 护栏：`catalog_score_kind_guard` / `catalog_integrity_guard` / `score_kind_policy_sync --check`（仍 formal×4 + omrDraft×22）

## 抽检范围

| 段 | PDF | 小节（MusicXML number） | 结论 |
|----|-----|-------------------------|------|
| OPEN | p1 sys1–2 | m1–10 | **部分通过**（既有 PDF 重写稿；本轮未改音高） |
| MID | p1 sys3–6 | m11–27（含 **m11–14**、**8va m20+**） | **未通过**（m11–14 多源读音不一致未猜改；m15–19 既有主题稿保留；8va 未逐音重签） |
| END | p2 末系统 | m38–45 | **未通过**（未做 PDF 逐音签字；尾音仍为 OMR 稿 A6） |

## 本轮证据与改动

1. 候选选择：相对铃芽（仅开篇）、如愿/梦中婚礼（仅开篇），Silence 已有 **m1–10 + m15–19** PDF 对齐稿 + 既有 `_open_fix` / `_silence_proof` 裁切，开/中证据路径最完整；天空之城 m21–24 本轮不碰。
2. 渲染：`docs/omr_audit/_silence_sop/open_m1_5.png` … `mid_m24_27.png`、`end_m_last.png`、`m11_bar`–`m14_bar`、`_dump_open_mid_end.txt`。
3. **m11–14**：当前稿（与 git HEAD 同）RH 低音区 E4/B3/A3…；LLM 视觉多次互斥、staff 几何误检谱线为符头。**无第二权威源** → **禁止猜改**，未重写。
4. **结构缺口已闭**：m20 孤儿 `forward(30)+voice6 A4 half` 越出小节（时值审计 voice6≠32）→ 删除第二 backup 之后碎片；RH+LH voice5 已满拍。重转 JSON **603** notes（原 604）。
5. 时值审计：全曲 voice sum **0** mismatch；仍 **omrDraft**。

## 先前已修（仍有效）

1. 开篇 m1–10：m1 双休；m2 起句 G4/A4/C5 + LH 全音符和弦等（2026-08-05）。
2. 中段主题 m15–19：RH 主题 + LH C/G/Am/F 四分和弦；m19 延长休止（`_fix_silence_mid.py`）。

## 阻塞 formal（精确剩余）

| 小节 | 状态 | 需要 |
|------|------|------|
| **m11–14** | 读图不确定 | MuseScore 对 PDF 逐音签字（或第二权威源交叉） |
| **m20–27（8va）** | 未本轮逐音重签 | MuseScore 对 PDF 8va 段逐音 |
| **m38–45 尾** | 未逐音签字 | MuseScore 对 PDF p2 末系统逐音 |
| m1–10 / m15–19 | 既有 PDF 对齐稿 | 建议与中/尾一并目视确认后签字 |

## 晋升条件（未满足）

```powershell
# 仅在开/中/尾 SOP 全部逐音通过后：
python .\scripts\omr_promote_formal.py --id sawano_call_of_silence --confirm-sop-passed
python .\scripts\score_kind_policy_sync.py
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
```
