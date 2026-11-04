# OMR audit — `animenz_avid`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_avid.pdf`
- MusicXML: `assets\scores\musicxml\animenz_avid.musicxml`
- JSON: `assets\scores\animenz_avid.json`
- JSON ≡ reparse: **True** (2772/2772 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 3 / 3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 438 same-hand leap(s) ≥12 semitones (OMR risk)
- 3 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1, "('3', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 50.750: 78→66
- right leap 15st @ beat 52.500: 66→81
- right leap 19st @ beat 53.500: 81→62
- right leap 21st @ beat 54.500: 62→83
- right leap 21st @ beat 56.000: 83→62
- right leap 12st @ beat 58.750: 78→66
- right leap 12st @ beat 60.500: 69→81
- right leap 12st @ beat 62.500: 71→83
- right leap 19st @ beat 63.500: 83→64
- right leap 14st @ beat 67.500: 81→67
- right leap 13st @ beat 70.000: 79→66
- right leap 15st @ beat 73.500: 74→59
- right leap 14st @ beat 74.500: 62→76
- right leap 12st @ beat 75.500: 76→64
- right leap 14st @ beat 76.500: 55→69
- right leap 15st @ beat 78.750: 86→71
- right leap 12st @ beat 79.000: 83→71
- right leap 12st @ beat 79.500: 74→86
- right leap 17st @ beat 79.750: 86→69
- right leap 12st @ beat 80.000: 81→69
- right leap 12st @ beat 80.500: 81→93
- right leap 26st @ beat 81.500: 93→67
- right leap 12st @ beat 81.500: 67→79
- right leap 13st @ beat 81.750: 79→66
- right leap 12st @ beat 82.000: 78→66
- right leap 26st @ beat 83.500: 90→64
- right leap 12st @ beat 83.500: 64→76
- right leap 12st @ beat 84.000: 79→67
- right leap 12st @ beat 84.500: 79→91
- right leap 17st @ beat 85.750: 91→74

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
