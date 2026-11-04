"""Minimal train loop for practice-listen multi-task heads."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import torch
from torch.utils.data import DataLoader

_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from practice_listen_eval.schema_util import REPO  # noqa: E402
from practice_listen_train.dataset import PracticeListenDataset  # noqa: E402
from practice_listen_train.export_onnx import export_heads_onnx  # noqa: E402
from practice_listen_train.model import PracticeListenHeads, multitask_loss  # noqa: E402

CKPT_DIR = REPO / "artifacts" / "practice_listen"
DEFAULT_MANIFEST = REPO / "testdata" / "practice_listen" / "manifest.jsonl"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=5)
    ap.add_argument("--batch-size", type=int, default=4)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--synthetic", action="store_true")
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--out-dir", type=Path, default=CKPT_DIR)
    args = ap.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    ds = PracticeListenDataset(
        None if args.synthetic else args.manifest,
        synthetic=args.synthetic or not args.manifest.is_file(),
        n_synthetic=24,
    )
    if len(ds) == 0:
        print("empty dataset", file=sys.stderr)
        return 2
    loader = DataLoader(ds, batch_size=min(args.batch_size, len(ds)), shuffle=True)

    model = PracticeListenHeads()
    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    history: list[dict] = []

    model.train()
    for epoch in range(args.epochs):
        totals = []
        for batch in loader:
            opt.zero_grad()
            outs = model(batch["feats"])
            loss, parts = multitask_loss(
                outs,
                onset_tgt=batch["onset"],
                pitch_tgt=batch["pitch"],
                outcome_tgt=batch["outcome"],
                guide_tgt=batch["guide"],
            )
            loss.backward()
            opt.step()
            totals.append(parts["total"])
        mean_loss = sum(totals) / max(1, len(totals))
        history.append({"epoch": epoch + 1, "loss": mean_loss})
        print(f"epoch {epoch + 1}/{args.epochs} loss={mean_loss:.4f}")

    ckpt_path = args.out_dir / "practice_listen_heads.pt"
    torch.save({"model": model.state_dict(), "history": history}, ckpt_path)
    onnx_path = args.out_dir / "practice_listen_heads.onnx"
    export_heads_onnx(model, onnx_path)
    meta = {
        "ckpt": str(ckpt_path.relative_to(REPO)).replace("\\", "/"),
        "onnx": str(onnx_path.relative_to(REPO)).replace("\\", "/"),
        "history": history,
        "note": "Frozen BP features + light heads; production engine remains Basic Pitch.",
    }
    (args.out_dir / "train_meta.json").write_text(
        json.dumps(meta, indent=2), encoding="utf-8"
    )
    print(f"Wrote {ckpt_path}")
    print(f"Wrote {onnx_path}")
    if len(history) >= 2 and history[-1]["loss"] < history[0]["loss"]:
        print("PASS: loss decreased")
    else:
        print("WARN: loss did not clearly decrease (still wrote checkpoint)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
