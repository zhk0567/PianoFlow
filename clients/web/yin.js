/** Minimal YIN → MIDI (Int16 PCM). */
export function midiFromPcm16(samples, sampleRate, threshold = 0.12) {
  const n = Math.min(samples.length, 2048);
  if (n < 512) return null;
  const x = new Float32Array(n);
  let rms = 0;
  for (let i = 0; i < n; i++) {
    const v = samples[i] / 32768;
    x[i] = v;
    rms += v * v;
  }
  rms = Math.sqrt(rms / n);
  if (rms < 0.01) return null;

  const tauMax = Math.min(Math.floor(sampleRate / 60), Math.floor(n / 2));
  const tauMin = Math.max(2, Math.floor(sampleRate / 1000));
  const d = new Float32Array(tauMax + 1);
  for (let tau = tauMin; tau <= tauMax; tau++) {
    let sum = 0;
    const limit = n - tau;
    for (let i = 0; i < limit; i++) {
      const diff = x[i] - x[i + tau];
      sum += diff * diff;
    }
    d[tau] = sum;
  }
  const cmnd = new Float32Array(tauMax + 1);
  cmnd[0] = 1;
  let running = 0;
  for (let tau = 1; tau <= tauMax; tau++) {
    running += d[tau];
    cmnd[tau] = running > 0 ? (d[tau] * tau) / running : 1;
  }
  let bestTau = -1;
  for (let tau = tauMin; tau <= tauMax; tau++) {
    if (cmnd[tau] < threshold) {
      let t = tau;
      while (t + 1 <= tauMax && cmnd[t + 1] < cmnd[t]) t++;
      bestTau = t;
      break;
    }
  }
  if (bestTau <= 0) {
    let minV = Infinity;
    for (let tau = tauMin; tau <= tauMax; tau++) {
      if (cmnd[tau] < minV) {
        minV = cmnd[tau];
        bestTau = tau;
      }
    }
    if (minV > 0.45) return null;
  }
  const hz = sampleRate / bestTau;
  if (hz < 60 || hz > 2000) return null;
  const midi = Math.round(69 + 12 * Math.log2(hz / 440));
  return Math.min(108, Math.max(21, midi));
}
