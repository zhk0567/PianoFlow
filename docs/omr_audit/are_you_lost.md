# OMR audit — `are_you_lost`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\are_you_lost.pdf`
- MusicXML: `assets\scores\musicxml\are_you_lost.musicxml`
- JSON: `assets\scores\are_you_lost.json`
- JSON ≡ reparse: **True** (1142/1142 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 239 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 19st @ beat 16.000: 58→77
- right leap 13st @ beat 28.333: 67→80
- right leap 12st @ beat 36.667: 75→63
- right leap 15st @ beat 41.750: 72→87
- right leap 12st @ beat 46.167: 77→89
- right leap 12st @ beat 49.750: 87→75
- right leap 15st @ beat 52.000: 82→67
- right leap 16st @ beat 53.000: 75→91
- right leap 21st @ beat 53.250: 91→70
- right leap 15st @ beat 53.250: 70→85
- right leap 13st @ beat 53.500: 85→72
- right leap 15st @ beat 57.750: 72→87
- right leap 12st @ beat 61.000: 72→84
- right leap 19st @ beat 61.250: 84→65
- right leap 17st @ beat 61.750: 80→63
- right leap 12st @ beat 61.750: 63→75
- right leap 14st @ beat 62.500: 82→68
- right leap 14st @ beat 63.500: 68→82
- right leap 17st @ beat 64.000: 82→65
- right leap 12st @ beat 66.000: 72→84
- right leap 16st @ beat 66.250: 84→68
- right leap 12st @ beat 66.250: 68→80
- right leap 17st @ beat 66.750: 80→63
- right leap 12st @ beat 66.750: 63→75
- right leap 12st @ beat 67.000: 65→77
- right leap 14st @ beat 68.500: 68→82
- right leap 14st @ beat 69.250: 82→68
- right leap 14st @ beat 69.250: 68→82
- right leap 13st @ beat 69.750: 80→67
- right leap 12st @ beat 70.000: 70→82

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
