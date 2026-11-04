# 战役：Score-conditioned 解码 + 三端收紧

> 续 [战役-跟弹可测与Android-BP.md](./战役-跟弹可测与Android-BP.md)  
> 对应最优方案 **C**（及 Android 仪表 / Web BP）  
> 开打：2026-09-20

## 目标

1. **期望音条件化**：BP 对 `waitingFor` 邻域 bin 加权；匹配层丢掉谱外杂音  
2. **收紧全局 ±1**：仅**单音等待**允许 soft ±1；**和弦要求 exact / 八度**  
3. Android 仪表 schema 对齐 Windows；Web 跟弹用同一匹配策略  

## 验收勾选

- [x] `PracticePitchMatch`：`conditionHeard` / `priorBins` / soft 仅 monophonic  
- [x] `BasicPitchEstimator.selectNotes(priorMidis)` 加权  
- [x] Windows `PitchService.setScorePriorMidis` + engine 接线  
- [x] Android `PitchMatch` + prior + `PracticeHitLatency`  
- [x] Web `pitch-match.js` + prior + `matchNoteOn`  
- [x] Dart 单测通过（含「和弦 ±1 不命中」）  
- [x] Android compile + unit test  
- [ ] 真机：单音仍可 ±1 容错；和弦弹邻音不应推进  

## 策略摘要

| waiting 规模 | ±1 soft | 八度 fold |
|--------------|-----------|-----------|
| 1（单音） | 允许 | 允许 |
| ≥2（和弦） | **禁止** | 允许（H2） |
