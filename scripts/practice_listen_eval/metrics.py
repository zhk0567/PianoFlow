from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from .schema_util import LABELS


@dataclass
class NoteEvent:
    onset_ms: float
    midi: int
    label: str = "hit"
    chord: list[int] | None = None


@dataclass
class MetricBundle:
    onset_f1_50: float = 0.0
    onset_f1_100: float = 0.0
    outcome_macro_f1: float = 0.0
    false_advance_rate: float = 0.0
    stuck_rate: float = 0.0
    latency_p50_ms: float | None = None
    latency_p95_ms: float | None = None
    n_gold: int = 0
    n_pred: int = 0
    extras: dict = field(default_factory=dict)


def _match_onsets(
    gold: list[NoteEvent],
    pred: list[NoteEvent],
    tol_ms: float,
    *,
    require_pitch: bool = True,
) -> tuple[int, int, int]:
    """Greedy one-to-one matching. Returns tp, fp, fn."""
    used_p: set[int] = set()
    tp = 0
    for g in gold:
        if g.label == "miss":
            # miss has no audible onset in gold performance
            continue
        best_j = -1
        best_dt = tol_ms + 1
        for j, p in enumerate(pred):
            if j in used_p:
                continue
            dt = abs(p.onset_ms - g.onset_ms)
            if dt > tol_ms:
                continue
            if require_pitch and p.midi != g.midi:
                continue
            if dt < best_dt:
                best_dt = dt
                best_j = j
        if best_j >= 0:
            used_p.add(best_j)
            tp += 1
    audible_gold = sum(1 for g in gold if g.label != "miss")
    fp = len(pred) - len(used_p)
    fn = audible_gold - tp
    return tp, fp, fn


def f1_from_counts(tp: int, fp: int, fn: int) -> float:
    if tp == 0 and fp == 0 and fn == 0:
        return 1.0
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    if prec + rec == 0:
        return 0.0
    return 2 * prec * rec / (prec + rec)


def map_pred_outcomes(
    gold: list[NoteEvent],
    pred: list[NoteEvent],
    tol_ms: float = 100.0,
) -> list[str]:
    """Assign each gold event an observed outcome from predictions (for classification F1)."""
    used: set[int] = set()
    out: list[str] = []
    for g in gold:
        chord = set(g.chord or [g.midi])
        if g.label == "miss":
            # If something matched nearby wrong pitch → wrong; else miss observed
            hit_wrong = False
            for j, p in enumerate(pred):
                if j in used:
                    continue
                if abs(p.onset_ms - g.onset_ms) <= tol_ms and p.midi not in chord:
                    used.add(j)
                    hit_wrong = True
                    out.append("wrong")
                    break
            if not hit_wrong:
                out.append("miss")
            continue
        matched = False
        for j, p in enumerate(pred):
            if j in used:
                continue
            if abs(p.onset_ms - g.onset_ms) > tol_ms:
                continue
            if p.midi == g.midi or p.midi in chord:
                used.add(j)
                out.append("hit")
                matched = True
                break
            used.add(j)
            out.append("wrong")
            matched = True
            break
        if not matched:
            out.append("miss")
    # Remaining preds near no gold → extras counted in false_advance
    return out


def macro_f1(y_true: Iterable[str], y_pred: Iterable[str]) -> float:
    yt = list(y_true)
    yp = list(y_pred)
    if len(yt) != len(yp) or not yt:
        return 0.0
    scores = []
    for lab in LABELS:
        tp = sum(1 for a, b in zip(yt, yp) if a == lab and b == lab)
        fp = sum(1 for a, b in zip(yt, yp) if a != lab and b == lab)
        fn = sum(1 for a, b in zip(yt, yp) if a == lab and b != lab)
        scores.append(f1_from_counts(tp, fp, fn))
    return sum(scores) / len(scores)


def percentile(xs: list[float], p: float) -> float | None:
    if not xs:
        return None
    arr = sorted(xs)
    if len(arr) == 1:
        return float(arr[0])
    k = (len(arr) - 1) * (p / 100.0)
    f = int(k)
    c = min(f + 1, len(arr) - 1)
    return float(arr[f] + (arr[c] - arr[f]) * (k - f))


def evaluate_segment(
    gold: list[NoteEvent],
    pred: list[NoteEvent],
    *,
    latency_ms: list[float] | None = None,
) -> MetricBundle:
    tp50, fp50, fn50 = _match_onsets(gold, pred, 50.0)
    tp100, fp100, fn100 = _match_onsets(gold, pred, 100.0)
    observed = map_pred_outcomes(gold, pred, tol_ms=100.0)
    true_labels = [g.label for g in gold]
    # Pad/truncate observed to gold length (map_pred_outcomes already 1:1)
    outcome_f1 = macro_f1(true_labels, observed)

    audible = [g for g in gold if g.label != "miss"]
    stuck = 0
    for g in audible:
        if g.label != "hit":
            continue
        ok = any(
            abs(p.onset_ms - g.onset_ms) <= 100 and p.midi == g.midi for p in pred
        )
        if not ok:
            stuck += 1
    stuck_rate = stuck / max(1, sum(1 for g in gold if g.label == "hit"))

    # False advance: predictions that don't match any non-miss gold within 100ms
    matched_pred: set[int] = set()
    for g in gold:
        if g.label == "miss":
            continue
        for j, p in enumerate(pred):
            if j in matched_pred:
                continue
            if abs(p.onset_ms - g.onset_ms) <= 100 and (
                p.midi == g.midi or (g.chord and p.midi in g.chord)
            ):
                matched_pred.add(j)
                break
    false_adv = len(pred) - len(matched_pred)
    false_advance_rate = false_adv / max(1, len(pred))

    return MetricBundle(
        onset_f1_50=f1_from_counts(tp50, fp50, fn50),
        onset_f1_100=f1_from_counts(tp100, fp100, fn100),
        outcome_macro_f1=outcome_f1,
        false_advance_rate=false_advance_rate,
        stuck_rate=stuck_rate,
        latency_p50_ms=percentile(latency_ms or [], 50),
        latency_p95_ms=percentile(latency_ms or [], 95),
        n_gold=len(gold),
        n_pred=len(pred),
    )


def average_metrics(rows: list[MetricBundle]) -> MetricBundle:
    if not rows:
        return MetricBundle()

    def mean(attr: str) -> float:
        return sum(getattr(r, attr) for r in rows) / len(rows)

    lats50 = [r.latency_p50_ms for r in rows if r.latency_p50_ms is not None]
    lats95 = [r.latency_p95_ms for r in rows if r.latency_p95_ms is not None]
    return MetricBundle(
        onset_f1_50=mean("onset_f1_50"),
        onset_f1_100=mean("onset_f1_100"),
        outcome_macro_f1=mean("outcome_macro_f1"),
        false_advance_rate=mean("false_advance_rate"),
        stuck_rate=mean("stuck_rate"),
        latency_p50_ms=(sum(lats50) / len(lats50)) if lats50 else None,
        latency_p95_ms=(sum(lats95) / len(lats95)) if lats95 else None,
        n_gold=sum(r.n_gold for r in rows),
        n_pred=sum(r.n_pred for r in rows),
    )
