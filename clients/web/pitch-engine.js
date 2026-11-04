/** Pitch engine: Basic Pitch ONNX (optional) → Poly-YIN → YIN. */

import { midiFromPcm16 } from "./yin.js";
import { midisFromPcm16Poly } from "./poly-yin.js";
import { asFrameBins, tailMeanScores, selectNotes } from "./basic-pitch-core.js";
import { OnsetFluxDetector } from "./onset-flux.js";

const SR = 22050;
const AUDIO_N = 43844;
const INPUT = "serving_default_input_2:0";
const NOTE_OUT = "StatefulPartitionedCall:1";

let engine = "yin";
let session = null;
let ring = new Float32Array(AUDIO_N);
let ringLen = 0;
/** @type {Set<number>} */
let scorePrior = new Set();
const onsetDet = new OnsetFluxDetector();

export function setScorePriorMidis(midis) {
  scorePrior = midis instanceof Set ? new Set(midis) : new Set(midis || []);
}

export function clearScorePriorMidis() {
  scorePrior = new Set();
}

function pushRing(f32) {
  if (f32.length >= AUDIO_N) {
    ring.set(f32.subarray(f32.length - AUDIO_N));
    ringLen = AUDIO_N;
    return;
  }
  const combined = new Float32Array(Math.min(AUDIO_N, ringLen + f32.length));
  if (ringLen > 0) combined.set(ring.subarray(0, ringLen), 0);
  combined.set(f32, ringLen);
  ringLen = combined.length;
  if (ringLen >= AUDIO_N) {
    ring.set(combined.subarray(ringLen - AUDIO_N));
    ringLen = AUDIO_N;
  } else {
    ring = combined;
  }
}

export function getPitchEngineLabel() {
  if (engine === "basicPitch") return "Basic Pitch";
  if (engine === "polyYin") return "增强多音 YIN";
  return "YIN";
}

export async function initPitchEngine() {
  try {
    if (!window.ort) {
      await new Promise((resolve, reject) => {
        const s = document.createElement("script");
        s.src = "https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/ort.min.js";
        s.onload = resolve;
        s.onerror = () => reject(new Error("ort load failed"));
        document.head.appendChild(s);
      });
    }
    const res = await fetch("./models/basic_pitch.onnx");
    if (!res.ok) throw new Error(`model HTTP ${res.status}`);
    const buf = await res.arrayBuffer();
    session = await ort.InferenceSession.create(buf, { executionProviders: ["wasm"] });
    engine = "basicPitch";
    console.log("[PianoFlow/Web/Pitch] engine: Basic Pitch");
    return engine;
  } catch (e) {
    console.warn("[PianoFlow/Web/Pitch] Basic Pitch unavailable, using Poly-YIN:", e.message || e);
    engine = "polyYin";
    return engine;
  }
}

async function inferBasicPitch() {
  if (!session || ringLen < 2048) return new Set();
  const window = new Float32Array(AUDIO_N);
  if (ringLen >= AUDIO_N) window.set(ring);
  else window.set(ring.subarray(0, ringLen), AUDIO_N - ringLen);

  const input = new ort.Tensor("float32", window, [1, AUDIO_N, 1]);
  const out = await session.run({ [INPUT]: input });
  const noteVal = out[NOTE_OUT];
  if (!noteVal?.data) return new Set();
  const { data, dims } = noteVal;
  const frames = [];
  if (dims?.length === 3) {
    const nFrames = dims[1];
    const nBins = dims[2];
    for (let t = 0; t < nFrames; t++) {
      const row = [];
      for (let b = 0; b < nBins; b++) row.push(data[t * nBins + b]);
      frames.push(row);
    }
  } else {
    frames.push(...asFrameBins(Array.from(data)));
  }
  return selectNotes(tailMeanScores(frames, 4), 0.42, 0.60, scorePrior.size ? scorePrior : null);
}

/** Process PCM16 chunk; returns `{ midis: Set, onset: boolean }`. */
export async function processPitchPcm16(pcm, sampleRate = SR) {
  const f32 = new Float32Array(pcm.length);
  for (let i = 0; i < pcm.length; i++) f32[i] = pcm[i] / 32768;
  if (sampleRate !== SR) {
    const ratio = SR / sampleRate;
    const n2 = Math.floor(f32.length * ratio);
    const r = new Float32Array(n2);
    for (let i = 0; i < n2; i++) r[i] = f32[Math.min(f32.length - 1, Math.floor(i / ratio))];
    pushRing(r);
  } else {
    pushRing(f32);
  }

  let midis = new Set();
  if (engine === "basicPitch" && session) {
    try {
      const s = await inferBasicPitch();
      if (s.size) midis = s;
    } catch (e) {
      console.error("[PianoFlow/Web/Pitch] infer failed", e);
    }
  }
  if (!midis.size && (engine === "polyYin" || engine === "basicPitch")) {
    const poly = midisFromPcm16Poly(pcm, sampleRate);
    if (poly.length) midis = new Set(poly);
  }
  if (!midis.size) {
    const m = midiFromPcm16(pcm, sampleRate);
    if (m != null) midis = new Set([m]);
  }
  const tail = f32.length > 2048 ? f32.subarray(f32.length - 2048) : f32;
  const onset = midis.size > 0 && onsetDet.push(tail);
  return { midis, onset };
}

export async function transcribeFloat32Mono(audio22050, { offline = true } = {}) {
  if (engine === "basicPitch" && session) {
    const hop = 4096;
    const events = [];
    let last = new Set();
    for (let i = 0; i < audio22050.length; i += hop) {
      const chunk = audio22050.subarray(i, Math.min(audio22050.length, i + AUDIO_N));
      ring = new Float32Array(AUDIO_N);
      ringLen = 0;
      pushRing(chunk);
      const active = await inferBasicPitch();
      const beat = (i / SR) * 2;
      for (const m of active) {
        if (!last.has(m)) events.push({ midi: m, start: beat, duration: 0.25 });
      }
      for (const m of last) {
        if (!active.has(m)) {
          let ev = null;
          for (let j = events.length - 1; j >= 0; j--) {
            if (events[j].midi === m) { ev = events[j]; break; }
          }
          if (ev) ev.duration = Math.max(0.12, beat - ev.start);
        }
      }
      last = active;
    }
    return events;
  }
  const hop = 2048;
  const events = [];
  const pcm = new Int16Array(audio22050.length);
  for (let i = 0; i < audio22050.length; i++) pcm[i] = Math.max(-32768, Math.min(32767, Math.round(audio22050[i] * 32767)));
  for (let i = 0; i < pcm.length; i += hop) {
    const slice = pcm.subarray(i, Math.min(pcm.length, i + 4096));
    const midis = midisFromPcm16Poly(slice, SR, offline ? 0.16 : 0.14);
    const beat = (i / SR) * 2;
    for (const m of midis) events.push({ midi: m, start: beat, duration: 0.2 });
  }
  return events;
}

export { SR as PITCH_SAMPLE_RATE };
