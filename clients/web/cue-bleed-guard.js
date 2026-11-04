/** Soft-cue bleed filter — port of cue_bleed_guard.dart */

import { isNear, isOctaveRelative } from "./pitch-match.js";

export class CueBleedGuard {
  constructor({
    softTailMs = 180,
    hardSuppressMs = 250,
    reedgeGraceMs = 50,
  } = {}) {
    this.softTailMs = softTailMs;
    this.hardSuppressMs = hardSuppressMs;
    this.reedgeGraceMs = reedgeGraceMs;
    this.cued = new Set();
    this.cueAt = 0;
  }

  arm(midis, at = performance.now()) {
    this.cued = new Set(midis);
    this.cueAt = at;
  }

  clear() {
    this.cued = new Set();
    this.cueAt = 0;
  }

  nearCue(midi) {
    for (const c of this.cued) {
      if (isNear(c, midi) || isOctaveRelative(c, midi)) return true;
    }
    return false;
  }

  onlyCueNeighborhood(heard) {
    if (!heard.size) return true;
    for (const h of heard) {
      if (!this.nearCue(h)) return false;
    }
    return true;
  }

  isBleed(midi, hasOnset, heardAll, now = performance.now()) {
    if (!this.cued.size || !this.cueAt) return false;
    if (!this.nearCue(midi)) return false;
    if (hasOnset) return false;
    const hardEnd = this.cueAt + this.hardSuppressMs;
    const softEnd = hardEnd + this.softTailMs;
    if (now < hardEnd) return true;
    if (now < softEnd) {
      if (now - hardEnd < this.reedgeGraceMs) return false;
      return this.onlyCueNeighborhood(heardAll);
    }
    return false;
  }
}
