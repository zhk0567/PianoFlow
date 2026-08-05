# OMR audit — `c418_mice_on_venus`

- Generated: 2026-08-04 21:10
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_mice_on_venus.pdf`
- MusicXML: `assets\scores\musicxml\c418_mice_on_venus.musicxml`
- JSON: `assets\scores\c418_mice_on_venus.json`
- JSON ≡ reparse: **True** (734/734 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 45 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 12.000: 72→60
- right leap 14st @ beat 28.000: 79→65
- right leap 24st @ beat 46.000: 79→55
- right leap 17st @ beat 48.000: 59→76
- right leap 24st @ beat 62.000: 77→53
- right leap 22st @ beat 64.000: 57→79
- right leap 16st @ beat 80.500: 88→72
- right leap 12st @ beat 81.000: 67→79
- right leap 21st @ beat 81.250: 88→67
- right leap 14st @ beat 81.500: 72→86
- right leap 12st @ beat 82.500: 84→72
- right leap 17st @ beat 83.250: 84→67
- right leap 14st @ beat 83.750: 72→86
- right leap 14st @ beat 84.000: 86→72
- right leap 16st @ beat 86.500: 88→72
- right leap 14st @ beat 87.500: 72→86
- right leap 12st @ beat 88.500: 84→72
- right leap 12st @ beat 90.500: 84→72
- right leap 12st @ beat 92.500: 84→72
- right leap 14st @ beat 93.000: 67→81
- right leap 14st @ beat 93.250: 81→67
- right leap 12st @ beat 94.500: 84→72
- right leap 17st @ beat 97.000: 67→84
- right leap 17st @ beat 97.250: 84→67
- right leap 12st @ beat 100.000: 79→67
- right leap 12st @ beat 252.500: 74→62
- right leap 12st @ beat 253.500: 72→60
- right leap 12st @ beat 254.500: 71→59
- right leap 12st @ beat 255.500: 69→57
- right leap 12st @ beat 268.500: 74→62

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
