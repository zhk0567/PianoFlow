# OMR audit — `animenz_unravel`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_unravel.pdf`
- MusicXML: `assets\scores\musicxml\animenz_unravel.musicxml`
- JSON: `assets\scores\animenz_unravel.json`
- JSON ≡ reparse: **True** (3765/3765 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 835 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 16.000: 74→62
- right leap 12st @ beat 16.000: 62→74
- right leap 12st @ beat 16.500: 74→62
- right leap 12st @ beat 17.500: 74→62
- right leap 12st @ beat 17.500: 62→74
- right leap 12st @ beat 18.000: 74→62
- right leap 12st @ beat 18.500: 74→62
- right leap 12st @ beat 19.000: 74→86
- right leap 12st @ beat 19.500: 86→74
- right leap 12st @ beat 20.500: 86→74
- right leap 16st @ beat 24.000: 86→70
- right leap 12st @ beat 24.000: 70→82
- right leap 13st @ beat 24.500: 82→69
- right leap 12st @ beat 25.500: 81→69
- right leap 12st @ beat 25.500: 69→81
- right leap 12st @ beat 26.000: 81→69
- right leap 12st @ beat 26.500: 81→69
- right leap 12st @ beat 27.000: 70→82
- right leap 12st @ beat 27.500: 82→70
- right leap 12st @ beat 27.500: 70→82
- right leap 12st @ beat 28.500: 82→70
- right leap 12st @ beat 28.500: 70→82
- right leap 12st @ beat 33.000: 84→72
- right leap 12st @ beat 34.000: 82→70
- right leap 12st @ beat 34.500: 69→81
- right leap 12st @ beat 35.500: 79→67
- right leap 17st @ beat 36.000: 67→84
- right leap 12st @ beat 36.500: 84→72
- right leap 12st @ beat 36.500: 72→84
- right leap 12st @ beat 37.500: 82→70

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
