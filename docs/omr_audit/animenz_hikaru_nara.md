# OMR audit — `animenz_hikaru_nara`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_hikaru_nara.pdf`
- MusicXML: `assets\scores\musicxml\animenz_hikaru_nara.musicxml`
- JSON: `assets\scores\animenz_hikaru_nara.json`
- JSON ≡ reparse: **True** (3480/3480 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 3 / 3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 847 same-hand leap(s) ≥12 semitones (OMR risk)
- 15 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 3, "('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 13.000: 70→82
- right leap 14st @ beat 17.000: 88→74
- right leap 12st @ beat 17.000: 74→86
- right leap 13st @ beat 18.000: 86→73
- right leap 13st @ beat 23.000: 93→80
- right leap 12st @ beat 23.000: 80→92
- right leap 13st @ beat 25.000: 93→80
- right leap 12st @ beat 25.000: 80→92
- right leap 12st @ beat 27.000: 83→95
- right leap 16st @ beat 31.000: 97→81
- right leap 12st @ beat 31.000: 81→93
- right leap 19st @ beat 32.000: 93→74
- right leap 20st @ beat 34.000: 86→66
- right leap 12st @ beat 35.000: 86→74
- right leap 12st @ beat 39.000: 85→73
- right leap 19st @ beat 41.000: 83→64
- right leap 14st @ beat 66.000: 78→64
- right leap 12st @ beat 76.000: 88→76
- right leap 12st @ beat 77.750: 81→93
- right leap 12st @ beat 78.000: 93→81
- right leap 12st @ beat 78.000: 81→93
- right leap 16st @ beat 85.500: 85→69
- right leap 17st @ beat 85.500: 69→86
- right leap 13st @ beat 85.750: 86→73
- right leap 19st @ beat 90.250: 88→69
- right leap 12st @ beat 92.250: 88→76
- right leap 19st @ beat 94.250: 88→69
- right leap 17st @ beat 96.250: 88→71
- right leap 19st @ beat 111.250: 69→88
- right leap 17st @ beat 112.250: 85→68

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
