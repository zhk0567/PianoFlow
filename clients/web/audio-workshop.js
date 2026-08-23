/** Audio → practice draft (userImport). Browser decode + Basic Pitch / Poly-YIN. */

import { transcribeFloat32Mono, initPitchEngine, PITCH_SAMPLE_RATE, getPitchEngineLabel } from "./pitch-engine.js";
import { midiToMusicXml } from "./midi-parse.js";
import { saveUserImport } from "./storage.js";

const HONESTY =
  "工坊音频转录草稿（非正式精确谱；Web 端 Basic Pitch/Poly-YIN 转练习 JSON，禁止冒充正式谱）。短音频预览；Demucs 分轨请用 Windows。";

function slug(name) {
  const base = name.replace(/\.[^.]+$/, "").replace(/[^a-zA-Z0-9\u4e00-\u9fff]+/g, "_").toLowerCase();
  return `user_audio_${base.slice(0, 30) || "clip"}_${Date.now().toString(36).slice(-4)}`;
}

function resample(f32, fromSr, toSr) {
  if (fromSr === toSr) return f32;
  const n2 = Math.floor(f32.length * toSr / fromSr);
  const out = new Float32Array(n2);
  for (let i = 0; i < n2; i++) out[i] = f32[Math.min(f32.length - 1, Math.floor((i * fromSr) / toSr))];
  return out;
}

export async function decodeAudioFile(file) {
  const ab = await file.arrayBuffer();
  const ac = new AudioContext();
  const buf = await ac.decodeAudioData(ab.slice(0));
  await ac.close();
  const ch0 = buf.getChannelData(0);
  let mono = ch0;
  if (buf.numberOfChannels > 1) {
    mono = new Float32Array(buf.length);
    const ch1 = buf.getChannelData(1);
    for (let i = 0; i < buf.length; i++) mono[i] = (ch0[i] + ch1[i]) * 0.5;
  }
  const maxSec = 90;
  const maxSamples = Math.min(mono.length, Math.floor(buf.sampleRate * maxSec));
  return resample(mono.subarray(0, maxSamples), buf.sampleRate, PITCH_SAMPLE_RATE);
}

export async function importAudioFile(file) {
  await initPitchEngine();
  const audio = await decodeAudioFile(file);
  if (audio.length < PITCH_SAMPLE_RATE * 0.5) throw new Error("音频太短");
  const events = await transcribeFloat32Mono(audio, { offline: true });
  if (!events.length) throw new Error("未识别到音符");
  const notes = events.map((e) => ({
    midi: e.midi,
    onsetBeats: e.start,
    durationBeats: Math.max(0.12, e.duration || 0.2),
  }));
  const title = file.name.replace(/\.[^.]+$/, "");
  const bpm = 72;
  const id = slug(file.name);
  const ticks = notes.map((n) => ({
    start: Math.round(n.onsetBeats * 480),
    end: Math.round((n.onsetBeats + n.durationBeats) * 480),
    midi: n.midi,
    velocity: 80,
  }));
  const xml = midiToMusicXml(ticks, 480, bpm, [4, 4], title);
  const scoreJson = {
    id,
    title,
    bpm,
    timeSignature: { num: 4, den: 4 },
    keySignature: 0,
    notes: notes.map((n) => ({
      midi: n.midi,
      start: n.onsetBeats,
      duration: n.durationBeats,
      hand: n.midi < 60 ? "left" : "right",
    })),
  };
  const catalogEntry = {
    id,
    title,
    artist: "音频导入",
    genre: "用户导入",
    difficulty: 2,
    bpm,
    scoreKind: "userImport",
    asset: `./user/${id}.json`,
    description: `${HONESTY} 引擎：${getPitchEngineLabel()}。`,
  };
  await saveUserImport({ id, catalogEntry, scoreJson, musicXml: xml });
  console.log("[PianoFlow/Web/Workshop] audio imported", id, notes.length, getPitchEngineLabel());
  return catalogEntry;
}
