# -*- coding: utf-8 -*-
"""Offline follow-mode replay (no phone, no room).

Renders MusyngKite piano one-shots into five labeled scenes, runs the same
Basic Pitch ONNX post-process as the app (hop ~30ms, tail=4, score prior),
then a compact port of lock + onset + Wait / latch / cue-bleed.

Does **not** retune quiet / hop / echoSuppress*. Prints miss / false-advance /
lag so the next product edit can name a failing scene.

Usage (repo root):
  python .\\scripts\\replay_follow_bench.py
  python .\\scripts\\replay_follow_bench.py --out .\\tmp\\replay_follow.json
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import wave
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets" / "models" / "basic_pitch.onnx"
PIANO_DIRS = [
    ROOT / "assets" / "audio" / "piano",
    ROOT / "clients" / "android" / "app" / "src" / "main" / "assets" / "audio" / "piano",
]

SR44 = 44100
SR22 = 22050
HOP44 = 1323  # ~30ms
WIN44 = 11025  # 0.25s
AUDIO_N = 43844
NOTE_OUT = "StatefulPartitionedCall:1"
INPUT_NAME = "serving_default_input_2:0"
MIDI_OFFSET = 21
FRAME_THRESH = 0.42
RELATIVE_THRESH = 0.60
PRIOR_BOOST = 1.35
TAIL = 4
LOCK_FRAMES = 2
RELEASE_FRAMES = 2
RMS_GATE = 0.005
ECHO_GUIDE_SEC = 0.250
CUE_GAIN = 0.22
SOFT_TAIL_SEC = 0.180
BLEED_GRACE_SEC = 0.050
NOTE_SEC = 0.42
PARTIALS = (12, 19, 24, 28, 31, 36)
BASS_CEILING = 48


def _log(msg: str) -> None:
    print(f"[PianoFlow/replay] {msg}", file=sys.stderr, flush=True)


def piano_dir() -> Path:
    for d in PIANO_DIRS:
        if (d / "n60.wav").is_file():
            return d
    raise FileNotFoundError("piano one-shots missing (n60.wav)")


def read_wav_mono(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        ch = w.getnchannels()
        sr = w.getframerate()
        width = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width != 2:
        raise ValueError(f"{path} width {width}")
    samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    if ch == 2:
        samples = samples.reshape(-1, 2).mean(axis=1)
    return samples, sr


def resample_linear(audio: np.ndarray, src_sr: int, dst_sr: int) -> np.ndarray:
    if src_sr == dst_sr or len(audio) == 0:
        return audio.astype(np.float32)
    n2 = max(1, int(round(len(audio) * dst_sr / src_sr)))
    x = np.linspace(0, 1, num=len(audio), endpoint=False)
    return np.interp(np.linspace(0, 1, num=n2, endpoint=False), x, audio).astype(
        np.float32
    )


_NOTE_CACHE: dict[int, np.ndarray] = {}


def note_44(midi: int) -> np.ndarray:
    """Peak-normalized one-shot at 44.1k (mic-level stand-in, not raw quiet MP3)."""
    if midi in _NOTE_CACHE:
        return _NOTE_CACHE[midi]
    path = piano_dir() / f"n{midi}.wav"
    if not path.is_file():
        raise FileNotFoundError(path)
    audio, sr = read_wav_mono(path)
    audio = resample_linear(audio, sr, SR44)
    peak = float(np.max(np.abs(audio))) + 1e-9
    audio = (audio / peak * 0.72).astype(np.float32)
    _NOTE_CACHE[midi] = audio
    return audio


def mix_note(buf: np.ndarray, midi: int, t0: float, gain: float) -> None:
    src = note_44(midi)
    n = min(len(src), int(NOTE_SEC * SR44))
    i0 = int(round(t0 * SR44))
    i1 = min(len(buf), i0 + n)
    if i1 <= i0:
        return
    seg = src[: i1 - i0] * gain
    fade = min(int(0.04 * SR44), len(seg) // 3)
    if fade > 1:
        seg = seg.copy()
        seg[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
    buf[i0:i1] += seg


# ---- live BP select (port of basic_pitch.dart) ---------------------------


def select_notes(
    scores: np.ndarray,
    *,
    frame_thresh: float = FRAME_THRESH,
    relative_thresh: float = RELATIVE_THRESH,
    prior_midis: set[int] | None = None,
    prior_boost: float = PRIOR_BOOST,
) -> set[int]:
    work = np.array(scores, dtype=np.float64, copy=True)
    if prior_midis and prior_boost > 1.0:
        for m in prior_midis:
            b = m - MIDI_OFFSET
            if 0 <= b < len(work):
                work[b] = min(1.0, work[b] * prior_boost)
    peak = float(work.max()) if len(work) else 0.0
    if peak < frame_thresh * 0.85:
        return set()
    floor = max(frame_thresh, peak * relative_thresh)
    bass_floor = max(frame_thresh * 0.55, peak * relative_thresh * 0.65)
    candidates: list[tuple[int, float]] = []
    n = min(88, len(work))
    for b in range(n):
        s = float(work[b])
        midi = MIDI_OFFSET + b
        if midi < 21 or midi > 108:
            continue
        bin_floor = bass_floor if midi <= BASS_CEILING else floor
        if s < bin_floor:
            continue
        candidates.append((midi, s))
    if not candidates:
        return set()
    candidates.sort(key=lambda c: -c[1])
    kept: list[tuple[int, float]] = []
    for c in candidates:
        if _is_partial_ghost(c, kept):
            continue
        if _is_neighbor_bleed(c, kept):
            continue
        kept.append(c)
        if len(kept) >= 6:
            break
    midis = {m for m, _ in kept}
    for m in sorted(midis):
        if (m + 12) in midis:
            low = next(s for mm, s in kept if mm == m)
            high = next(s for mm, s in kept if mm == m + 12)
            if high < frame_thresh and high <= low * 1.25:
                midis.discard(m + 12)
    return _recover_bass(work, midis, frame_thresh)


def _score_at(scores: np.ndarray, midi: int) -> float:
    b = midi - MIDI_OFFSET
    if b < 0 or b >= len(scores):
        return 0.0
    return float(scores[b])


def _is_partial_ghost(c: tuple[int, float], kept: list[tuple[int, float]]) -> bool:
    for k_midi, k_score in kept:
        interval = c[0] - k_midi
        if interval <= 0 or interval not in PARTIALS:
            continue
        if (
            interval == 12
            and k_midi <= BASS_CEILING
            and c[1] >= 0.42
            and k_score >= 0.42 * 0.85
        ):
            continue
        margin = 1.15 if k_midi <= BASS_CEILING else 1.35
        if c[1] < k_score * margin:
            return True
    return False


def _is_neighbor_bleed(c: tuple[int, float], kept: list[tuple[int, float]]) -> bool:
    for k_midi, k_score in kept:
        if abs(c[0] - k_midi) != 1:
            continue
        if c[1] < k_score * 0.88:
            return True
    return False


def _recover_bass(scores: np.ndarray, selected: set[int], frame_thresh: float) -> set[int]:
    if not selected:
        return selected
    out: set[int] = set()
    for m in selected:
        low = m - 12
        if (
            m <= BASS_CEILING
            or m > BASS_CEILING + 12
            or low < 21
            or low > BASS_CEILING
        ):
            out.add(m)
            continue
        ls = _score_at(scores, low)
        hs = _score_at(scores, m)
        if ls < 0.18 or hs > ls * 2.8:
            out.add(m)
            continue
        out.add(low)
        both = hs >= frame_thresh and ls >= frame_thresh * 0.85 and hs >= ls * 0.8
        if both:
            out.add(m)
    return out


def prior_bins(waiting: set[int]) -> set[int]:
    out: set[int] = set()
    for m in waiting:
        for x in (m - 12, m - 1, m, m + 1, m + 12):
            if 21 <= x <= 108:
                out.add(x)
    return out


def is_near(a: int, b: int) -> bool:
    return abs(a - b) <= 1


def is_octave(a: int, b: int) -> bool:
    return abs(a - b) == 12


def soft_allowed(waiting: set[int]) -> bool:
    return len(waiting) <= 1


def match_waiting(heard: set[int], waiting: set[int]) -> set[int]:
    """Port of PracticePitchMatch.matchWaiting (exact, optional ±1, octave)."""
    if not heard or not waiting:
        return set()
    soft = soft_allowed(waiting)
    conditioned: set[int] = set()
    for h in heard:
        for e in waiting:
            if h == e or is_octave(e, h) or (soft and is_near(e, h)):
                conditioned.add(h)
                break
    if not conditioned:
        return set()
    remaining = set(waiting)
    hits: set[int] = set()
    used: set[int] = set()
    for h in list(conditioned):
        if h in remaining:
            remaining.remove(h)
            hits.add(h)
            used.add(h)
    if soft:
        for h in conditioned:
            if h in used:
                continue
            best = None
            best_d = 2
            for e in remaining:
                d = abs(e - h)
                if d == 0 or d > 1:
                    continue
                if d < best_d or (d == best_d and (best is None or e < best)):
                    best = e
                    best_d = d
            if best is not None:
                remaining.remove(best)
                hits.add(best)
                used.add(h)
    for h in conditioned:
        if h in used or h in waiting:
            continue
        best = None
        for e in remaining:
            if not is_octave(e, h):
                continue
            if best is None or e < best:
                best = e
        if best is None:
            continue
        remaining.remove(best)
        hits.add(best)
        used.add(h)
    return hits


def match_note_on(midi: int, waiting: set[int]) -> int | None:
    if not waiting:
        return None
    if midi in waiting:
        return midi
    hits = match_waiting({midi}, waiting)
    return next(iter(hits)) if hits else None


# ---- onset / lock / bleed / latch (compact ports) ------------------------


class OnsetFlux:
    def __init__(self) -> None:
        self.prev = 0.0
        self.cool = 0
        self.last = 0.0

    def push(self, samples: np.ndarray) -> bool:
        if len(samples) < 64:
            self.last = 0.0
            return False
        if self.cool > 0:
            self.cool -= 1
            hf = high_freq(samples)
            self.prev = self.prev * 0.65 + hf * 0.35
            self.last = 0.0
            return False
        hf = high_freq(samples)
        rms = float(np.sqrt(np.mean(np.square(samples)))) if len(samples) else 0.0
        flux = max(0.0, hf - self.prev)
        self.last = flux
        rising = hf >= 0.028 if self.prev <= 1e-6 else hf >= self.prev * 1.55
        onset = rms >= 0.008 and flux >= 0.028 and rising
        self.prev = self.prev * 0.55 + hf * 0.45
        if onset:
            self.cool = 3
        return onset


def high_freq(samples: np.ndarray) -> float:
    if len(samples) < 2:
        return 0.0
    d = np.diff(samples.astype(np.float64))
    return float(np.sqrt(np.mean(d * d)))


class AttackLatch:
    def __init__(self) -> None:
        self.spent: set[int] = set()
        self.quiet: dict[int, int] = {}

    def clear(self) -> None:
        self.spent.clear()
        self.quiet.clear()

    def mark(self, waiting_midi: int, heard: int) -> None:
        # Roots only. blocks() applies ±1 and exact ±12 — same as Dart latch.
        for m in (waiting_midi, heard):
            if 21 <= m <= 108:
                self.spent.add(m)
                self.quiet[m] = 0

    def blocks(self, midi: int) -> bool:
        return any(is_near(s, midi) or is_octave(s, midi) for s in self.spent)

    def _still(self, spent_midi: int, heard: set[int]) -> bool:
        return any(
            h == spent_midi or is_octave(spent_midi, h) or is_near(spent_midi, h)
            for h in heard
        )

    def on_heard(self, heard: set[int]) -> None:
        for m in list(self.spent):
            if self._still(m, heard):
                self.quiet[m] = 0
                continue
            n = self.quiet.get(m, 0) + 1
            if n >= RELEASE_FRAMES:
                self.spent.discard(m)
                self.quiet.pop(m, None)
            else:
                self.quiet[m] = n

    def release_on_onset(self, heard: set[int]) -> bool:
        before = len(self.spent)
        for m in list(self.spent):
            if self._still(m, heard):
                self.spent.discard(m)
                self.quiet.pop(m, None)
        return len(self.spent) < before


class CueBleed:
    def __init__(self) -> None:
        self.cued: set[int] = set()
        self.cue_at: float | None = None

    def arm(self, midis: set[int], t: float) -> None:
        self.cued = set(midis)
        self.cue_at = t

    def clear(self) -> None:
        self.cued = set()
        self.cue_at = None

    def _near_cue(self, midi: int) -> bool:
        return any(is_near(c, midi) or is_octave(c, midi) for c in self.cued)

    def is_bleed(self, midi: int, has_onset: bool, heard_all: set[int], now: float) -> bool:
        if self.cue_at is None or not self.cued:
            return False
        if not self._near_cue(midi):
            return False
        if has_onset:
            return False
        hard_end = self.cue_at + ECHO_GUIDE_SEC
        soft_end = hard_end + SOFT_TAIL_SEC
        if now < hard_end:
            return True
        if now < soft_end:
            if now - hard_end < BLEED_GRACE_SEC:
                return False
            if not heard_all:
                return True
            return all(self._near_cue(h) for h in heard_all)
        return False


class GuideGate:
    def __init__(self) -> None:
        self.awaiting: set[int] = set()
        self.gap_seen: set[int] = set()
        self.quiet: dict[int, int] = {}

    def arm(self, midis: set[int]) -> None:
        for m in midis:
            self.awaiting.add(m)
            self.gap_seen.discard(m)
            self.quiet[m] = 0

    def disarm(self, midis: set[int]) -> None:
        for m in midis:
            self.awaiting.discard(m)
            self.gap_seen.discard(m)
            self.quiet.pop(m, None)

    def clear(self) -> None:
        self.awaiting.clear()
        self.gap_seen.clear()
        self.quiet.clear()

    def accept(self, heard: set[int], waiting: set[int], suppressed: set[int]) -> set[int]:
        for m in list(self.awaiting):
            if any(is_near(m, s) for s in suppressed):
                self.quiet[m] = 0
                continue
            hearing = any(h == m or is_octave(m, h) or is_near(m, h) for h in heard)
            if not hearing:
                n = self.quiet.get(m, 0) + 1
                self.quiet[m] = n
                if n >= 2:
                    self.gap_seen.add(m)
            elif m not in self.gap_seen:
                self.quiet[m] = 0
        matched = match_waiting(heard, waiting)
        hits: set[int] = set()
        for m in matched:
            if m in self.awaiting and m in self.gap_seen:
                self.disarm({m})
                hits.add(m)
        return hits


class LockState:
    def __init__(self) -> None:
        self.locked: set[int] = set()
        self.hit: dict[int, int] = {}
        self.miss: dict[int, int] = {}
        self.emitted: set[int] = set()

    def update(self, raw: set[int], above: bool) -> list[tuple[int, bool]]:
        """Return new noteOn (midi, onset_flag filled by caller)."""
        if not above:
            self.hit.clear()
            for m in list(self.locked):
                self.miss[m] = self.miss.get(m, 0) + 1
                if self.miss[m] >= RELEASE_FRAMES:
                    self.locked.discard(m)
                    self.miss.pop(m, None)
        else:
            for m in raw:
                self.hit[m] = self.hit.get(m, 0) + 1
                self.miss.pop(m, None)
                if self.hit[m] >= LOCK_FRAMES:
                    self.locked.add(m)
            for m in list(self.locked):
                if m in raw:
                    continue
                self.miss[m] = self.miss.get(m, 0) + 1
                self.hit.pop(m, None)
                if self.miss[m] >= RELEASE_FRAMES:
                    self.locked.discard(m)
                    self.miss.pop(m, None)
            self.hit = {
                m: c
                for m, c in self.hit.items()
                if m in raw or m in self.locked
            }
        return list(self.locked)


# ---- scenes ---------------------------------------------------------------


@dataclass
class Chord:
    t: float
    midis: tuple[int, ...]


@dataclass
class Scene:
    name: str
    user: list[Chord]
    cues: list[Chord] = field(default_factory=list)
    wait_forever: tuple[int, ...] = ()
    pad: float = 1.15

    def duration(self) -> float:
        times = [c.t for c in self.user] + [c.t for c in self.cues]
        return (max(times) if times else 0.4) + self.pad


def default_scenes() -> list[Scene]:
    return [
        Scene(
            "melody",
            [Chord(0.50, (60,)), Chord(1.20, (64,)), Chord(1.90, (67,)),
             Chord(2.60, (72,)), Chord(3.30, (69,))],
        ),
        Scene(
            "chord4",
            [Chord(0.55, (60, 64, 67, 71)), Chord(1.90, (62, 66, 69, 73))],
        ),
        Scene(
            "restrike",
            [Chord(0.50, (60,)), Chord(1.25, (60,))],
        ),
        Scene(
            "cue_then_play",
            [Chord(0.90, (60,))],
            cues=[Chord(0.40, (60,))],
        ),
        Scene(
            "cue_only",
            [],
            cues=[Chord(0.40, (60, 64))],
            wait_forever=(60, 64),
            pad=2.2,
        ),
    ]


def render_scene(scene: Scene) -> np.ndarray:
    n = int(math.ceil(scene.duration() * SR44)) + WIN44
    buf = np.zeros(n, dtype=np.float32)
    for c in scene.cues:
        for m in c.midis:
            mix_note(buf, m, c.t, CUE_GAIN)
    for c in scene.user:
        for m in c.midis:
            mix_note(buf, m, c.t, 1.0)
    peak = float(np.max(np.abs(buf))) + 1e-9
    if peak > 0.98:
        buf *= 0.98 / peak
    return buf


def infer_tail(session, audio22: np.ndarray, prior: set[int]) -> set[int]:
    window = np.zeros((1, AUDIO_N, 1), dtype=np.float32)
    n = len(audio22)
    if n >= AUDIO_N:
        window[0, :, 0] = audio22[-AUDIO_N:]
    elif n > 0:
        window[0, AUDIO_N - n :, 0] = audio22
    frames = session.run([NOTE_OUT], {INPUT_NAME: window})[0][0]
    t = min(TAIL, frames.shape[0])
    scores = frames[-t:].mean(axis=0)
    return select_notes(scores, prior_midis=prior)


def to22(audio44: np.ndarray) -> np.ndarray:
    return resample_linear(audio44, SR44, SR22)


@dataclass
class SceneReport:
    name: str
    user_events: int
    hits: int
    misses: int
    false_advances: int
    lags_ms: list[float]
    notes: list[str]

    def as_dict(self) -> dict:
        lags = sorted(self.lags_ms)
        return {
            "name": self.name,
            "user_events": self.user_events,
            "hits": self.hits,
            "misses": self.misses,
            "false_advances": self.false_advances,
            "lag_p50_ms": _pct(lags, 50),
            "lag_p95_ms": _pct(lags, 95),
            "notes": self.notes,
        }


def _pct(sorted_vals: list[float], p: float) -> float | None:
    if not sorted_vals:
        return None
    if len(sorted_vals) == 1:
        return round(sorted_vals[0], 1)
    rank = (p / 100.0) * (len(sorted_vals) - 1)
    lo = int(math.floor(rank))
    hi = int(math.ceil(rank))
    if lo == hi:
        return round(sorted_vals[lo], 1)
    t = rank - lo
    return round(sorted_vals[lo] * (1 - t) + sorted_vals[hi] * t, 1)


def run_scene(session, scene: Scene) -> SceneReport:
    audio44 = render_scene(scene)
    audio22 = to22(audio44)
    lock = LockState()
    onset = OnsetFlux()
    latch = AttackLatch()
    bleed = CueBleed()
    gate = GuideGate()
    suppress_until: dict[int, float] = {}
    notes: list[str] = []

    user_i = 0
    satisfied: set[int] = set()
    waiting: set[int] = set(scene.user[0].midis) if scene.user else set(scene.wait_forever)
    completions: list[float | None] = [None] * len(scene.user)
    false_advances = 0
    cue_only_tripped = False
    armed_cues: set[int] = set()

    def suppressed(midi: int, t: float) -> bool:
        until = suppress_until.get(midi)
        return until is not None and t < until

    def arm_cue(chord: Chord) -> None:
        bleed.arm(set(chord.midis), chord.t)
        gate.arm(set(chord.midis))
        until = chord.t + ECHO_GUIDE_SEC
        for m in chord.midis:
            for x in (m - 1, m, m + 1):
                if 21 <= x <= 108:
                    suppress_until[x] = max(suppress_until.get(x, 0.0), until)

    def register(midi_wait: int, t: float, how: str, heard: int | None = None) -> None:
        nonlocal user_i, waiting, satisfied, false_advances, cue_only_tripped
        if midi_wait not in waiting or midi_wait in satisfied:
            return
        satisfied.add(midi_wait)
        latch.mark(midi_wait, midi_wait if heard is None else heard)
        gate.disarm({midi_wait})
        notes.append(f"{t:.3f} hit {midi_wait} via {how}")
        if not scene.user:
            cue_only_tripped = True
            false_advances += 1
            return
        if satisfied >= waiting:
            completions[user_i] = t
            if t + 1e-3 < scene.user[user_i].t - 0.03:
                false_advances += 1
                notes.append(f"false early complete {scene.user[user_i].t:.3f} at {t:.3f}")
            user_i += 1
            satisfied = set()
            if user_i < len(scene.user):
                waiting = set(scene.user[user_i].midis)
            else:
                waiting = set()

    n_hops = max(0, (len(audio44) - WIN44) // HOP44)
    for step in range(n_hops):
        end44 = WIN44 + step * HOP44
        t = end44 / SR44
        for ci, cue in enumerate(scene.cues):
            if ci in armed_cues:
                continue
            if t + 1e-6 >= cue.t:
                arm_cue(cue)
                armed_cues.add(ci)
        prior = prior_bins(waiting)
        end22 = int(round(end44 * SR22 / SR44))
        raw = infer_tail(session, audio22[:end22], prior) if end22 > 0 else set()
        window = audio44[end44 - WIN44 : end44]
        rms = float(np.sqrt(np.mean(np.square(window)))) if len(window) else 0.0
        above = rms >= RMS_GATE
        if not above:
            raw = set()
        lock.update(raw, above)
        onset_samples = window[-2048:] if len(window) > 2048 else window
        onset_hit = bool(above and onset.push(onset_samples))
        if onset_hit and lock.locked:
            lock.emitted.difference_update(lock.locked)

        if not lock.locked:
            lock.emitted.clear()
            edges: list[int] = []
        else:
            edges = []
            for m in sorted(lock.locked):
                if m not in lock.emitted:
                    lock.emitted.add(m)
                    edges.append(m)
            lock.emitted.intersection_update(lock.locked)

        pressed = {m for m in lock.locked if not suppressed(m, t)}
        if waiting:
            pressed = {
                h
                for h in pressed
                if any(
                    h == e or is_octave(e, h) or (soft_allowed(waiting) and is_near(e, h))
                    for e in waiting
                )
            }
        latch.on_heard(pressed)
        if onset_hit and pressed:
            latch.release_on_onset(pressed)

        if waiting:
            still_sup = {m for m in gate.awaiting if suppressed(m, t)}
            for m in gate.accept(pressed, waiting, still_sup):
                if latch.blocks(m):
                    continue
                register(m, t, "frame", heard=m)

        for midi in edges:
            if suppressed(midi, t):
                continue
            heard_all = set(pressed)
            heard_all.add(midi)
            if bleed.is_bleed(midi, onset_hit, heard_all, t):
                notes.append(f"{t:.3f} bleed-block {midi}")
                continue
            if not waiting:
                continue
            matched = match_note_on(midi, waiting)
            if matched is None:
                continue
            if latch.blocks(midi) or latch.blocks(matched):
                notes.append(f"{t:.3f} latch-block {midi}->{matched}")
                continue
            register(matched, t, "noteOn" + ("+onset" if onset_hit else ""), heard=midi)

    hits = 0
    misses = 0
    lags: list[float] = []
    for i, chord in enumerate(scene.user):
        done = completions[i]
        if done is None or done - chord.t > 1.0:
            misses += 1
            notes.append(f"miss @{chord.t:.3f} {list(chord.midis)}")
            continue
        if done + 1e-3 < chord.t - 0.03:
            # already counted false; not a hit
            continue
        hits += 1
        lags.append((done - chord.t) * 1000.0)
    if scene.wait_forever and cue_only_tripped:
        pass
    elif scene.wait_forever and not cue_only_tripped:
        notes.append("cue-only held")
    return SceneReport(
        name=scene.name,
        user_events=len(scene.user),
        hits=hits,
        misses=misses,
        false_advances=false_advances,
        lags_ms=lags,
        notes=notes,
    )


def summarize(rows: list[SceneReport]) -> dict:
    user = sum(r.user_events for r in rows)
    misses = sum(r.misses for r in rows)
    false_n = sum(r.false_advances for r in rows)
    # cue-only counts as one trial in the false denominator
    trials = user + sum(1 for r in rows if r.user_events == 0)
    lags = sorted(x for r in rows for x in r.lags_ms)
    no_cue = [r for r in rows if r.name in {"melody", "chord4", "restrike"}]
    no_cue_user = sum(r.user_events for r in no_cue)
    no_cue_miss = sum(r.misses for r in no_cue)
    no_cue_false = sum(r.false_advances for r in no_cue)
    no_cue_lags = sorted(x for r in no_cue for x in r.lags_ms)
    return {
        "schema": "pianoflow.replay_follow.v1",
        "scenes": [r.as_dict() for r in rows],
        "no_guide": {
            "events": no_cue_user,
            "miss_rate": round(no_cue_miss / no_cue_user, 4) if no_cue_user else None,
            "false_rate": round(no_cue_false / no_cue_user, 4) if no_cue_user else None,
            "lag_p50_ms": _pct(no_cue_lags, 50),
            "lag_p95_ms": _pct(no_cue_lags, 95),
            "slo": {
                "miss_lt_5pct": (no_cue_miss / no_cue_user) < 0.05 if no_cue_user else False,
                "false_lt_2pct": (no_cue_false / no_cue_user) < 0.02 if no_cue_user else False,
                "p95_lt_300ms": (_pct(no_cue_lags, 95) or 1e9) < 300,
            },
        },
        "all": {
            "events": user,
            "cue_only_trials": trials - user,
            "misses": misses,
            "false_advances": false_n,
            "miss_rate": round(misses / user, 4) if user else None,
            "false_rate": round(false_n / trials, 4) if trials else None,
            "lag_p50_ms": _pct(lags, 50),
            "lag_p95_ms": _pct(lags, 95),
        },
        "honesty": (
            "Soundfont one-shots mixed in silence, same ONNX as the app. "
            "Not a phone mic or a room. Do not retune frozen constants from this table alone."
        ),
    }


def run_all() -> dict:
    import onnxruntime as ort

    if not MODEL.is_file():
        raise FileNotFoundError(MODEL)
    _log(f"piano={piano_dir()}")
    sess = ort.InferenceSession(str(MODEL), providers=["CPUExecutionProvider"])
    rows = []
    for scene in default_scenes():
        _log(f"scene {scene.name} ...")
        row = run_scene(sess, scene)
        rows.append(row)
        d = row.as_dict()
        _log(
            f"  hits={d['hits']} miss={d['misses']} false={d['false_advances']} "
            f"p50={d['lag_p50_ms']} p95={d['lag_p95_ms']}"
        )
    return summarize(rows)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Offline follow replay bench")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args(argv)
    report = run_all()
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
        _log(f"wrote {args.out}")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
