# OMR audit — `animenz_merry_go_round_of_life`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_merry_go_round_of_life.pdf`
- MusicXML: `assets\scores\musicxml\animenz_merry_go_round_of_life.musicxml`
- JSON: `assets\scores\animenz_merry_go_round_of_life.json`
- JSON ≡ reparse: **True** (3194/3194 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 4 / 4
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 767 same-hand leap(s) ≥12 semitones (OMR risk)
- 37 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('3', '4')": 2}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 42.000: 77→65
- right leap 12st @ beat 68.000: 69→81
- right leap 12st @ beat 96.000: 74→62
- right leap 12st @ beat 96.167: 62→74
- right leap 12st @ beat 96.333: 74→62
- right leap 12st @ beat 96.500: 62→74
- right leap 12st @ beat 96.833: 67→79
- right leap 12st @ beat 97.000: 79→67
- right leap 12st @ beat 97.250: 67→79
- right leap 12st @ beat 97.750: 70→82
- right leap 12st @ beat 98.000: 82→70
- right leap 12st @ beat 98.250: 70→82
- right leap 12st @ beat 99.750: 74→86
- right leap 14st @ beat 102.000: 86→72
- right leap 12st @ beat 102.250: 72→84
- right leap 12st @ beat 102.500: 84→72
- right leap 12st @ beat 102.750: 72→84
- right leap 14st @ beat 103.000: 84→70
- right leap 12st @ beat 103.250: 70→82
- right leap 12st @ beat 103.500: 82→70
- right leap 12st @ beat 103.750: 70→82
- right leap 13st @ beat 104.000: 82→69
- right leap 12st @ beat 104.250: 69→81
- right leap 12st @ beat 104.500: 81→69
- right leap 12st @ beat 104.750: 69→81
- right leap 12st @ beat 105.750: 70→82
- right leap 15st @ beat 108.000: 82→67
- right leap 12st @ beat 108.250: 67→79
- right leap 12st @ beat 108.500: 79→67
- right leap 12st @ beat 108.750: 67→79

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
