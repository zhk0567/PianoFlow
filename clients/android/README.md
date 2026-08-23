# PianoFlow Android（原生 · 手机主路径）

**效果目标：对齐 Windows 练习页**（钢琴采样、完整曲库、瀑布+88键、Verovio、跟弹）。  
验收：[`docs/Android原生对齐Windows-验收勾选.md`](../../docs/Android原生对齐Windows-验收勾选.md)。

> **不要**用仓库根 Flutter APK 当本战役交付。本目录才是手机主战场。

## 构建 / 安装

Android Studio：**Open** → `F:\commercial\PianoFlow\clients\android` → 选设备 Run。

或 PowerShell：

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.11'
Set-Location F:\commercial\PianoFlow\clients\android
# 同步 Windows 同款曲库/采样/Verovio（若尚未 sync）
..\..\scripts\sync-android-native-assets.ps1
.\gradlew.bat assembleDebug
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

## 能力（对齐后）

- 完整曲库（`assets/scores/catalog.json`）+ 诚实质量档
- 自动：钢琴采样示范音 + 瀑布 + 88 键（可横滑跟焦）
- 跟弹：麦克风中文权限提示 + YIN 推进
- Verovio WASM 五线谱 + 游标

## 与 P1 的关系

四端战役 P1 已用 Views 达标收工；本战役在其上把**听感/曲库/舞台**拉到 Windows 同级。
