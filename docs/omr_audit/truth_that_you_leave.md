# OMR audit — `truth_that_you_leave`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\truth_that_you_leave.pdf`
- MusicXML: `assets\scores\musicxml\truth_that_you_leave.musicxml`
- JSON: `assets\scores\truth_that_you_leave.json`
- JSON ≡ reparse: **True** (1397/1397 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 278 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 19st @ beat 26.500: 77→58
- right leap 16st @ beat 102.000: 74→58
- right leap 20st @ beat 150.000: 79→59
- right leap 14st @ beat 156.750: 77→63
- right leap 12st @ beat 160.750: 77→65
- right leap 12st @ beat 183.250: 74→62
- right leap 12st @ beat 201.250: 81→69
- right leap 20st @ beat 277.750: 79→59
- right leap 22st @ beat 283.500: 77→55
- right leap 36st @ beat 284.500: 55→91
- right leap 12st @ beat 285.500: 91→79
- right leap 12st @ beat 285.500: 79→91
- right leap 12st @ beat 286.000: 91→79
- right leap 12st @ beat 286.000: 79→91
- right leap 12st @ beat 287.500: 91→79
- right leap 12st @ beat 289.500: 79→91
- right leap 12st @ beat 290.000: 91→79
- right leap 12st @ beat 290.000: 79→91
- right leap 24st @ beat 291.500: 91→67
- right leap 12st @ beat 301.500: 79→91
- right leap 12st @ beat 302.000: 91→79
- right leap 12st @ beat 302.000: 79→91
- right leap 12st @ beat 303.500: 91→79
- right leap 12st @ beat 305.500: 79→91
- right leap 12st @ beat 306.000: 91→79
- right leap 12st @ beat 306.000: 79→91
- right leap 24st @ beat 307.500: 91→67
- right leap 16st @ beat 313.000: 76→60
- right leap 12st @ beat 317.500: 67→79
- right leap 12st @ beat 318.000: 79→67

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
