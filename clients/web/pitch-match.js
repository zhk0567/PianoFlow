/** Score-conditioned pitch match — port of practice_pitch_match.dart */

export const SOFT_SEMITONE_MAX_WAITING = 1;

export function softSemitoneAllowed(waitingFor) {
  return waitingFor.size <= SOFT_SEMITONE_MAX_WAITING;
}

export function isNear(expected, heard) {
  return Math.abs(expected - heard) <= 1;
}

export function isOctaveRelative(expected, heard) {
  return Math.abs(expected - heard) === 12;
}

export function conditionHeard(heard, waitingFor) {
  if (!heard.size || !waitingFor.size) return heard;
  const soft = softSemitoneAllowed(waitingFor);
  const out = new Set();
  for (const h of heard) {
    for (const e of waitingFor) {
      if (h === e || isOctaveRelative(e, h) || (soft && isNear(e, h))) {
        out.add(h);
        break;
      }
    }
  }
  return out;
}

export function priorBins(waitingFor) {
  const out = new Set();
  for (const m of waitingFor) {
    for (const x of [m - 12, m - 1, m, m + 1, m + 12]) {
      if (x >= 21 && x <= 108) out.add(x);
    }
  }
  return out;
}

export function isForgivableWrongPitch(heard, waitingFor) {
  if (!waitingFor.size) return false;
  const soft = softSemitoneAllowed(waitingFor);
  for (const e of waitingFor) {
    if (isOctaveRelative(e, heard)) return true;
    if (soft && isNear(e, heard)) return true;
  }
  return false;
}

export function matchWaiting(heard, waitingFor) {
  if (!heard.size || !waitingFor.size) return new Set();
  const conditioned = conditionHeard(heard, waitingFor);
  if (!conditioned.size) return new Set();
  const remaining = new Set(waitingFor);
  const hits = new Set();
  const usedHeard = new Set();
  const soft = softSemitoneAllowed(waitingFor);

  for (const h of conditioned) {
    if (remaining.delete(h)) {
      hits.add(h);
      usedHeard.add(h);
    }
  }
  if (soft) {
    for (const h of conditioned) {
      if (usedHeard.has(h)) continue;
      let best = null;
      let bestDist = 2;
      for (const e of remaining) {
        const d = Math.abs(e - h);
        if (d === 0 || d > 1) continue;
        if (d < bestDist || (d === bestDist && (best == null || e < best))) {
          best = e;
          bestDist = d;
        }
      }
      if (best != null) {
        remaining.delete(best);
        hits.add(best);
        usedHeard.add(h);
      }
    }
  }
  for (const h of conditioned) {
    if (usedHeard.has(h)) continue;
    if (waitingFor.has(h)) continue;
    let best = null;
    for (const e of remaining) {
      if (!isOctaveRelative(e, h)) continue;
      if (best == null || e < best) best = e;
    }
    if (best == null) continue;
    remaining.delete(best);
    hits.add(best);
    usedHeard.add(h);
  }
  return hits;
}

export function matchNoteOn(midi, waitingFor) {
  if (!waitingFor.size) return null;
  if (waitingFor.has(midi)) return midi;
  const hits = matchWaiting(new Set([midi]), waitingFor);
  if (!hits.size) return null;
  return [...hits][0];
}
