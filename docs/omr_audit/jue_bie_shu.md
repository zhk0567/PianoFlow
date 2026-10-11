# OMR audit — `jue_bie_shu`

- Generated: 2026-09-11 19:29
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\jue_bie_shu.pdf`
- MusicXML: `assets\scores\musicxml\jue_bie_shu.musicxml`
- JSON: `assets\scores\jue_bie_shu.json`
- JSON ≡ reparse: **True** (1755/1755 notes)
- BPM JSON/parse: 96 / 96
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 315 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 14st @ beat 24.000: 70→84
- right leap 12st @ beat 96.000: 86→74
- right leap 24st @ beat 128.000: 86→62
- right leap 17st @ beat 159.000: 74→57
- right leap 14st @ beat 160.000: 60→74
- right leap 12st @ beat 191.000: 86→74
- right leap 12st @ beat 191.000: 74→86
- right leap 12st @ beat 191.500: 76→88
- right leap 12st @ beat 192.000: 77→89
- right leap 12st @ beat 195.000: 81→93
- right leap 12st @ beat 196.000: 93→81
- right leap 12st @ beat 196.000: 81→93
- right leap 14st @ beat 197.500: 93→79
- right leap 12st @ beat 197.500: 79→91
- right leap 12st @ beat 198.000: 91→79
- right leap 12st @ beat 198.000: 79→91
- right leap 15st @ beat 200.000: 91→76
- right leap 12st @ beat 200.000: 76→88
- right leap 16st @ beat 201.500: 88→72
- right leap 12st @ beat 201.500: 72→84
- right leap 12st @ beat 202.000: 84→72
- right leap 12st @ beat 202.000: 72→84
- right leap 15st @ beat 204.000: 84→69
- right leap 12st @ beat 204.000: 69→81
- right leap 14st @ beat 205.500: 81→67
- right leap 12st @ beat 205.500: 67→79
- right leap 12st @ beat 206.000: 79→67
- right leap 12st @ beat 206.000: 67→79
- right leap 12st @ beat 208.000: 70→82
- right leap 13st @ beat 210.500: 82→69

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
