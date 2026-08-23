# OMR audit — `clayderman_reve_damour`

- Generated: 2026-08-09 11:54
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\clayderman_reve_damour.pdf`
- MusicXML: `assets\scores\musicxml\clayderman_reve_damour.musicxml`
- JSON: `assets\scores\clayderman_reve_damour.json`
- JSON ≡ reparse: **True** (1104/1104 notes)
- BPM JSON/parse: 72 / 72
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 250 same-hand leap(s) ≥12 semitones (OMR risk)
- 2 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 17.000: 74→86
- right leap 12st @ beat 20.000: 86→74
- right leap 12st @ beat 63.500: 70→82
- right leap 12st @ beat 64.000: 82→70
- right leap 12st @ beat 64.000: 70→82
- right leap 12st @ beat 64.250: 82→70
- right leap 12st @ beat 64.250: 70→82
- right leap 12st @ beat 64.500: 82→70
- right leap 12st @ beat 64.500: 70→82
- right leap 12st @ beat 64.750: 72→84
- right leap 12st @ beat 65.000: 84→72
- right leap 12st @ beat 65.000: 72→84
- right leap 14st @ beat 65.750: 84→70
- right leap 12st @ beat 65.750: 70→82
- right leap 13st @ beat 66.000: 82→69
- right leap 12st @ beat 66.000: 69→81
- right leap 14st @ beat 66.250: 81→67
- right leap 12st @ beat 66.250: 67→79
- right leap 14st @ beat 66.500: 79→65
- right leap 12st @ beat 66.500: 65→77
- right leap 12st @ beat 67.250: 77→65
- right leap 12st @ beat 67.250: 65→77
- right leap 12st @ beat 67.500: 67→79
- right leap 14st @ beat 67.750: 79→65
- right leap 12st @ beat 67.750: 65→77
- right leap 15st @ beat 68.000: 77→62
- right leap 12st @ beat 68.000: 62→74
- right leap 12st @ beat 69.500: 70→82
- right leap 12st @ beat 70.000: 82→70
- right leap 12st @ beat 70.000: 70→82

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
