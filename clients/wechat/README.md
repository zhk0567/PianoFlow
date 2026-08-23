# PianoFlow 微信小程序（降级）

用**微信开发者工具**打开本目录（`project.config.json` 已含 touristappid，可本地预览）。

**收工标准**：`docs/四端收工验收勾选.md` → P4。

**能力**：
- 曲库：`data/catalog.json`（与契约样例 2 首对齐）
- 预渲染谱：`data/staff/*.json`（MusicXML 节选 → 可横滑音名谱）
- 简易练习：节拍器（BPM 可调 + 震动 + 闪烁）
- 诚实文案：完整跟弹引导至 Windows / Android

**明确不做**：完整 88 键瀑布、Verovio WASM、低延迟麦克风跟弹。

**无 GUI 校验**（PowerShell）：

```powershell
Set-Location F:\commercial\PianoFlow\clients\wechat
.\verify.ps1
```
