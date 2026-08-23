# 曲谱导入 SOP（准确优先 + 批量要快）

## 一句话结论

**若你只有 PDF（本项目当前硬约束）**：走 **高精度 OMR → 对着 PDF 校对 → MusicXML 入库**（见下文「只有 PDF」专节）。  
**PDF 清晰 ≠ 能无损「提取」音符**——程序看到的是图画，OMR 是识图猜音；业界也做不到全自动 100%。  
若将来能拿到与 PDF **同版**的 MusicXML/MSCZ，仍是最快且最稳的 A 档路径。

---

## 为什么不能「PDF 提取」出最精细谱？

| PDF 实际是什么 | 结果 |
|----------------|------|
| 矢量/位图「画」出来的五线谱（常见：MuseScore 导出、jsPDF） | **没有**内嵌 MusicXML；只有图形。电脑看到的是线条和圆点，不是「这是 C4 八分音符」 |
| 少数带嵌入字体的 PDF | 仍通常不是 MusicXML，最多能抠到文字标题 |
| 真正可提取的源 | `.musicxml` / `.mxl` / `.mscz`（MuseScore 工程） |

**OMR（光学识谱，如 Audiveris）** = 看图猜音符，不是无损解压：

- 清晰 PDF 能提高识别率，但密集钢琴谱、和弦、跨谱表、反复、8vb、临时升降号仍常错
- 业界标准流程是：OMR → **人工在 MuseScore 里改对** → 再导出 MusicXML
- 所以：OMR **不能**单独满足「完全一致」；也不能当作默认快速通道

**MIDI→MusicXML** 在本项目 **正式谱禁止**（会丢声部/谱表、乱写临时升降号，曾导致 Fur Elise 翻车）。

对人眼「已经排好的乐谱」，对程序往往是「画出来的线与符头」——**清楚 → 提高识别率；不等于 100%**。FlowKey 类产品曲库也是**已校对数字谱**，不是「用户丢 PDF 自动完美上架」。

---

## 只有 PDF 时：高精度路线（本项目标准）

```
PDF（归档在 third_party/scores_pdf/）
  → 高分辨率渲染（≥300dpi，优先整页图）
  → Audiveris（或更强的商业 OMR）出 MusicXML 初稿
  → MuseScore / Audiveris 编辑器 对着 PDF 逐段校对
  → 通过「谱面 ↔ 自动演奏」抽检
  → scripts/import-score.ps1 入库
```

验收（达不到就不上架 formal）：

- 橙线处符头 = 亮键 = 下落条 = 耳朵听到的音
- 抽检至少：开头 / 中段 / 结尾各 8 小节与 PDF 一致
- 有 8vb / 反复 / 1–2 结尾时单独核对

工具：`scripts/omr-from-pdf.ps1`（本机 Audiveris 批处理 → `_omr_work/{id}/`）。

**和 FlowKey 对齐时，谱只是底座**：听（采样）、视（下落+谱+键）、练（等音/反馈）都要在谱准之后再磨。备选：采购同版 MusicXML、商业 OMR、制谱外包、或只上有数字源的曲。

---

## 速度与准确度梯度（以后加曲按此选）

| 优先级 | 你提供什么 | 准确度 | 耗时 | 用法 |
|--------|------------|--------|------|------|
| **A（默认）** | 与 PDF **同版**的 `.musicxml` / `.mxl` / `.mscz` | 可与 PDF 逐音一致 | **约 10–30 秒** | `.\scripts\import-score.ps1` |
| **B** | 只有 PDF，但能下到同版数字源 | 同 A | 下载几分钟 + A | PDF 对照 + A |
| **C** | 只有 PDF，无数字源 | 需 OMR + 校对后才可上架 | 数十分钟～数小时 | `_omr_work/` 校对后再 A |
| **禁止** | 仅 MIDI / music21(MIDI) | 不够正式谱标准 | — | 不上架 formal |

**批量加曲：** 每首准备好 A 档源；慢的是找源或手改 OMR，不是转换脚本。

---

## 一键导入（A 档）

在仓库根目录：

```powershell
Set-Location F:\commercial\PianoFlow

.\scripts\import-score.ps1 `
  -Id "some_piece_id" `
  -Source "C:\path\to\score.musicxml" `
  -Title "曲名" `
  -Artist "作曲家" `
  -Genre "Classical" `
  -Difficulty 3 `
  -Description "来源与版权说明"
```

也支持 `-Source` 为 `.mxl` 或 `.mscz`（本机 MuseScore CLI 可自动导出）。可选 `-Pdf` 归档参考 PDF。

脚本会：复制/转换 MusicXML → 同步 assets → 生成 JSON → 更新 catalog → 跑三项护栏。然后**完全重启 App**。

---

## 入库护栏（每次导入 / 批量转换后必过）

```powershell
Set-Location F:\commercial\PianoFlow

python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
python .\scripts\score_kind_policy_sync.py --check
```

`convert-scores.ps1` / `import-score.ps1` / `omr-finish-import.ps1` 末尾会自动跑上述三项。  
`genre` 用英文码：`Classical` / `Anime` / `Pop` / `Game`。  
重跑 `--update-catalog` 时保留已有 `scoreKind`；无 `<sound tempo>` 时保留已有 BPM。

---

## PDF 仅作对照（推荐习惯）

`third_party\scores_pdf\{id}.pdf` 与 MusicXML id 同名。示例：`fur_elise_woo59.pdf`、`pachelbel_canon_d.pdf`、`megalovania.pdf`。

---

## C 档：仅有 PDF 时

1. PDF 放入工作目录 / `third_party\scores_pdf\`
2. Audiveris / MuseScore 得草稿 MusicXML
3. **对照 PDF 改到满意**
4. 再执行 A 档 `import-score.ps1`

未校对 OMR **不要**标 `formal`；可先 `omrDraft`（UI：「OMR草稿」）。

```powershell
python .\scripts\omr_audit_score.py --id hisaishi_castle_in_the_sky
python .\scripts\omr_audit_score.py --all-omr --fail-on-drift
```

报告在 `docs\omr_audit\`。脚本**永远不会**升 formal。`omr-finish-import.ps1` 固定 `omrDraft`。

---

## 验收清单（每首正式曲）

- [ ] 谱源是 MusicXML/MSCZ，不是 MIDI
- [ ] 与参考 PDF：调号、拍号、速度、谱号（含 8vb）、起句音高一致
- [ ] **8vb：** MusicXML `<pitch>` 必须是发声音高（concert）
- [ ] `catalog.json` 有条目，`scoreKind: formal`
- [ ] `assets/scores/musicxml/` 与 `third_party/scores_musicxml/` 同 id 对齐
- [ ] 三项护栏均为 OK
- [ ] App 重启后橙线符头 = 听到的键/下落条

更多路径约定见 [`曲谱来源.md`](./曲谱来源.md)。状态索引见 [`omr_audit/PROOFREAD_STATUS.md`](./omr_audit/PROOFREAD_STATUS.md)。
