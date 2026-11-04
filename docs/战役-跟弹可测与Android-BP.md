# 战役：跟弹可测 + Android Basic Pitch 对齐

> 用户点名「开始执行」最优技术方案 A+B。  
> 开打：2026-09-20  
> 对应：[音高识别-最优技术方案.md](./音高识别-最优技术方案.md) §5 A/B

## 目标

1. **A 可测**：跟弹 p50/p95、miss / latchBlock / softMatch / leak、有无 guide 分桶  
2. **B 三端听音对齐**：Android 主引擎 Basic Pitch ONNX + noteOn 边沿 + Gate/Latch（对齐 Windows 语义）

## 非目标（本战役不做）

- 拧 `quiet` / `hop` / `echoSuppress` 常量  
- Score-conditioned 解码（战役 C）  
- 替换为 rtt / Transkun  
- MIDI 主路径  

## 验收勾选

### A · Windows 仪表

- [x] `PracticeHitLatency`：p50/p95、guide 分桶、计数器、`snapshotLine`
- [x] `_registerWaitHit` / miss / latch / softMatch 打点
- [x] 会话 flush 打 `[PianoFlow/Practice] metrics …`
- [x] `flutter test test/practice_hit_latency_test.dart` 通过
- [ ] 真机跟弹一眼能在 log 看到 metrics（人工）

### B · Android BP

- [x] `onnxruntime-android:1.22.0` 依赖
- [x] `assets/models/basic_pitch.onnx` 经 `sync-basic-pitch-model` / preBuild 同步
- [x] `BasicPitchEstimator` + `BasicPitchSelect`（与 Dart 同阈值/八度恢复）
- [x] `MicPitchTracker`：22.05k 环、~30ms hop、BP→Poly-YIN/YIN
- [x] `PitchEdgeTracker` noteOn；`GuideRetriggerGate` + `PracticeAttackLatch`
- [x] `PracticeController` noteOn/frame 双路径
- [x] PitchTest 显示引擎名
- [x] `:app:compileDebugKotlin` + unit test 通过
- [ ] 真机 PitchTest 显示「Basic Pitch（多音）」
- [ ] 真机跟弹：开 soft cue 不明显乱推；和弦可推进

## 关键路径

| 端 | 路径 |
|----|------|
| Dart 仪表 | `lib/features/practice/practice_hit_latency.dart` |
| Dart 接线 | `lib/features/practice/practice_engine.dart` |
| Android BP | `clients/android/.../BasicPitchEstimator.kt` 等 |
| Android 跟弹 | `clients/android/.../PracticeController.kt` |
| 同步 | `scripts/sync-basic-pitch-model.ps1`（已挂入 android asset sync） |

## 备注

- leak：会话结束时若冻结 ≥5s 且 waiting 未清，记 1（启发式）  
- Android 尚无完整 Dart 级 `PracticeHitLatency` 对象；已有 `hit-capture-ms` 日志，后续可再对齐仪表 schema  
