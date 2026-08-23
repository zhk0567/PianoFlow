/** Lightweight MusicXML → note list (same role as Android MusicXmlNotes). */
export function parseMusicXmlNotes(xml) {
  const divMatch = xml.match(/<divisions>\s*(\d+)\s*<\/divisions>/i);
  const divisions = divMatch ? Math.max(1, parseInt(divMatch[1], 10)) : 1;
  const noteBlocks = xml.match(/<note[\s\S]*?<\/note>/gi) || [];
  let cursor = 0;
  const out = [];
  for (const block of noteBlocks) {
    const isChord = /<chord[\s/>]/i.test(block);
    const isRest = /<rest[\s/>]/i.test(block);
    const durMatch = block.match(/<duration>\s*(\d+)\s*<\/duration>/i);
    const dur = (durMatch ? parseInt(durMatch[1], 10) : divisions) / divisions;
    if (isRest) {
      if (!isChord) cursor += dur;
      continue;
    }
    const step = block.match(/<step>\s*([A-G])\s*<\/step>/i)?.[1];
    const octave = parseInt(block.match(/<octave>\s*(-?\d+)\s*<\/octave>/i)?.[1] ?? "", 10);
    const alter = parseInt(block.match(/<alter>\s*(-?\d+)\s*<\/alter>/i)?.[1] ?? "0", 10);
    if (step && Number.isFinite(octave)) {
      const midi = stepToMidi(step, octave, alter);
      const onset = isChord && out.length ? out[out.length - 1].onsetBeats : cursor;
      out.push({ midi, onsetBeats: onset, durationBeats: Math.max(0.05, dur) });
      if (!isChord) cursor += dur;
    } else if (!isChord) {
      cursor += dur;
    }
  }
  return out.sort((a, b) => a.onsetBeats - b.onsetBeats || a.midi - b.midi);
}

function stepToMidi(step, octave, alter) {
  const base = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[step.toUpperCase()] ?? 0;
  return Math.min(108, Math.max(21, (octave + 1) * 12 + base + alter));
}
