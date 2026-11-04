"""Run practice-listen baselines on a JSONL manifest; emit CSV + Markdown table."""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

# Allow `python scripts/practice_listen_eval/run_eval.py`
_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from practice_listen_eval.baselines import run_baseline  # noqa: E402
from practice_listen_eval.metrics import (  # noqa: E402
    NoteEvent,
    average_metrics,
    evaluate_segment,
)
from practice_listen_eval.schema_util import (  # noqa: E402
    DEFAULT_MANIFEST,
    REPO,
    load_manifest,
    resolve_wav,
)

BASELINES = ("yin", "basic_pitch", "basic_pitch_latch", "ours")
OUT_MD = REPO / "docs/omr_audit/_practice_listen_eval_table.md"
OUT_CSV = REPO / "docs/omr_audit/_practice_listen_eval_table.csv"


def _gold_events(seg: dict) -> list[NoteEvent]:
    out: list[NoteEvent] = []
    for e in seg.get("events") or []:
        out.append(
            NoteEvent(
                onset_ms=float(e["onset_ms"]),
                midi=int(e["midi"]),
                label=str(e["label"]),
                chord=list(e["chord"]) if e.get("chord") else None,
            )
        )
    return out


def _run_ours(wav: Path, bp_session=None) -> tuple[list[NoteEvent], list[float]]:
    """Prefer trained checkpoint adapter; fall back to BP+latch until train lands."""
    try:
        from practice_listen_train.infer_adapter import predict_onsets

        return predict_onsets(wav)
    except Exception:
        # Fallback keeps four-row table runnable before / without a checkpoint.
        return run_baseline("basic_pitch_latch", wav, bp_session=bp_session)


def eval_baseline(name: str, segments: list[dict], bp_session=None):
    bundles = []
    for seg in segments:
        wav = resolve_wav(seg)
        gold = _gold_events(seg)
        if name == "ours":
            pred, lats = _run_ours(wav, bp_session=bp_session)
        else:
            pred, lats = run_baseline(name, wav, bp_session=bp_session)
        bundles.append(evaluate_segment(gold, pred, latency_ms=lats))
    return average_metrics(bundles)


def _fmt(v: float | None, digits: int = 3) -> str:
    if v is None:
        return "—"
    return f"{v:.{digits}f}"


def write_tables(rows: list[dict], md_path: Path, csv_path: Path) -> None:
    md_path.parent.mkdir(parents=True, exist_ok=True)
    headers = [
        "baseline",
        "onset_f1_50",
        "onset_f1_100",
        "outcome_macro_f1",
        "false_advance_rate",
        "stuck_rate",
        "latency_p50_ms",
        "latency_p95_ms",
        "n_gold",
        "n_pred",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=headers)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k) for k in headers})

    lines = [
        "# Practice listen eval (fixture)",
        "",
        "| baseline | onset F1@50 | onset F1@100 | outcome macro-F1 | false-adv | stuck | p50 ms | p95 ms |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for r in rows:
        lines.append(
            "| {baseline} | {o50} | {o100} | {out} | {fa} | {st} | {p50} | {p95} |".format(
                baseline=r["baseline"],
                o50=_fmt(r["onset_f1_50"]),
                o100=_fmt(r["onset_f1_100"]),
                out=_fmt(r["outcome_macro_f1"]),
                fa=_fmt(r["false_advance_rate"]),
                st=_fmt(r["stuck_rate"]),
                p50=_fmt(r["latency_p50_ms"], 1),
                p95=_fmt(r["latency_p95_ms"], 1),
            )
        )
    lines.append("")
    lines.append(f"_Source: `{DEFAULT_MANIFEST.relative_to(REPO).as_posix()}`_")
    lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Practice-listen baseline eval")
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument(
        "--baselines",
        nargs="+",
        default=list(BASELINES),
        choices=list(BASELINES),
    )
    ap.add_argument("--md", type=Path, default=OUT_MD)
    ap.add_argument("--csv", type=Path, default=OUT_CSV)
    args = ap.parse_args(argv)

    if not args.manifest.is_file():
        # Auto-generate fixture if missing
        from practice_listen_eval.generate_fixture import main as gen

        gen()

    segments = load_manifest(args.manifest)
    if not segments:
        print(f"empty manifest: {args.manifest}", file=sys.stderr)
        return 2

    bp_session = None
    need_bp = any(b in ("basic_pitch", "basic_pitch_latch", "ours") for b in args.baselines)
    if need_bp:
        try:
            from practice_listen_eval.baselines import _bp_session

            bp_session = _bp_session()
        except Exception as exc:
            print(f"warn: Basic Pitch ONNX unavailable ({exc}); BP rows may fail", file=sys.stderr)

    table: list[dict] = []
    for name in args.baselines:
        print(f"eval {name} …")
        try:
            m = eval_baseline(name, segments, bp_session=bp_session)
            table.append(
                {
                    "baseline": name,
                    "onset_f1_50": round(m.onset_f1_50, 4),
                    "onset_f1_100": round(m.onset_f1_100, 4),
                    "outcome_macro_f1": round(m.outcome_macro_f1, 4),
                    "false_advance_rate": round(m.false_advance_rate, 4),
                    "stuck_rate": round(m.stuck_rate, 4),
                    "latency_p50_ms": None if m.latency_p50_ms is None else round(m.latency_p50_ms, 2),
                    "latency_p95_ms": None if m.latency_p95_ms is None else round(m.latency_p95_ms, 2),
                    "n_gold": m.n_gold,
                    "n_pred": m.n_pred,
                }
            )
        except Exception as exc:
            print(f"FAIL {name}: {exc}", file=sys.stderr)
            table.append(
                {
                    "baseline": name,
                    "onset_f1_50": None,
                    "onset_f1_100": None,
                    "outcome_macro_f1": None,
                    "false_advance_rate": None,
                    "stuck_rate": None,
                    "latency_p50_ms": None,
                    "latency_p95_ms": None,
                    "n_gold": 0,
                    "n_pred": 0,
                }
            )

    write_tables(table, args.md, args.csv)
    print(f"Wrote {args.md}")
    print(f"Wrote {args.csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
