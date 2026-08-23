/** Standard MIDI File parser (Type 0/1, PPQ). Port of scripts/midi_to_musicxml_draft.py */

function readVlq(data, i) {
  let value = 0;
  while (i < data.length) {
    const b = data[i++];
    value = (value << 7) | (b & 0x7f);
    if (b < 0x80) return [value, i];
  }
  throw new Error("truncated VLQ");
}

function parseTrack(data) {
  let i = 0;
  let absTick = 0;
  let running = null;
  const active = new Map();
  const notes = [];
  let tempoUs = null;
  let timeSig = null;

  while (i < data.length) {
    let delta;
    [delta, i] = readVlq(data, i);
    absTick += delta;
    if (i >= data.length) break;
    let status = data[i];
    if (status & 0x80) {
      i++;
      running = status;
    } else {
      if (running == null) throw new Error("running status missing");
      status = running;
    }

    if (status === 0xff) {
      if (i >= data.length) break;
      const meta = data[i++];
      let length;
      [length, i] = readVlq(data, i);
      const payload = data.subarray(i, i + length);
      i += length;
      if (meta === 0x2f) break;
      if (meta === 0x51 && length === 3) {
        tempoUs = (payload[0] << 16) | (payload[1] << 8) | payload[2];
      } else if (meta === 0x58 && length >= 2) {
        timeSig = [payload[0], 2 ** payload[1]];
      }
      continue;
    }

    if (status === 0xf0 || status === 0xf7) {
      let length;
      [length, i] = readVlq(data, i);
      i += length;
      continue;
    }

    const msg = status & 0xf0;
    const ch = status & 0x0f;
    if (msg === 0x90 || msg === 0x80 || msg === 0xa0 || msg === 0xb0 || msg === 0xe0) {
      if (i + 1 >= data.length) break;
      const a = data[i];
      const b = data[i + 1];
      i += 2;
      if (msg === 0x90) {
        const key = `${ch}:${a}`;
        if (b === 0) {
          if (active.has(key)) {
            const [start, vel] = active.get(key);
            active.delete(key);
            notes.push({ start, end: absTick, midi: a, velocity: vel });
          }
        } else {
          active.set(key, [absTick, b]);
        }
      } else if (msg === 0x80) {
        const key = `${ch}:${a}`;
        if (active.has(key)) {
          const [start, vel] = active.get(key);
          active.delete(key);
          notes.push({ start, end: absTick, midi: a, velocity: vel });
        }
      }
    } else if (msg === 0xc0 || msg === 0xd0) {
      i += 1;
    } else {
      break;
    }
  }
  for (const [key, [start, vel]] of active) {
    const pitch = Number(key.split(":")[1]);
    notes.push({ start, end: Math.max(start + 1, absTick), midi: pitch, velocity: vel });
  }
  return { notes, tempoUs, timeSig };
}

