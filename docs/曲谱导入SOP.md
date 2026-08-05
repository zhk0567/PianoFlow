# 曲谱导入 SOP（准确优先 + 批量要快）

## 一句话结论

**若你只有 PDF（本项目当前硬约束）**：走 **高精度 OMR → 对着 PDF 校对 → MusicXML 入库**，见 [`PDF识谱与FlowKey对齐.md`](./PDF识谱与FlowKey对齐.md)。  
**PDF 清晰 ≠ 能无损「提取」音符**——程序看到的是图画，OMR 是识图猜音；业界也做不到全自动 100%。  
若将来能拿到与 PDF **同版**的 MusicXML/MSCZ，仍是最快且最稳的 A 档路径（下方脚本）。

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

---

## 速度与准确度梯度（以后加曲按此选）

| 优先级 | 你提供什么 | 准确度 | 耗时 | 用法 |
|--------|------------|--------|------|------|
| **A（默认）** | 与 PDF **同版**的 `.musicxml` / `.mxl` / `.mscz` | 可与 PDF 逐音一致 | **约 10–30 秒** | `.\scripts\import-score.ps1` |
| **B** | 只有 PDF，但你能从 MuseScore / Mutopia / Cantorion 下到同版数字源 | 同 A | 下载几分钟 + A | 先存 `third_party\scores_pdf\` 对照，源文件走 A |
| **C** | 只有 PDF，无数字源 | 需 OMR + 校对后才可上架 | 数十分钟～数小时 | 工作目录 `_omr_work/`，校对通过后再走 A |
| **禁止** | 仅 MIDI / music21(MIDI) | 不够正式谱标准 | — | 不上架 formal |

**批量加曲的正确姿势：** 每首曲子入库前准备好 A 档源文件；转换本身已经很快。慢的是「找同版源」或「对着 PDF 手改 OMR」，不是 `musicxml_to_score.py`。

---

## 一键导入（A 档）

在仓库根目录：

```powershell
Set-Location F:\commercial\Piano

.\scripts\import-score.ps1 `
  -Id "some_piece_id" `
  -Source "C:\path\to\score.musicxml" `
  -Title "曲名" `
  -Artist "作曲家" `
  -Genre "Classical" `
  -Difficulty 3 `
  -Description "来源与版权说明"
```

也支持 `-Source` 为 `.mxl` 或 `.mscz`（若本机已装 MuseScore CLI，会自动导出 MusicXML；未安装则请先自行导出 `.musicxml`）。

可选：把参考 PDF 一并归档：

```powershell
.\scripts\import-score.ps1 -Id "..." -Source "..." -Pdf "C:\path\to\ref.pdf" ...
```

脚本会：

1. 复制/转换 MusicXML → `third_party\scores_musicxml\{id}.musicxml`
2. 同步 → `assets\scores\musicxml\{id}.musicxml`
3. 生成 → `assets\scores\{id}.json`
4. 更新 → `assets\scores\catalog.json`
5. 跑护栏：`catalog_score_kind_guard.py` + `catalog_integrity_guard.py`（失败则导入中止）

然后 **完全重启 App** 即可看到新曲。

---

## 入库护栏（每次导入 / 批量转换后必过）

```powershell
Set-Location F:\commercial\Piano

# scoreKind：OMR provenance 不得标 formal
python .\scripts\catalog_score_kind_guard.py

# catalog ↔ JSON bpm/id、asset 与 packaged MusicXML 必须存在
# （含 packaged ↔ third_party MusicXML sha256 一致）
python .\scripts\catalog_integrity_guard.py

# score_kind_policy.json ↔ Dart omrProvenanceIds 不得漂移
python .\scripts\score_kind_policy_sync.py --check
```

