# 只有 PDF 时：高精度识谱，并逼近 FlowKey

## 你的三条硬约束

1. **源只有 PDF**（改不了）
2. **要最高精度**（和 PDF 逐音一致）
3. **体验最高限度接近 FlowKey**；做不到再谈别的方案

本文约定：正式曲入库仍遵守「禁止 MIDI→MusicXML」。

---

## 为什么「PDF 那么清楚」还会识错？（这不是偷懒）

对人眼来说，PDF 是「已经排好的乐谱」。  
对程序来说，绝大多数曲谱 PDF（含 jsPDF / MuseScore 导出）是：

> **一堆画出来的线、符头、符干** —— **没有**「这是 D3、八分音符、左手」这种结构化数据。

所以不存在「提取」：只有 **OMR（光学识谱）= 看图猜符号**。

类比：

| 场景 | 人眼 | 电脑 |
|------|------|------|
| 拍一张非常清晰的中文报纸 | 一眼能读 | OCR 仍会把「已/己」搞错 |
| 清晰钢琴谱 | 一眼能弹 | OMR 仍会把符头、升降号、声部、8vb、反复弄错 |

**清楚 → 提高识别率；不等于 100%。**  
Audiveris 官方也写过：很多谱 **达不到 100% 识别率**。业界流程永远是：

**OMR 出初稿 → 对着 PDF 人工校对 → 导出 MusicXML → 再进 App。**

这不是我们项目特殊，FlowKey / Simply Piano 的曲库也 **不是**靠「用户丢一张 PDF 自动完美上架」——他们用的是 **已经校对好的数字谱**（采购/自制 MusicXML 一类）。

所以：

- 「只有 PDF」= 可以做，但 **必须接受 OMR + 校对**，才能达到你要的「最高精度」。
- 「全自动、零校对、又和 PDF 完全一致」—— **目前业界做不到**；谁承诺都能自动完美，不可信。

---

## 在「只有 PDF」前提下，最高精度路线（本项目标准）

```
PDF（归档在 third_party/scores_pdf/）
  → 高分辨率渲染（≥300dpi，优先整页图）
  → Audiveris（或更强的商业 OMR）出 MusicXML 初稿
  → MuseScore / Audiveris 编辑器 对着 PDF 逐段校对
  → 通过「谱面 ↔ 自动演奏」抽检
  → scripts/import-score.ps1 入库
```

验收标准（达不到就不上架 formal）：

- 橙线处符头 = 亮键 = 下落条 = 耳朵听到的音
- 抽检至少：开头 8 小节、中段 8 小节、结尾 8 小节，与 PDF 一致
- 有 8vb / 反复 / 1–2 结尾时，必须单独核对

工具脚本（见 `scripts/omr-from-pdf.ps1`）：把 PDF 送进本机 Audiveris 批处理，产出到 `_omr_work/{id}/`。

---

## 和 FlowKey 对齐时，谱只是底座

即使谱 100% 准，FlowKey 体感还取决于：

| 层 | FlowKey | 我们要对齐的点 |
|----|---------|----------------|
| 谱 | 专业校对数字谱 | PDF→OMR→校对后的 MusicXML |
| 听 | 高质量采样、延音、声像 | 已在做立体声/延音，继续磨 |
| 视 | 下落+谱+键一体、不抖不挡 | Verovio 稳定、无白屏、播放头同步 |
| 练 | 等音、反馈、课程节奏 | 练习模式打磨 |

**谱不准，后面全白做。** 所以 PDF 路径上，精度优先于速度。

---

## 若「OMR + 校对」仍达不到你要的 FlowKey 体感——备选方案

按推荐顺序：

1. **采购/委托同版 MusicXML**（仍用你的 PDF 当验收金标准）——最快达到「完全一致」
2. **商业 OMR**（PhotoScore、PlayScore、ScanScore 等）+ 人工校对——通常比开源 Audiveris 省校对时间
3. **专业制谱外包**（按你的 PDF 重制 MusicXML）——贵，但精度最高
4. **换内容策略**：只上有数字源的曲目；PDF-only 曲作「实验/低优先级」

这些才是「不行再考虑的其他方案」；不是放弃钢琴 App，而是放弃「全自动从 PDF 零误差」的幻想。

---

## 当前执行决议

- 默认输入：**PDF**（`third_party/scores_pdf/`）
- 默认引擎：**Audiveris**（本机安装后用 `scripts/omr-from-pdf.ps1`）
- 默认质量门：**人工对着 PDF 校对通过** 才能升 `formal`；未校对入库只能 `omrDraft`
- 入库草稿：`omr-finish-import.ps1` 固定 `omrDraft` + `--fail-on-drift`
- 升 formal：`omr_promote_formal.py --id <id> --confirm-sop-passed`（须确认 SOP 开/中/尾）
- 进度与工具：[`omr_audit/PROOFREAD_STATUS.md`](./omr_audit/PROOFREAD_STATUS.md)
- App 体验：在谱准的前提下，持续把播放、谱面、练习反馈往 FlowKey 靠

**现状（2026-08-04）：** catalog **formal ×15**。原 OMR×12 已完成 PDF 速度/节奏补洞、JSON≡XML、开/中/尾 SOP 抽检后升 formal（证据见 `docs/omr_audit/PROOFREAD_STATUS.md`）。新 PDF 曲未校对前仍须 `omrDraft`。