export function parseMidi(buffer) {
  const data = new Uint8Array(buffer);
  const sig = String.fromCharCode(...data.subarray(0, 4));
  if (sig !== "MThd") throw new Error("不是标准 MIDI 文件");
  const headerLen = (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | data[7];
  const ntrks = (data[10] << 8) | data[11];
  const division = (data[12] << 8) | data[13];
  if (division & 0x8000) throw new Error("不支持 SMPTE 格式 MIDI");
  const ppq = division;
  let i = 8 + headerLen;
  const allNotes = [];
  let tempoUs = null;
  let timeSig = null;
  for (let t = 0; t < ntrks; t++) {
    const trkSig = String.fromCharCode(...data.subarray(i, i + 4));
    if (trkSig !== "MTrk") throw new Error("MTrk 块缺失");
    const tlen = (data[i + 4] << 24) | (data[i + 5] << 16) | (data[i + 6] << 8) | data[i + 7];
    const track = data.subarray(i + 8, i + 8 + tlen);
    i += 8 + tlen;
    const parsed = parseTrack(track);
    allNotes.push(...parsed.notes);
    if (parsed.tempoUs != null && tempoUs == null) tempoUs = parsed.tempoUs;
    if (parsed.timeSig != null && timeSig == null) timeSig = parsed.timeSig;
  }
  if (!allNotes.length) throw new Error("MIDI 中无音符");
  let bpm = 120;
  if (tempoUs && tempoUs > 0) bpm = Math.max(30, Math.min(240, Math.round(60000000 / tempoUs)));
  const ts = timeSig || [4, 4];
  allNotes.sort((a, b) => a.start - b.start || a.midi - b.midi);
  return { notes: allNotes, ppq, bpm, timeSig: ts };
}

const STEPS = ["C", "C", "D", "D", "E", "F", "F", "G", "G", "A", "A", "B"];
const ALTERS = [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0];

function midiToPitch(midi) {
  const m = Math.max(21, Math.min(108, midi));
  const octave = Math.floor(m / 12) - 1;
  const pc = m % 12;
  return { step: STEPS[pc], alter: ALTERS[pc], octave };
}

function xmlEsc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Crude MusicXML for Verovio (userImport draft). */
export function midiToMusicXml(notes, ppq, bpm, timeSig, title) {
  const [beats, beatType] = timeSig;
  const divisions = Math.max(1, ppq);
  const cleaned = notes.map((n) => ({
    ...n,
    end: n.end > n.start ? n.end : n.start + Math.max(1, Math.floor(ppq / 4)),
  }));
  const maxTick = Math.max(...cleaned.map((n) => n.end));
  const ticksPerMeasure = Math.max(1, Math.floor(ppq * beats * (4 / beatType)));
  const measureCount = Math.max(1, Math.ceil(maxTick / ticksPerMeasure));

  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>${xmlEsc(title)}</work-title></work>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
`;
  for (let mi = 0; mi < measureCount; mi++) {
    const mStart = mi * ticksPerMeasure;
    const mEnd = mStart + ticksPerMeasure;
    const inM = cleaned.filter((n) => n.start >= mStart && n.start < mEnd);
    xml += `    <measure number="${mi + 1}">\n`;
    if (mi === 0) {
      xml += `      <attributes><divisions>${divisions}</divisions>
        <time><beats>${beats}</beats><beat-type>${beatType}</beat-type></time></attributes>\n`;
      xml += `      <direction><sound tempo="${bpm}"/></direction>\n`;
    }
    const byOnset = new Map();
    for (const n of inM) {
      const rel = n.start - mStart;
      if (!byOnset.has(rel)) byOnset.set(rel, []);
      byOnset.get(rel).push(n);
    }
    const onsets = [...byOnset.keys()].sort((a, b) => a - b);
    let cursor = 0;
    for (const onset of onsets) {
      const chord = byOnset.get(onset);
      const delta = Math.max(0, onset - cursor);
      if (delta) xml += `      <forward><duration>${delta}</duration></forward>\n`;
      chord.sort((a, b) => a.midi - b.midi);
      for (let ci = 0; ci < chord.length; ci++) {
        const n = chord[ci];
        const dur = Math.max(1, n.end - n.start);
        const p = midiToPitch(n.midi);
        xml += `      <note>${ci ? "<chord/>" : ""}<pitch><step>${p.step}</step>`;
        if (p.alter) xml += `<alter>${p.alter}</alter>`;
        xml += `<octave>${p.octave}</octave></pitch><duration>${dur}</duration></note>\n`;
      }
      cursor = onset;
    }
    xml += `    </measure>\n`;
  }
  xml += `  </part>\n</score-partwise>`;
  return xml;
}

export function midiToPracticeNotes(notes, ppq) {
  return notes.map((n) => {
    const start = n.start / ppq;
    const duration = Math.max(0.05, (n.end - n.start) / ppq);
    return {
      midi: n.midi,
      onsetBeats: start,
      durationBeats: duration,
    };
  });
}
