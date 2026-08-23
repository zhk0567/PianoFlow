# PianoFlow Web

**功能对齐 Windows · 布局按浏览器场景优化**（顶栏/底栏导航；练习页竖向舞台：瀑布+键盘在上、五线谱在下）。

## 打开

```powershell
Set-Location F:\commercial\PianoFlow\clients\web
.\serve.ps1
```

http://127.0.0.1:8765/ · Chrome/Edge · 勿用 `file://`

## 能力（P0/P1/P2）

- 首页 / 曲库 / 考试 / 工坊 / 我的
- MusicXML / MIDI / **音频草稿** 用户导入（IndexedDB；非正式谱）
- **PDF 暂存** + Windows OMR 指引（本机无 Audiveris）
- 登录访客、收藏、最近、练习统计、考试战绩
- 练习星座、试音、音高测试（Poly-YIN / 可选 Basic Pitch）
- 练习：自动/跟弹/考试、双手速度、冻结跟弹、结算薄弱段、音量
- **视觉特效**：命中环/光柱（设置可关）
- **考试 PCM**：勾选录制 → 结算「聆听录音」
- **跟弹**：Basic Pitch ONNX（有模型）→ Poly-YIN → YIN

### Basic Pitch 模型（可选）

将 `basic_pitch.onnx` 放到 `clients/web/models/`，或在仓库根目录运行：

```powershell
Set-Location F:\commercial\PianoFlow
.\scripts\sync-basic-pitch-model.ps1
```

无模型时自动使用 Poly-YIN/YIN，不影响跟弹主路径。

详见 `docs/三端功能契约.md`
