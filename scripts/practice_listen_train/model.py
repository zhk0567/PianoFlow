"""Multi-task heads on frozen Basic Pitch note frames."""
from __future__ import annotations

import torch
import torch.nn as nn


class PracticeListenHeads(nn.Module):
    """
    Input: BP note activation (T, 88) — treated as frozen features.
    Heads:
      - onset: per-frame onset logit (T, 1)  [pooled for loss]
      - pitch: per-frame pitch logits (T, 88) — auxiliary
      - chord_outcome: segment-level 4-way (hit/wrong/miss/extra)
      - guide_present: optional binary
    """

    def __init__(self, n_midi: int = 88, hidden: int = 64, n_outcome: int = 4):
        super().__init__()
        self.n_midi = n_midi
        self.shared = nn.Sequential(
            nn.Linear(n_midi, hidden),
            nn.ReLU(),
            nn.Linear(hidden, hidden),
            nn.ReLU(),
        )
        self.onset_head = nn.Linear(hidden, 1)
        self.pitch_head = nn.Linear(hidden, n_midi)
        self.outcome_fc = nn.Linear(hidden, n_outcome)
        self.guide_fc = nn.Linear(hidden, 1)

    def forward(self, note_frames: torch.Tensor) -> dict[str, torch.Tensor]:
        """
        note_frames: (B, T, 88)
        """
        h = self.shared(note_frames)  # (B, T, H)
        onset = self.onset_head(h).squeeze(-1)  # (B, T)
        pitch = self.pitch_head(h)  # (B, T, 88)
        # Pool over time for segment heads
        h_t = h.transpose(1, 2)  # (B, H, T)
        pooled = torch.mean(h_t, dim=-1)  # (B, H)
        outcome = self.outcome_fc(pooled)  # (B, 4)
        guide = self.guide_fc(pooled).squeeze(-1)  # (B,)
        return {
            "onset": onset,
            "pitch": pitch,
            "chord_outcome": outcome,
            "guide_present": guide,
        }


def multitask_loss(
    outs: dict[str, torch.Tensor],
    *,
    onset_tgt: torch.Tensor,
    pitch_tgt: torch.Tensor,
    outcome_tgt: torch.Tensor,
    guide_tgt: torch.Tensor,
    w_onset: float = 1.0,
    w_pitch: float = 0.3,
    w_outcome: float = 1.0,
    w_guide: float = 0.2,
) -> tuple[torch.Tensor, dict[str, float]]:
    bce = nn.BCEWithLogitsLoss()
    ce = nn.CrossEntropyLoss()
    # onset_tgt: (B, T) float 0/1
    # pitch_tgt: (B, T) long midi-bin or -100 ignore; use BCE on multi-hot soft
    loss_onset = bce(outs["onset"], onset_tgt)
    loss_pitch = bce(outs["pitch"], pitch_tgt)
    loss_outcome = ce(outs["chord_outcome"], outcome_tgt)
    loss_guide = bce(outs["guide_present"], guide_tgt)
    total = (
        w_onset * loss_onset
        + w_pitch * loss_pitch
        + w_outcome * loss_outcome
        + w_guide * loss_guide
    )
    parts = {
        "onset": float(loss_onset.detach()),
        "pitch": float(loss_pitch.detach()),
        "outcome": float(loss_outcome.detach()),
        "guide": float(loss_guide.detach()),
        "total": float(total.detach()),
    }
    return total, parts
