import { parseMusicXmlNotes } from "./musicxml-notes.js";
import { parseMidi, midiToMusicXml, midiToPracticeNotes } from "./midi-parse.js";
import { saveUserImport } from "./storage.js";

const MIDI_HONESTY =
  "工坊 MIDI 导入（可跟弹；MIDI→MusicXML 会丢声部/记谱细节，质量档为自导入，非教材级正式谱）。";

function slugFromName(name) {
  const base = name.replace(/\.[^.]+$/, "").replace(/[^a-zA-Z0-9\u4e00-\u9fff]+/g, "_").toLowerCase();
  return `user_${base.slice(0, 40) || "import"}_${Date.now().toString(36).slice(-4)}`;
}

function titleFromXml(xml, fallback) {
  const m = xml.match(/<work-title[^>]*>([^<]+)<\/work-title>/i) ||
    xml.match(/<movement-title[^>]*>([^<]+)<\/movement-title>/i);
  return (m?.[1] || fallback || "自导入曲目").trim();
}

function bpmFromXml(xml) {
  const m = xml.match(/<sound[^>]*tempo="([\d.]+)"/i);
  return m ? Math.round(parseFloat(m[1])) : 72;
}

function notesToScoreJson(id, title, bpm, parsed) {
  const notes = parsed.map((n) => ({
    midi: n.midi,
    start: n.onsetBeats,
    duration: n.durationBeats,
    hand: n.midi < 60 ? "left" : "right",
  }));
  return {
    id,
    title,
    bpm,
    timeSignature: { num: 4, den: 4 },
    keySignature: 0,
    notes,
  };
}

/** Import MusicXML text into IndexedDB user catalog. */
export async function importMusicXmlText(xmlText, fileName = "import.musicxml") {
  const id = slugFromName(fileName);
  const title = titleFromXml(xmlText, fileName);
  const bpm = bpmFromXml(xmlText);
  const parsed = parseMusicXmlNotes(xmlText);
  if (!parsed.length) throw new Error("未解析到音符");
  const scoreJson = notesToScoreJson(id, title, bpm, parsed);
  const catalogEntry = {
    id,
    title,
    artist: "自导入",
    genre: "用户导入",
    difficulty: 2,
    bpm,
    scoreKind: "userImport",
    asset: `./user/${id}.json`,
    description: "工坊 MusicXML 导入（可跟弹；自导入质量档，未做教材级校对）。",
  };
  await saveUserImport({
    id,
    catalogEntry,
    scoreJson,
    musicXml: xmlText,
  });
  console.log("[PianoFlow/Web/Workshop] imported", id, parsed.length, "notes");
  return catalogEntry;
}

/** Import .mid / .midi bytes */
export async function importMidiBytes(buffer, fileName = "import.mid") {
  const { notes, ppq, bpm, timeSig } = parseMidi(buffer);
  const title = fileName.replace(/\.[^.]+$/, "");
  const xmlText = midiToMusicXml(notes, ppq, bpm, timeSig, title);
  const parsed = midiToPracticeNotes(notes, ppq);
  const id = slugFromName(fileName).replace(/^user_/, "user_midi_");
  const scoreJson = notesToScoreJson(id, title, bpm, parsed);
  const catalogEntry = {
    id,
    title,
    artist: "MIDI导入",
    genre: "用户导入",
    difficulty: 2,
    bpm,
    scoreKind: "userImport",
    asset: `./user/${id}.json`,
    description: MIDI_HONESTY,
  };
  await saveUserImport({ id, catalogEntry, scoreJson, musicXml: xmlText });
  console.log("[PianoFlow/Web/Workshop] MIDI imported", id, parsed.length, "notes");
  return catalogEntry;
}

export async function readFileAsArrayBuffer(file) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result);
    r.onerror = () => reject(r.error);
    r.readAsArrayBuffer(file);
  });
}

export async function readFileAsText(file) {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result || ""));
    r.onerror = () => reject(r.error);
    r.readAsText(file);
  });
}
