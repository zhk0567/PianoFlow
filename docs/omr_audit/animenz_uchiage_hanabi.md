# OMR audit — `animenz_uchiage_hanabi`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_uchiage_hanabi.pdf`
- MusicXML: `assets\scores\musicxml\animenz_uchiage_hanabi.musicxml`
- JSON: `assets\scores\animenz_uchiage_hanabi.json`
- JSON ≡ reparse: **True** (1901/1901 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -6 / -6
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 559 same-hand leap(s) ≥12 semitones (OMR risk)
- 6 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 16.500: 70→82
- right leap 12st @ beat 17.000: 82→70
- right leap 15st @ beat 17.000: 70→85
- right leap 15st @ beat 17.500: 85→70
- right leap 12st @ beat 18.500: 70→82
- right leap 12st @ beat 19.000: 82→70
- right leap 15st @ beat 19.000: 70→85
- right leap 15st @ beat 19.500: 85→70
- right leap 12st @ beat 20.000: 68→80
- right leap 12st @ beat 20.500: 80→68
- right leap 14st @ beat 20.500: 68→82
- right leap 14st @ beat 21.000: 82→68
- right leap 17st @ beat 21.000: 68→85
- right leap 17st @ beat 21.500: 85→68
- right leap 19st @ beat 21.500: 68→87
- right leap 19st @ beat 22.000: 87→68
- right leap 12st @ beat 22.000: 68→80
- right leap 12st @ beat 22.500: 80→68
- right leap 14st @ beat 22.500: 68→82
- right leap 14st @ beat 23.000: 82→68
- right leap 12st @ beat 24.500: 70→82
- right leap 12st @ beat 25.000: 82→70
- right leap 15st @ beat 25.000: 70→85
- right leap 15st @ beat 25.500: 85→70
- right leap 12st @ beat 26.500: 70→82
- right leap 12st @ beat 27.000: 82→70
- right leap 15st @ beat 27.000: 70→85
- right leap 15st @ beat 27.500: 85→70
- right leap 12st @ beat 28.000: 68→80
- right leap 12st @ beat 28.500: 80→68

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
