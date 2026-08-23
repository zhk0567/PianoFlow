/** Piano sample player (audio/piano/n{midi}.wav) — silent preload, no ghost play. */
let ctx;
const buffers = new Map();
let preloadStarted = false;

function ensureCtx() {
  if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
  if (ctx.state === "suspended") ctx.resume();
  return ctx;
}

export function unlockAudio() {
  ensureCtx();
  if (!preloadStarted) {
    preloadStarted = true;
    preloadAll().catch((e) => console.warn("[PianoFlow/Web/Audio] preload", e));
  }
}

async function preloadAll() {
  const ac = ensureCtx();
  const jobs = [];
  for (let midi = 21; midi <= 108; midi++) {
    jobs.push(
      (async () => {
        try {
          const res = await fetch(`./audio/piano/n${midi}.wav`);
          if (!res.ok) return;
          const arr = await res.arrayBuffer();
          const buf = await ac.decodeAudioData(arr.slice(0));
          buffers.set(midi, buf);
        } catch (_) {
          /* missing sample */
        }
      })(),
    );
  }
  await Promise.all(jobs);
  console.log("[PianoFlow/Web/Audio] samples ready", buffers.size);
}

let masterVolume = 0.85;
try {
  const saved = localStorage.getItem("pf_master_vol");
  if (saved != null) masterVolume = Math.max(0.05, Math.min(1, Number(saved) || 0.85));
} catch (_) {}

export function setMasterVolume(v) {
  masterVolume = Math.max(0.05, Math.min(1, v));
  try { localStorage.setItem("pf_master_vol", String(masterVolume)); } catch (_) {}
}

export function getMasterVolume() {
  return masterVolume;
}

export function playMidi(midi, _ms = 0, volume = 0.85) {
  const ac = ensureCtx();
  const m = Math.max(21, Math.min(108, midi | 0));
  const vol = volume * masterVolume;
  const buf = buffers.get(m);
  if (!buf) {
    // Soft fallback sine only if sample not yet loaded
    const osc = ac.createOscillator();
    const gain = ac.createGain();
    osc.frequency.value = 440 * Math.pow(2, (m - 69) / 12);
    osc.type = "sine";
    const now = ac.currentTime;
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.12, now + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.18);
    osc.connect(gain);
    gain.connect(ac.destination);
    osc.start(now);
    osc.stop(now + 0.2);
    return;
  }
  const src = ac.createBufferSource();
  const gain = ac.createGain();
  src.buffer = buf;
  gain.gain.value = vol;
  src.connect(gain);
  gain.connect(ac.destination);
  src.start();
}
