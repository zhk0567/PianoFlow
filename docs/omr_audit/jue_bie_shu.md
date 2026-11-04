# OMR audit — `jue_bie_shu`

- Generated: 2026-10-18 09:45
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\jue_bie_shu.pdf`
- MusicXML: `assets\scores\musicxml\jue_bie_shu.musicxml`
- JSON: `assets\scores\jue_bie_shu.json`
- JSON ≡ reparse: **True** (1397/1397 notes)
- BPM JSON/parse: 96 / 100
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=96) — practice tempo may be a catalog default
- 201 same-hand leap(s) ≥12 semitones (OMR risk)
- 3 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '3', None), ('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 96.000: 86→74
- right leap 24st @ beat 128.000: 86→62
- right leap 14st @ beat 133.000: 67→81
- right leap 14st @ beat 133.500: 81→67
- right leap 12st @ beat 133.500: 67→79
- right leap 19st @ beat 134.000: 79→60
- right leap 12st @ beat 191.000: 86→74
- right leap 12st @ beat 191.000: 74→86
- right leap 12st @ beat 191.500: 76→88
- right leap 12st @ beat 192.000: 77→89
- right leap 12st @ beat 195.000: 81→93
- right leap 12st @ beat 196.000: 93→81
- right leap 12st @ beat 196.000: 81→93
- right leap 15st @ beat 200.000: 91→76
- right leap 12st @ beat 204.000: 69→81
- right leap 13st @ beat 210.500: 82→69
- right leap 12st @ beat 211.000: 81→69
- right leap 14st @ beat 211.500: 81→67
- right leap 12st @ beat 214.000: 82→70
- right leap 13st @ beat 215.000: 82→69
- right leap 12st @ beat 215.000: 69→81
- right leap 14st @ beat 216.000: 81→67
- right leap 12st @ beat 219.500: 77→65
- right leap 12st @ beat 223.000: 74→86
- right leap 12st @ beat 223.500: 76→88
- right leap 12st @ beat 224.000: 77→89
- right leap 15st @ beat 226.500: 89→74
- right leap 12st @ beat 226.500: 74→86
- right leap 12st @ beat 227.000: 76→88
- right leap 12st @ beat 227.500: 77→89

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
