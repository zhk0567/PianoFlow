# OMR audit — `radwimps_suzume`

- Generated: 2026-10-18 15:38
- scoreKind: **formal**
- PDF: `third_party\scores_pdf\radwimps_suzume.pdf`
- MusicXML: `assets\scores\musicxml\radwimps_suzume.musicxml`
- JSON: `assets\scores\radwimps_suzume.json`
- JSON ≡ reparse: **True** (428/428 notes)
- BPM JSON/parse: 80 / 80
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- already formal — audit is informational only
- 29 same-hand leap(s) ≥12 semitones (OMR risk)
- 2 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 17st @ beat 92.000: 60→77
- left leap 12st @ beat 44.250: 50→38
- left leap 13st @ beat 54.000: 53→40
- left leap 14st @ beat 60.000: 55→41
- left leap 16st @ beat 60.167: 41→57
- left leap 13st @ beat 62.000: 53→40
- left leap 14st @ beat 66.000: 57→43
- left leap 14st @ beat 68.000: 55→41
- left leap 13st @ beat 70.000: 53→40
- left leap 14st @ beat 74.000: 57→43
- left leap 14st @ beat 76.000: 55→41
- left leap 13st @ beat 78.000: 53→40
- left leap 12st @ beat 81.000: 43→55
- left leap 16st @ beat 82.000: 59→43
- left leap 12st @ beat 83.000: 43→55
- left leap 12st @ beat 85.000: 48→60
- left leap 21st @ beat 86.000: 64→43
- left leap 17st @ beat 87.000: 43→60
- left leap 14st @ beat 88.000: 64→50
- left leap 12st @ beat 89.000: 50→62
- left leap 15st @ beat 90.000: 65→50
- left leap 12st @ beat 91.000: 50→62
- left leap 22st @ beat 92.000: 65→43
- left leap 12st @ beat 100.000: 55→43
- left leap 13st @ beat 106.000: 53→40
- left leap 14st @ beat 110.000: 57→43
- left leap 14st @ beat 112.000: 55→41
- left leap 13st @ beat 114.000: 53→40
- left leap 13st @ beat 118.000: 53→40

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
