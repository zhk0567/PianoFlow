/** Note selection from Basic Pitch ONNX frames — port of lib/features/practice/basic_pitch.dart */

const MIDI_OFFSET = 21;
const N_BINS = 88;
const PARTIALS = new Set([12, 19, 24, 28, 31, 36]);

export function asFrameBins(raw) {
  let root = raw;
  if (!Array.isArray(root)) return [];
  if (root.length && Array.isArray(root[0]) && root[0].length && Array.isArray(root[0][0])) {
    root = root[0];
  }
  return root.filter((row) => Array.isArray(row)).map((row) => row.map((e) => Number(e)));
}

export function tailMeanScores(frames, tail = 4) {
  const n = Math.min(tail, frames.length);
  const start = frames.length - n;
  const scores = new Array(N_BINS).fill(0);
  for (let t = start; t < frames.length; t++) {
    const row = frames[t];
    for (let b = 0; b < N_BINS && b < row.length; b++) scores[b] += row[b];
  }
  for (let b = 0; b < N_BINS; b++) scores[b] /= n;
  return scores;
}

function isPartialGhost(c, kept) {
  for (const k of kept) {
    const interval = c.midi - k.midi;
    if (interval <= 0 || !PARTIALS.has(interval)) continue;
    if (c.score < k.score * 1.35) return true;
  }
  return false;
}

export function selectNotes(scores, frameThresh = 0.42, relativeThresh = 0.60, priorMidis = null, priorBoost = 1.35) {
  const work = scores.slice();
  if (priorMidis && priorMidis.size && priorBoost > 1) {
    for (const m of priorMidis) {
      const b = m - MIDI_OFFSET;
      if (b < 0 || b >= work.length) continue;
      work[b] = Math.min(1, work[b] * priorBoost);
    }
  }
  let peak = 0;
  for (const s of work) if (s > peak) peak = s;
  if (peak < frameThresh * 0.85) return new Set();

  const floor = Math.max(frameThresh, peak * relativeThresh);
  const candidates = [];
  for (let b = 0; b < N_BINS; b++) {
    const s = work[b];
    if (s < floor) continue;
    const midi = MIDI_OFFSET + b;
    if (midi < 21 || midi > 108) continue;
    candidates.push({ midi, score: s });
  }
  if (!candidates.length) return new Set();
  candidates.sort((a, b) => b.score - a.score);

  const kept = [];
  for (const c of candidates) {
    if (isPartialGhost(c, kept)) continue;
    kept.push(c);
    if (kept.length >= 6) break;
  }

  const midis = new Set(kept.map((e) => e.midi));
  for (const m of [...midis].sort((a, b) => a - b)) {
    if (midis.has(m + 12)) {
      const low = kept.find((e) => e.midi === m);
      const high = kept.find((e) => e.midi === m + 12);
      if (high && low && high.score < frameThresh && high.score <= low.score * 1.25) midis.delete(m + 12);
    }
  }
  return midis;
}

export function selectNotesOffline(scores) {
  return selectNotes(scores, 0.28, 0.5);
}
