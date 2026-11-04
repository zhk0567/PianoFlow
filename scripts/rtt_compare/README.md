# rtt 对照评测（战役 F）

离线对照 **huispaty/rtt**（ISMIR 2025，因果 &lt;30ms 钢琴转录基线）与 PianoFlow 现用 **Basic Pitch 流式**。

**纪律：不默认替换主引擎；无数据不换代。**

## 克隆与依赖（可选）

```powershell
# 建议放在仓库外，避免把 ~68MB ckpt 与 torch 堆进 PianoFlow
cd ..
git clone https://github.com/huispaty/rtt.git
cd rtt
# conda create -n rtt python=3.10 && conda activate rtt
pip install -r requirements.txt
```

官方推理入口面向 **MAESTRO v3** 全量评测：

```text
python src/inference.py path/to/maestro-v3
```

论文 / 仓库：https://arxiv.org/abs/2509.07586 · https://github.com/huispaty/rtt

## PianoFlow 脚手架

仓库根目录：

```powershell
# 仅 BP 流式（合成谐波爆发，烟测）
python .\scripts\compare_amt_latency.py --self-check --out .\tmp\amt_compare_self.json

# 真实 clip + 标注
python .\scripts\compare_amt_latency.py --wav clip.wav --gt clip.gt.json --out .\tmp\amt_compare.json

# 若已克隆 rtt
python .\scripts\compare_amt_latency.py --wav clip.wav --gt clip.gt.json --rtt-root ..\rtt --out .\tmp\amt_compare.json
```

Ground-truth JSON：

```json
{"onsets": [{"t": 0.50, "midi": 60}, {"t": 1.00, "midi": 64}]}
```

指标：`note-on F` @ 30/50/100ms；匹配对的 `lag_p50/p95`（est−ref）；推理墙钟。

单测（不强制 rtt）：

```powershell
python -m unittest scripts.test_compare_amt_latency -v
```

## 换代闸门（须全部满足再议）

1. 同批钢琴录音上 rtt 的 note-on F@50ms ≥ Basic Pitch 流式  
2. rtt `lag_p95` 明显更低，且存在可接受的 **ONNX / 端侧**路径（体积、CPU、冷启动）  
3. 不破坏 Wait / soft-cue / CueBleed 产品路径（跟弹体感回归）

任一不满足 → 继续 BP + A–E 门闩体系。
