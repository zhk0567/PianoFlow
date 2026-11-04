# practice_listen_train

冻结 Basic Pitch note 帧特征 + 轻量多任务头（onset / pitch / chord_outcome / guide_present）。

```powershell
Set-Location F:\commercial\PianoFlow
$env:PYTHONPATH='scripts'
python scripts/practice_listen_train/train.py --epochs 5 --synthetic
python scripts/practice_listen_eval/run_eval.py
```

产物：`artifacts/practice_listen/practice_listen_heads.{pt,onnx}`。

**不改生产默认：** `PracticeEngine` / Android `BasicPitchEstimator` 仍为 Basic Pitch；实验开关后置，评测表 `ours` 行仅离线脚本使用。

**硬约束（实时×准确×抗干扰同时达标）：** 见 `docs/战役-练习态听音评测.md` §0。  
上线门槛：真机 capture→hit p50≤80ms / p95≤150ms；误推进/错漏多优于 `basic_pitch_latch`；**guide-on/off 分列**，示范 bleed 为第一干扰源。  
下一刀：流式因果特征 + `waiting_chord` + `guide_present`；规则门保留兜底；禁止 look-ahead / 瞎抬阈值冒充抗干扰。
