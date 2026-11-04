# 战役 F：rtt 低延迟对照评测

> 续最优方案 §5 F / §3.5  
> 开打：2026-09-20  
> **纪律**：对照实验；**不**默认替换 Basic Pitch；不拧 `quiet` / `hop` / `echoSuppress`

## 目标

用可复现的离线脚手架，把 **huispaty/rtt**（ISMIR 2025，因果实时钢琴转录基线）与当前 **Basic Pitch 流式**（hop≈30ms、tail=4）放在同一批 onset 标注上比：

- note-on F @ 30 / 50 / 100 ms  
- 匹配对的检测滞后 p50 / p95  
- 推理墙钟（仅供参考，非端侧 SLO）

有数据后再议「要不要换主引擎」；没有数据 → 不换。

## 非目标

- 把 rtt / PyTorch / 68MB ckpt 打进 App  
- 改跟弹门闩或冻结常量  
- 用论文 MAESTRO F1 直接当产品验收

## 落地

| 项 | 路径 |
|----|------|
| 对照脚本 | `scripts/compare_amt_latency.py` |
| 单测 | `scripts/test_compare_amt_latency.py` |
| rtt 克隆说明 | `scripts/rtt_compare/README.md` |

```powershell
python .\scripts\compare_amt_latency.py --self-check
python -m unittest scripts.test_compare_amt_latency -v
```

可选：`--rtt-root <huispaty/rtt checkout>`（需按其 `requirements.txt` 装好依赖）。

## 验收

- [x] BP 流式离线 onset + F / lag 报告（`amt_compare.v1` JSON）  
- [x] 匹配逻辑单测 +（有 onnx 时）self-check smoke  
- [x] rtt 接线为可选；缺依赖时 skip 并写明  
- [x] 文档写清换代闸门  
- [ ] 用户自备钢琴 clip + gt 或 MAESTRO 子集跑出对照表后再议换代  

## 换代闸门

见 `scripts/rtt_compare/README.md`：F@50ms、lag_p95、端侧可行性、产品路径无回归。
