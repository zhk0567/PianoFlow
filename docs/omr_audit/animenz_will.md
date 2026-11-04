# OMR audit — `animenz_will`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_will.pdf`
- MusicXML: `assets\scores\musicxml\animenz_will.musicxml`
- JSON: `assets\scores\animenz_will.json`
- JSON ≡ reparse: **True** (2638/2638 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 585 same-hand leap(s) ≥12 semitones (OMR risk)
- 18 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 10.000: 77→65
- right leap 12st @ beat 17.000: 77→89
- right leap 17st @ beat 18.000: 89→72
- right leap 12st @ beat 21.500: 72→84
- right leap 12st @ beat 22.000: 84→72
- right leap 12st @ beat 22.000: 72→84
- right leap 14st @ beat 24.000: 84→70
- right leap 12st @ beat 25.500: 75→87
- right leap 12st @ beat 26.000: 87→75
- right leap 12st @ beat 26.000: 75→87
- right leap 13st @ beat 26.500: 87→74
- right leap 12st @ beat 26.500: 74→86
- right leap 16st @ beat 27.500: 86→70
- right leap 12st @ beat 32.000: 82→70
- right leap 12st @ beat 35.000: 82→70
- right leap 12st @ beat 73.500: 77→65
- right leap 12st @ beat 75.500: 65→77
- right leap 12st @ beat 78.500: 70→82
- right leap 12st @ beat 80.000: 84→72
- right leap 26st @ beat 80.500: 84→58
- right leap 12st @ beat 83.500: 85→73
- right leap 12st @ beat 83.500: 73→85
- right leap 12st @ beat 84.000: 85→73
- right leap 13st @ beat 85.500: 85→72
- right leap 12st @ beat 85.500: 72→84
- right leap 16st @ beat 85.750: 84→68
- right leap 12st @ beat 86.000: 80→68
- right leap 12st @ beat 87.500: 80→68
- right leap 12st @ beat 87.500: 68→80
- right leap 14st @ beat 89.000: 82→68

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
