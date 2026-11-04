# PianoFlow

**一条龙练琴体系**（本地优先）：多源进料（音频 / 曲库 / PDF 等）→ 自动成谱 → 跟弹练习 → 反馈再练。  
总纲（防忘本）：[docs/产品定位-一条龙体系.md](docs/产品定位-一条龙体系.md)。

现行练习页：对着屏幕跟弹，用麦克风听你弹得对不对；下落 + 88 键 + 五线谱。不绑课、不收费墙。  
工程取舍：谱面诚实标注 > 识别/跟弹体验 ≈ Flowkey > 可观测性 > 其它。

## 能做什么

- **练习（跟弹）/ 自动播放**：下落音符对准琴键；可慢速、循环、单手练习
- **麦克风识音**：Basic Pitch 多音为主、SwiftF0/YIN 兜底；抬高静音门限、压低亚谐波/低音幽灵，减少「没弹琴却亮键」
- **跟弹判定**：onset + carryover 收紧，降低误推进；延音线（tie）合并进练习 JSON
- **五线谱**：练习页下方用 Verovio 显示标准谱面，跟弹时同步高亮
- **示范音、节拍器**：听示范、对拍子再练
- **曲库与进度**：收藏、最近练习、练习统计；也可游客一键进入

## 曲库规模

内置曲目（`assets/scores/catalog.json`，截至 2026-11-04）：**69 首**  
其中正式谱 **12**、OMR 草稿 **55**、简化谱 **2**。用户自行导入不计入此数。

## 怎么打开用

1. 在资源管理器打开本仓库根目录  
2. **双击 `启动.bat`** → 清理残留后打开已编译程序（日常最快，**无 Dart 日志**）  
3. 若打不开或要看报错：双击 **`命令行启动.bat`**（默认 `flutter run`，黑窗口有 `[PianoFlow/` 前缀日志）

关掉 App 后，启动脚本一般会顺手清掉残留进程。  
改过 Dart / Verovio 后请用 **`命令行启动.bat`**（或下面的 `run`），不要只用旧 exe。

**四端：** Windows = 本仓库 Flutter EXE；**手机主路径 = [`clients/android`](clients/android/) 原生**（对齐 Windows 练习效果，见 [验收勾选](docs/Android原生对齐Windows-验收勾选.md)）；Web / 微信见 `clients/`。  
**不要**用仓库根 Flutter APK 冒充手机主交付。

## 首次准备

- **从没在这台电脑编过 Windows 版 Flutter？** 先跑一次 `scripts\安装Windows编译环境.bat`，再按提示装好 Flutter。  
- **麦克风**：系统设置里允许本 App 使用麦克风，否则识音不可用。  
- **缺模型 / 运行时 / 谱面引擎？**
  - 音高模型 → [麦克风怎么识音](docs/音高识别.md)
  - 五线谱（Verovio）→ [五线谱怎么显示](docs/五线谱.md)

日常练琴：有现成 exe 时，双击 `启动.bat` 即可。

## 更多说明

| 想了解… | 看这里 |
|--------|--------|
| **产品总身份（一条龙）** | [产品定位-一条龙体系](docs/产品定位-一条龙体系.md) |
| **前沿 idea** | [前沿Idea-本地实时一条龙](docs/前沿Idea-本地实时一条龙.md) |
| 现行功能 | [需求汇总](docs/需求汇总.md) |
| 四端冻结验收 | [四端收工验收勾选](docs/四端收工验收勾选.md) |
| **手机原生对齐 Windows** | [Android原生对齐Windows-验收勾选](docs/Android原生对齐Windows-验收勾选.md) |
| Web 对齐 Windows | [`clients/web`](clients/web/) · `.\serve.ps1` → http://127.0.0.1:8765/（布局同 Windows：瀑布→键盘→谱） |
| 冻结后「可更好」 | [战役外-backlog](docs/战役外-backlog.md) |
| 麦克风怎么识音 | [音高识别](docs/音高识别.md) |
| **练习态听音评测（基线 / SLO）** | [战役-练习态听音评测](docs/战役-练习态听音评测.md) |
| 五线谱怎么显示 | [五线谱](docs/五线谱.md) |
| 曲谱从哪来、怎么同步 | [曲谱来源](docs/曲谱来源.md) · [曲谱导入SOP](docs/曲谱导入SOP.md) |
| 变更流水 | [进化日志](docs/进化日志.md) |

---

<details>
<summary>进阶 / 开发（命令行与构建）</summary>

```powershell
Set-Location F:\commercial\PianoFlow

.\命令行启动.bat
.\启动.bat
.\命令行启动.bat auto

$env:PATH = "F:\Other\flutter\bin;" + $env:PATH
flutter pub get
flutter analyze
flutter test
flutter build windows --debug
```

练习态听音离线评测骨架：`scripts/practice_listen_eval/`（见战役文档）。  
曲谱转换、模型下载等见对应 `docs/`。

</details>
