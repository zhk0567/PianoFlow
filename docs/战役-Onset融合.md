# 战役 D：Onset 融合（连击 / 同音再击）

> 续最优方案 §5 D  
> 开打：2026-09-20

## 目标

同音再击不必完全静音：HF-flux **onset** 触发时  
1. Pitch 层清除 `_emitted` → 再发 noteOn  
2. AttackLatch `releaseOnOnset` → 跟弹可再次记命中  

## 实现

| 端 | 内容 |
|----|------|
| Dart | `onset_flux.dart` + `PitchFrame.onset` + latch 释放 |
| Android | `OnsetFluxDetector` + Mic 清 emitted + latch |
| Web | `onset-flux.js` + `attackSpent` + onset 释放 |

## 验收

- [x] 单测：flux / cooldown / latch releaseOnOnset  
- [x] Android compile  
- [ ] 真机：同一键连击两下（无完全抬起静音）能推进两个同音时位  
- [ ] metrics 出现 `onsetRel=`  

## 非目标

- 不拧 quiet/hop/echoSuppress  
- 不做完整 aubio / FFT onset  
