/** Lightweight HF-flux onset — port of onset_flux.dart */

export class OnsetFluxDetector {
  constructor({
    fluxThresh = 0.028,
    ratioThresh = 1.55,
    minRms = 0.008,
    cooldownHops = 3,
  } = {}) {
    this.fluxThresh = fluxThresh;
    this.ratioThresh = ratioThresh;
    this.minRms = minRms;
    this.cooldownHops = cooldownHops;
    this.prevHf = 0;
    this.cooldown = 0;
    this.lastFlux = 0;
  }

  reset() {
    this.prevHf = 0;
    this.cooldown = 0;
    this.lastFlux = 0;
  }

  static highFreqEnergy(samples) {
    if (samples.length < 2) return 0;
    let sum = 0;
    for (let i = 1; i < samples.length; i++) {
      const d = samples[i] - samples[i - 1];
      sum += d * d;
    }
    return Math.sqrt(sum / (samples.length - 1));
  }

  static rms(samples) {
    if (!samples.length) return 0;
    let sum = 0;
    for (const s of samples) sum += s * s;
    return Math.sqrt(sum / samples.length);
  }

  /** @param {Float32Array|number[]} samples */
  push(samples) {
    if (samples.length < 64) {
      this.lastFlux = 0;
      return false;
    }
    if (this.cooldown > 0) {
      this.cooldown--;
      const hf = OnsetFluxDetector.highFreqEnergy(samples);
      this.prevHf = this.prevHf * 0.65 + hf * 0.35;
      this.lastFlux = 0;
      return false;
    }
    const hf = OnsetFluxDetector.highFreqEnergy(samples);
    const rms = OnsetFluxDetector.rms(samples);
    const flux = Math.max(0, hf - this.prevHf);
    this.lastFlux = flux;
    const rising =
      this.prevHf <= 1e-6 ? hf >= this.fluxThresh : hf >= this.prevHf * this.ratioThresh;
    const onset = rms >= this.minRms && flux >= this.fluxThresh && rising;
    this.prevHf = this.prevHf * 0.55 + hf * 0.45;
    if (onset) this.cooldown = Math.max(1, this.cooldownHops);
    return onset;
  }
}
