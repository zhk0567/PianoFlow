# OMR audit — `rimsky_flight_of_the_bumblebee`

- Generated: 2026-07-30 16:53
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\rimsky_flight_of_the_bumblebee.pdf`
- MusicXML: `assets\scores\musicxml\rimsky_flight_of_the_bumblebee.musicxml`
- JSON: `assets\scores\rimsky_flight_of_the_bumblebee.json`
- JSON ≡ reparse: **True** (1165/1165 notes)
- BPM JSON/parse: 160 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=160) — practice tempo may be a catalog default
- 89 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('2', '4')": 3}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 44.250: 69→57
- right leap 12st @ beat 77.750: 62→74
- right leap 17st @ beat 104.500: 59→76
- right leap 12st @ beat 104.500: 76→88
- right leap 16st @ beat 105.000: 88→72
- right leap 12st @ beat 105.000: 72→84
- right leap 15st @ beat 105.500: 84→69
- right leap 12st @ beat 105.500: 69→81
- right leap 16st @ beat 106.000: 81→65
- right leap 12st @ beat 106.000: 65→77
- right leap 12st @ beat 106.500: 69→81
- right leap 12st @ beat 107.000: 72→84
- right leap 12st @ beat 107.500: 76→88
- right leap 12st @ beat 108.500: 88→76
- right leap 12st @ beat 108.500: 76→88
- right leap 16st @ beat 109.000: 88→72
- right leap 12st @ beat 109.000: 72→84
- right leap 15st @ beat 109.500: 84→69
- right leap 12st @ beat 109.500: 69→81
- right leap 16st @ beat 110.000: 81→65
- right leap 12st @ beat 110.000: 65→77
- right leap 12st @ beat 110.500: 69→81
- right leap 12st @ beat 111.000: 72→84
- right leap 12st @ beat 111.500: 76→88
- right leap 23st @ beat 114.750: 88→65
- right leap 42st @ beat 152.625: 87→45
- right leap 28st @ beat 152.625: 60→88
- right leap 35st @ beat 153.125: 87→52
- right leap 26st @ beat 153.125: 60→86
- right leap 42st @ beat 154.625: 87→45

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