`convert-scores.ps1` / `import-score.ps1` / `omr-finish-import.ps1` 末尾会自动跑上述三项。
`convert-scores.ps1`（无 `-Id`）从 `catalog.json` 读全部 id 并逐首转换；缺 MusicXML 的跳过并提示。  
`python .\scripts\musicxml_to_score.py --all` 同样以 catalog 为准（含 OMR）。  
catalog `genre` 请用英文码：`Classical` / `Anime` / `Pop` / `Game`（UI 显示古典/动画/流行/游戏；护栏拒绝未知码）。  
重跑 `musicxml_to_score.py --update-catalog` 时：已有 catalog 的 `scoreKind`/描述会保留；MusicXML **无** `<sound tempo>` 时会保留已有 BPM（避免 OMR 默认 100 覆盖手调速度）。

---

## PDF 仅作对照（推荐习惯）

参考 PDF 放：

`third_party\scores_pdf\{id}.pdf`

与 MusicXML id 同名，便于以后校对。已有示例：

- `fur_elise_woo59.pdf`
- `pachelbel_canon_d.pdf`
- `megalovania.pdf`

---

## C 档：仅有 PDF 时

1. PDF 放入 `third_party\scores_musicxml\_omr_work\{name}\source.pdf`
2. 用 Audiveris / MuseScore 扫描等得到草稿 MusicXML
3. **在记谱软件中对照 PDF 改到满意**
4. 再执行 A 档 `import-score.ps1`

未校对的 OMR 结果 **不要**标为 `formal` 上架。若需先入库练手，catalog 标 `scoreKind: omrDraft`（UI：「OMR草稿」），校对通过后再改为 `formal`。

**审计（不升 formal）：**

```powershell
python .\scripts\omr_audit_score.py --id hisaishi_castle_in_the_sky
python .\scripts\omr_audit_score.py --all-omr
# CI / 导入门禁：JSON ≠ MusicXML 重解析则 exit 1（仍不会升 formal）
python .\scripts\omr_audit_score.py --all-omr --fail-on-drift
```

报告写在 `docs\omr_audit\`。脚本**永远不会**把曲目标成 formal。`omr-finish-import.ps1` 也固定导入为 `omrDraft`，并带 `--fail-on-drift`。

校对通过后升 formal（须人工确认 SOP 开/中/尾逐音）：

```powershell
python .\scripts\omr_promote_formal.py --id <score_id> --confirm-sop-passed
# 内部会：catalog→formal、从 score_kind_policy 移除 id、改写 Dart 镜像、跑护栏
```

每首进度见 `docs\omr_audit\PROOFREAD_STATUS.md` 与 `docs\omr_audit\<id>_SOP.md`。

**校对辅助脚本（均不自动升 formal）：**

```powershell
# PDF 首页预览 / 小节音高 dump
python .\scripts\omr_pdf_preview.py --id hisaishi_castle_in_the_sky --pages 2
python .\scripts\omr_dump_measures.py --id hisaishi_castle_in_the_sky --bars 8

# MusicXML 渲成 PNG，与 PDF 并排（需：npm i verovio @resvg/resvg-js）
node .\scripts\render_musicxml_png.js hisaishi_castle_in_the_sky 2
# 输出：docs\omr_audit\_render\{id}\mxml_p*.png
```

---

## 验收清单（每首正式曲）

- [ ] 谱源是 MusicXML/MSCZ，不是 MIDI
- [ ] 与参考 PDF：调号、拍号、速度、谱号（含 8vb）、起句音高一致
- [ ] **8vb / `clef-octave-change`：** MusicXML `<pitch>` 必须是**发声音高**（concert）。Verovio 用 octave-change 只负责把符头移到记谱位置；`musicxml_to_score.py` **不再**对 JSON 套用 octave-change。否则会出现「谱面看起来是 X、音频/琴键是 X±12」。
- [ ] `catalog.json` 有条目，`scoreKind: formal`
- [ ] `assets/scores/musicxml/` 与 `third_party/scores_musicxml/` 同 id 对齐
- [ ] `python .\scripts\catalog_score_kind_guard.py`、`catalog_integrity_guard.py`、`score_kind_policy_sync.py --check` 均为 OK
- [ ] App 完全重启后能打开；自动播放时橙色播放线下的符头与听到的键/下落条一致

更多路径约定见 `docs\曲谱来源.md`。
