# OMR audit — `sawano_call_of_silence`

- Generated: 2026-08-04 19:37
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\sawano_call_of_silence.pdf`
- MusicXML: `assets\scores\musicxml\sawano_call_of_silence.musicxml`
- JSON: `assets\scores\sawano_call_of_silence.json`
- JSON ≡ reparse: **True** (605/605 notes)
- BPM JSON/parse: 60 / 60
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- 103 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 15st @ beat 39.000: 72→57
- right leap 12st @ beat 75.125: 69→81
- right leap 12st @ beat 88.875: 88→76
- right leap 12st @ beat 114.375: 76→88
- right leap 14st @ beat 114.875: 88→74
- right leap 12st @ beat 114.875: 74→86
- right leap 12st @ beat 115.375: 86→74
- right leap 12st @ beat 115.375: 74→86
- right leap 14st @ beat 115.875: 86→72
- right leap 12st @ beat 115.875: 72→84
- right leap 12st @ beat 116.375: 84→72
- right leap 12st @ beat 116.375: 72→84
- right leap 12st @ beat 116.875: 79→91
- right leap 19st @ beat 117.375: 91→72
- right leap 12st @ beat 117.375: 72→84
- right leap 13st @ beat 118.375: 84→71
- right leap 12st @ beat 118.375: 71→83
- right leap 12st @ beat 118.875: 72→84
- right leap 12st @ beat 119.375: 84→72
- right leap 12st @ beat 119.375: 72→84
- right leap 12st @ beat 122.375: 76→88
- right leap 14st @ beat 122.875: 88→74
- right leap 12st @ beat 122.875: 74→86
- right leap 12st @ beat 123.375: 86→74
- right leap 12st @ beat 123.375: 74→86
- right leap 14st @ beat 123.875: 86→72
- right leap 12st @ beat 123.875: 72→84
- right leap 19st @ beat 124.375: 84→65
- right leap 14st @ beat 124.375: 65→79
- right leap 12st @ beat 124.875: 76→88

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
