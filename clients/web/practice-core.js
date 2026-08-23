export const PracticeConsts = {
  waitEarlyHitBeats: 0.45,
  waitFreezeSlackBeats: 0.02,
  waitChordClusterBeats: 0.02,
  waitAdvanceEpsilonBeats: 0.04,
  judgePerfectBeats: 0.08,
  echoSuppressGuideMs: 250,
  playbackLeadInBeats: 1.0,
  speedMin: 0.4,
  speedMax: 2.0,
};

export function parseScoreJson(text) {
  const root = JSON.parse(text);
  const bpm = root.bpm || 72;
  const notes = (root.notes || []).map((n) => ({
    midi: n.midi,
    start: n.start,
    duration: Math.max(0.05, n.duration),
    hand: n.hand === "left" ? "left" : "right",
  }));
  notes.sort((a, b) => a.start - b.start || a.midi - b.midi);
  return { bpm, notes };
}

export function filterHand(notes, hand) {
  if (hand === "both") return notes;
  return notes.filter((n) => n.hand === hand);
}

export function nextTarget(notes, pos) {
  for (const n of notes) {
    if (n.start + 0.001 >= pos - 0.001) return n;
  }
  return null;
}

export function chordMidis(notes, target) {
  const c = PracticeConsts.waitChordClusterBeats;
  return new Set(
    notes.filter((n) => Math.abs(n.start - target.start) < c).map((n) => n.midi),
  );
}

export function expectedAt(notes, pos) {
  const target = nextTarget(notes, pos);
  if (!target) return new Set();
  if (target.start > pos + PracticeConsts.waitEarlyHitBeats) return new Set();
  return chordMidis(notes, target);
}

export function shouldFreeze(pos, chordStart) {
  return pos >= chordStart - PracticeConsts.waitFreezeSlackBeats;
}

export function nudgePast(notes, pos) {
  const c = PracticeConsts.waitChordClusterBeats;
  const at = notes.filter((n) => Math.abs(n.start - pos) < c);
  if (at.length) return at[0].start + PracticeConsts.waitAdvanceEpsilonBeats;
  const t = nextTarget(notes, pos);
  if (t && t.start <= pos + PracticeConsts.waitEarlyHitBeats) {
    return t.start + PracticeConsts.waitAdvanceEpsilonBeats;
  }
  return pos + PracticeConsts.waitAdvanceEpsilonBeats;
}

export function gradeDelta(delta) {
  return Math.abs(delta) <= PracticeConsts.judgePerfectBeats ? "perfect" : "good";
}

export function suggestWeak(missBeats, duration) {
  if (!missBeats.length || duration <= 0.5) return null;
  const sorted = [...missBeats].sort((a, b) => a - b);
  let bestCount = 0;
  let bestLo = sorted[0];
  let bestHi = sorted[0];
  let j = 0;
  for (let i = 0; i < sorted.length; i++) {
    while (j < sorted.length && sorted[j] - sorted[i] <= 8 + 1e-9) j++;
    const count = j - i;
    if (count > bestCount) {
      bestCount = count;
      bestLo = sorted[i];
      bestHi = sorted[j - 1];
    }
  }
  let start = Math.max(0, bestLo - 1);
  let end = Math.min(duration, bestHi + 1);
  if (end - start < 1) end = Math.min(duration, start + 2);
  if (end <= start + 0.5) return null;
  return { start, end };
}

/** Keyboard geometry for canvas stage. */
export function buildGeo(contentWidth) {
  const whiteMidis = [];
  for (let m = 21; whiteMidis.length < 52; m++) {
    if (![1, 3, 6, 8, 10].includes(m % 12)) whiteMidis.push(m);
  }
  const total = Math.max(1, Math.floor(contentWidth));
  const base = Math.max(1, Math.floor(total / 52));
  const rem = Math.min(52, total - base * 52);
  const widths = Array.from({ length: 52 }, (_, i) => (i < rem ? base + 1 : base));
  const lefts = [];
  let x = 0;
  for (let i = 0; i < 52; i++) {
    lefts.push(x);
    x += widths[i];
  }
  const blackMidis = [];
  for (let m = whiteMidis[0]; m <= whiteMidis[whiteMidis.length - 1]; m++) {
    if ([1, 3, 6, 8, 10].includes(m % 12)) blackMidis.push(m);
  }
  const whiteWidth = base;
  const blackWidth = whiteWidth * 0.62;
  function blackLeft(midi) {
    const leftWhite = whiteMidis.findIndex((w) => w > midi) - 1;
    if (leftWhite < 0) return null;
    return lefts[leftWhite + 1] - blackWidth / 2;
  }
  function midiCenterX(midi) {
    if (midi < whiteMidis[0] || midi > whiteMidis[whiteMidis.length - 1]) return null;
    if ([1, 3, 6, 8, 10].includes(midi % 12)) {
      const l = blackLeft(midi);
      return l == null ? null : l + blackWidth / 2;
    }
    const i = whiteMidis.indexOf(midi);
    if (i < 0) return null;
    return lefts[i] + widths[i] / 2;
  }
  return {
    contentWidth: total,
    whiteMidis,
    blackMidis,
    widths,
    lefts,
    whiteWidth,
    blackWidth,
    blackLeft,
    midiCenterX,
    isBlack: (m) => [1, 3, 6, 8, 10].includes(m % 12),
  };
}

export function contentWidthFor(viewportPx, { fitViewport = false } = {}) {
  const vw = Math.max(1, Math.floor(viewportPx));
  if (fitViewport) return vw;
  const minWhite = 22;
  return Math.max(vw, 52 * minWhite);
}

/** Phone / narrow practice: no waterfall FX, keyboard fits viewport (no horizontal scroll). */
export function isMobilePractice() {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(max-width: 768px)").matches;
}
