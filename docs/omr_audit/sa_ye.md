# OMR audit — `sa_ye`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\sa_ye.pdf`
- MusicXML: `assets\scores\musicxml\sa_ye.musicxml`
- JSON: `assets\scores\sa_ye.json`
- JSON ≡ reparse: **True** (1777/1777 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 2 / 2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 388 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 3, "('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 79.000: 78→66
- right leap 12st @ beat 82.000: 71→83
- right leap 14st @ beat 82.500: 83→69
- right leap 12st @ beat 82.500: 69→81
- right leap 12st @ beat 83.000: 81→69
- right leap 12st @ beat 83.000: 69→81
- right leap 15st @ beat 83.500: 81→66
- right leap 12st @ beat 83.500: 66→78
- right leap 14st @ beat 84.500: 78→64
- right leap 12st @ beat 84.500: 64→76
- right leap 12st @ beat 85.000: 76→64
- right leap 12st @ beat 85.000: 64→76
- right leap 12st @ beat 96.000: 78→66
- right leap 12st @ beat 98.000: 71→83
- right leap 12st @ beat 98.500: 73→85
- right leap 12st @ beat 99.000: 85→73
- right leap 12st @ beat 99.000: 73→85
- right leap 12st @ beat 99.500: 85→73
- right leap 12st @ beat 113.500: 71→83
- right leap 12st @ beat 114.500: 73→85
- right leap 12st @ beat 115.000: 85→73
- right leap 12st @ beat 115.000: 73→85
- right leap 12st @ beat 115.500: 74→86
- right leap 13st @ beat 116.500: 86→73
- right leap 12st @ beat 117.500: 74→86
- right leap 12st @ beat 118.500: 76→88
- right leap 12st @ beat 119.000: 88→76
- right leap 12st @ beat 119.000: 76→88
- right leap 15st @ beat 119.500: 88→73
- right leap 12st @ beat 119.500: 73→85

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
