# OMR audit — `haruhikage`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\haruhikage.pdf`
- MusicXML: `assets\scores\musicxml\haruhikage.musicxml`
- JSON: `assets\scores\haruhikage.json`
- JSON ≡ reparse: **True** (1204/1204 notes)
- BPM JSON/parse: 97 / 97
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 380 same-hand leap(s) ≥12 semitones (OMR risk)
- 7 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('6', '8')": 3}`

## Same-hand leaps ≥12st
- right leap 16st @ beat 1.500: 75→59
- right leap 16st @ beat 2.000: 59→75
- right leap 16st @ beat 2.500: 75→59
- right leap 12st @ beat 2.500: 59→71
- right leap 12st @ beat 3.000: 71→59
- right leap 19st @ beat 4.500: 59→78
- right leap 19st @ beat 5.000: 78→59
- right leap 21st @ beat 5.250: 59→80
- right leap 21st @ beat 5.500: 80→59
- right leap 19st @ beat 5.500: 59→78
- right leap 19st @ beat 6.000: 78→59
- right leap 19st @ beat 7.500: 78→59
- right leap 12st @ beat 8.000: 59→71
- right leap 12st @ beat 8.500: 71→59
- right leap 16st @ beat 8.500: 59→75
- right leap 16st @ beat 9.000: 75→59
- right leap 19st @ beat 10.500: 78→59
- right leap 28st @ beat 10.500: 59→87
- right leap 28st @ beat 11.000: 87→59
- right leap 29st @ beat 11.250: 59→88
- right leap 29st @ beat 11.500: 88→59
- right leap 28st @ beat 11.500: 59→87
- right leap 28st @ beat 12.000: 87→59
- right leap 16st @ beat 13.500: 75→59
- right leap 12st @ beat 13.500: 59→71
- right leap 12st @ beat 14.000: 71→59
- right leap 17st @ beat 16.500: 76→59
- right leap 12st @ beat 16.500: 59→71
- right leap 12st @ beat 17.000: 71→59
- right leap 12st @ beat 17.000: 59→71

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
