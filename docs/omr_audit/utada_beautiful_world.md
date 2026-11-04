# OMR audit — `utada_beautiful_world`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\utada_beautiful_world.pdf`
- MusicXML: `assets\scores\musicxml\utada_beautiful_world.musicxml`
- JSON: `assets\scores\utada_beautiful_world.json`
- JSON ≡ reparse: **True** (2765/2765 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 784 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 32.000: 77→65
- right leap 14st @ beat 48.000: 79→65
- right leap 13st @ beat 65.000: 89→76
- right leap 19st @ beat 66.000: 88→69
- right leap 12st @ beat 66.750: 81→69
- right leap 12st @ beat 67.000: 81→69
- right leap 12st @ beat 68.000: 84→72
- right leap 15st @ beat 68.500: 84→69
- right leap 12st @ beat 69.000: 81→69
- right leap 16st @ beat 70.000: 81→65
- right leap 12st @ beat 70.000: 65→77
- right leap 12st @ beat 70.500: 67→79
- right leap 12st @ beat 71.000: 69→81
- right leap 12st @ beat 71.500: 70→82
- right leap 13st @ beat 71.750: 82→69
- right leap 12st @ beat 71.750: 69→81
- right leap 13st @ beat 73.000: 89→76
- right leap 19st @ beat 74.000: 88→69
- right leap 12st @ beat 74.750: 81→69
- right leap 12st @ beat 75.000: 81→69
- right leap 12st @ beat 76.000: 84→72
- right leap 15st @ beat 77.000: 84→69
- right leap 12st @ beat 77.000: 69→81
- right leap 12st @ beat 77.500: 81→69
- right leap 12st @ beat 77.500: 69→81
- right leap 12st @ beat 78.000: 74→86
- right leap 17st @ beat 78.750: 86→69
- right leap 12st @ beat 78.750: 69→81
- right leap 12st @ beat 79.000: 81→69
- right leap 12st @ beat 79.000: 69→81

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
