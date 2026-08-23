/** Multi-peak YIN — polyphonic fallback when Basic Pitch ONNX unavailable. */

function yinCmnd(x, sampleRate) {
  const n = x.length;
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
  return { cmnd, tauMin, tauMax };
}

function tauToMidi(tau, sampleRate) {
  if (tau <= 0) return null;
  const hz = sampleRate / tau;
  if (hz < 60 || hz > 2000) return null;
  const midi = Math.round(69 + 12 * Math.log2(hz / 440));
  return Math.min(108, Math.max(21, midi));
}

/** Up to 4 MIDI notes from one PCM buffer. */
export function midisFromPcm16Poly(samples, sampleRate, threshold = 0.14) {
  const n = Math.min(samples.length, 4096);
  if (n < 512) return [];
  const x = new Float32Array(n);
  let rms = 0;
  for (let i = 0; i < n; i++) {
    const v = samples[i] / 32768;
    x[i] = v;
    rms += v * v;
  }
  rms = Math.sqrt(rms / n);
  if (rms < 0.008) return [];

  const { cmnd, tauMin, tauMax } = yinCmnd(x, sampleRate);
  const peaks = [];
  for (let tau = tauMin + 1; tau < tauMax - 1; tau++) {
    if (cmnd[tau] < threshold && cmnd[tau] <= cmnd[tau - 1] && cmnd[tau] <= cmnd[tau + 1]) {
      peaks.push({ tau, v: cmnd[tau] });
    }
  }
  peaks.sort((a, b) => a.v - b.v);
  const out = new Set();
  for (const p of peaks) {
    const m = tauToMidi(p.tau, sampleRate);
    if (m == null) continue;
    let dup = false;
    for (const k of out) if (Math.abs(k - m) <= 1) dup = true;
    if (!dup) out.add(m);
    if (out.size >= 4) break;
  }
  if (!out.size && peaks.length) {
    const m = tauToMidi(peaks[0].tau, sampleRate);
    if (m != null) out.add(m);
  }
  return [...out];
}
