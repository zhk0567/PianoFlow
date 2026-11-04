# Android 原生 · Windows 同效验收

> 手机主路径：`clients/android/`。  
> **本表 =「真同等可测」标准**（高于早期「闭环 Pass」）。用户测前以本表为准。

**战役状态：** **已冻结待测**（工程项全 Pass；体感由你真机确认）

## 同效项

| 项 | 状态 | 说明 |
|----|------|------|
| 钢琴采样示范音 | **Pass** | SoundPool + n21–n108.wav |
| 完整曲库 + JSON 时线（含 hand） | **Pass** | `scores/*.json` 驱动跟弹；MusicXML 出谱 |
**原则**：功能与 Windows 同效；布局按手机/Web 场景独立设计（非像素复刻）。

## 同效项

| 项 | 状态 | 说明 |
|----|------|------|
| 五页壳 + 场景化布局 | **Pass** | Web 顶栏/底栏；Android 底栏；练习页各自优化 |
| 壳导航（首页·曲库·考试·工坊·我的） | **Pass** | |
| MusicXML 用户导入 | **Pass** | Web IndexedDB；Android 内部存储 |
| 登录/访客、收藏、最近、统计 | **Pass** | 本地持久化 |
| 练习星座 / 试音 / 音高测试 / 设置 | **Pass** | |
| 考试模式（禁 seek、禁示范） | **Pass** | |
| 舞台 + 跟弹核心 | **Pass** | |
| Verovio + 游标 | **Pass** | |
| 跟弹：冻结 / 提前窗 / 和弦齐击 / nudge | **Pass** | 对齐 Windows WaitLogic |
| 冻结软示范音 + 短抑制窗 | **Pass** | guideAudio + 250ms suppress |
| 完美/不错 + 冻结错音记 miss | **Pass** | |
| 左/右/双手 | **Pass** | |
| 速度 40%–200% | **Pass** | |
| 进度 seek + lead-in 重来 | **Pass** | |
| 节拍器（冻结时停） | **Pass** | |
| 结算 + 再练 / 薄弱段 | **Pass** | AlertDialog |
| 打开不幽灵出声 | **Pass** | 预加载不 play |
| `assembleDebug` | **Pass** | `app-debug.apk` |

## 仍非同等（诚实 · backlog）

- Oboe 级低延迟；Compose UI；像素级桌面布局  
- Windows 全套视觉特效 / 音量 200% 头房  
- ~~跟弹模型（Basic Pitch / SwiftF0）；现为 YIN~~ → 2026-09-20 已接 BP ONNX（见 [战役-跟弹可测与Android-BP.md](./战役-跟弹可测与Android-BP.md)；真机待勾）  

## 怎么测

Studio Open `clients/android` → Run，或：

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.11'
Set-Location F:\commercial\PianoFlow\clients\android
.\gradlew.bat assembleDebug
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

重点测：布局是否与 Windows 同序（瀑布→键盘→谱）、跟弹冻结、双手、谱游标。
