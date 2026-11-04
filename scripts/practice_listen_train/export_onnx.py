"""Export practice-listen heads to ONNX (placeholder for engine experiment switch)."""
from __future__ import annotations

from pathlib import Path

import torch

from .model import PracticeListenHeads


def export_heads_onnx(
    model: PracticeListenHeads | None = None,
    out_path: Path | None = None,
) -> Path:
    model = model or PracticeListenHeads()
    model.eval()
    out_path = out_path or Path("practice_listen_heads.onnx")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    dummy = torch.zeros(1, 172, 88, dtype=torch.float32)

    class _Wrapper(torch.nn.Module):
        def __init__(self, m: PracticeListenHeads):
            super().__init__()
            self.m = m

        def forward(self, note_frames: torch.Tensor):
            o = self.m(note_frames)
            # Flatten outputs for ONNX: onset, pitch, outcome, guide
            return o["onset"], o["pitch"], o["chord_outcome"], o["guide_present"]

    wrapped = _Wrapper(model)
    wrapped.eval()
    # Prefer legacy exporter for stable placeholder artifact across torch versions.
    export_kwargs = dict(
        input_names=["note_frames"],
        output_names=["onset", "pitch", "chord_outcome", "guide_present"],
        dynamic_axes={
            "note_frames": {0: "batch", 1: "time"},
            "onset": {0: "batch", 1: "time"},
            "pitch": {0: "batch", 1: "time"},
            "chord_outcome": {0: "batch"},
            "guide_present": {0: "batch"},
        },
        opset_version=18,
    )
    try:
        torch.onnx.export(
            wrapped, dummy, str(out_path), dynamo=False, **export_kwargs
        )
    except TypeError:
        torch.onnx.export(wrapped, dummy, str(out_path), **export_kwargs)
    return out_path


if __name__ == "__main__":
    import sys

    _scripts = Path(__file__).resolve().parents[1]
    if str(_scripts) not in sys.path:
        sys.path.insert(0, str(_scripts))
    from practice_listen_eval.schema_util import REPO

    p = REPO / "artifacts" / "practice_listen" / "practice_listen_heads.onnx"
    export_heads_onnx(out_path=p)
    print(f"Wrote {p}")
