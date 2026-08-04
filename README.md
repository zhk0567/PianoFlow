# PianoFlow

Windows 上的互动练琴 App：对着屏幕跟弹，用麦克风听你弹得对不对。

本地优先，不绑课、不收费墙。原则：**谱面准确性 > 识别/跟弹体验 ≈ Flowkey > 可观测性 > 其它**。

## 能做什么

- **练习（跟弹）/ 自动播放**：下落音符对准琴键；可慢速、循环、单手练习
- **麦克风识音**：听你弹的音高（和弦也能听），驱动跟弹判定
- **五线谱**：练习页下方用 Verovio 显示标准谱面，跟弹时同步高亮
- **示范音、节拍器**：听示范、对拍子再练
- **曲库与进度**：收藏、最近练习、练习统计；也可游客一键进入

## 怎么打开用

1. 在资源管理器打开本仓库根目录  
2. **双击 `启动.bat`** → 清理残留后打开已编译程序（日常最快，**无 Dart 日志**）  
3. 若打不开或要看报错：双击 **`命令行启动.bat`**（默认 `flutter run`，黑窗口有 `[PianoFlow/` 前缀日志）

关掉 App 后，启动脚本一般会顺手清掉残留进程。

改过 Dart / Verovio 后请用 **`命令行启动.bat`**（或下面的 `run`），不要只用旧 exe。

## 首次准备

- **从没在这台电脑编过 Windows 版 Flutter？** 先跑一次 `scripts\安装Windows编译环境.bat`，再按提示装好 Flutter。  
- **麦克风**：系统设置里允许本 App 使用麦克风，否则识音不可用。  
- **缺模型 / 运行时 / 谱面引擎？** 别翻一堆脚本——缺什么就跑对应准备脚本（详情见下方文档）：
  - 音高模型 → 见 [麦克风怎么识音](docs/音高识别.md)
  - 五线谱（Verovio）→ 见 [五线谱怎么显示](docs/五线谱.md)
  - ONNX Runtime 等 → 同上两篇里的「准备」小节

日常练琴：有现成 exe 时，双击 `启动.bat` 即可，不必每次编译。

## 更多说明

| 想了解… | 看这里 |
|--------|--------|
| 产品做什么、不做什么 | [需求汇总](docs/需求汇总.md) |
| 麦克风怎么识音 | [音高识别](docs/音高识别.md) |
| 五线谱怎么显示 | [五线谱](docs/五线谱.md) |
| 曲谱从哪来、怎么同步 | [曲谱来源](docs/曲谱来源.md) |
| 目录与健康状况 | [健康检查](docs/健康检查.md) |
| 阶段排期备忘 | [开发计划](docs/开发计划.md) |

---

<details>
<summary>进阶 / 开发（命令行与构建）</summary>

```powershell
Set-Location F:\commercial\Piano

# 命令行启动（推荐排错）：默认 flutter run，可看到 Dart 日志
.\命令行启动.bat

# 只要旧 exe（快，无日志）
.\启动.bat
.\命令行启动.bat auto
# 或: .\scripts\run-console.ps1          # auto
#     .\scripts\run-console.ps1 run      # 完整 Dart 日志
#     .\scripts\run-console.ps1 build    # 先 build 再跑 exe

$env:PATH = "F:\Other\flutter\bin;" + $env:PATH
flutter pub get
flutter analyze
flutter test
flutter build windows --debug
```

曲谱转换、模型下载等脚本说明写在对应 `docs/` 文档里，这里不展开。

</details>
