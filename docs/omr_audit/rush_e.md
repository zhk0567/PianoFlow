# OMR audit — `rush_e`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\rush_e.pdf`
- MusicXML: `assets\scores\musicxml\rush_e.musicxml`
- JSON: `assets\scores\rush_e.json`
- JSON ≡ reparse: **True** (877/877 notes)
- BPM JSON/parse: 40 / 40
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 222 same-hand leap(s) ≥12 semitones (OMR risk)
- 6 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 7.125: 64→76
- right leap 12st @ beat 7.250: 76→64
- right leap 12st @ beat 7.375: 64→76
- right leap 12st @ beat 7.500: 76→64
- right leap 12st @ beat 7.625: 64→76
- right leap 12st @ beat 7.750: 76→64
- right leap 12st @ beat 7.875: 64→76
- right leap 12st @ beat 8.125: 76→88
- right leap 12st @ beat 8.250: 88→76
- right leap 12st @ beat 8.375: 76→88
- right leap 12st @ beat 8.500: 88→76
- right leap 12st @ beat 8.625: 76→88
- right leap 12st @ beat 8.750: 88→76
- right leap 12st @ beat 8.875: 76→88
- right leap 12st @ beat 9.000: 88→76
- right leap 12st @ beat 9.125: 76→88
- right leap 12st @ beat 9.250: 88→76
- right leap 12st @ beat 9.375: 76→88
- right leap 12st @ beat 9.500: 88→76
- right leap 12st @ beat 9.625: 76→88
- right leap 12st @ beat 9.750: 88→76
- right leap 12st @ beat 9.875: 76→88
- right leap 24st @ beat 10.000: 88→64
- right leap 12st @ beat 10.125: 64→76
- right leap 12st @ beat 10.250: 76→64
- right leap 12st @ beat 10.375: 64→76
- right leap 12st @ beat 10.500: 76→64
- right leap 12st @ beat 10.625: 64→76
- right leap 12st @ beat 10.750: 76→64
- right leap 12st @ beat 10.875: 64→76

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
