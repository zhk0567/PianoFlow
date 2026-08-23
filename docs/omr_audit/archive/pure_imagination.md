# OMR audit — `pure_imagination`

- Generated: 2026-08-09 11:54
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\pure_imagination.pdf`
- MusicXML: `assets\scores\musicxml\pure_imagination.musicxml`
- JSON: `assets\scores\pure_imagination.json`
- JSON ≡ reparse: **True** (143/143 notes)
- BPM JSON/parse: 120 / 120
- keySignature JSON/parse: -3 / -3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 9 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 3.000: 62→74
- right leap 17st @ beat 16.000: 65→48
- right leap 12st @ beat 17.000: 48→60
- right leap 12st @ beat 21.000: 46→58
- right leap 16st @ beat 24.000: 51→67
- left leap 12st @ beat 2.000: 46→34
- left leap 29st @ beat 4.000: 34→63
- left leap 12st @ beat 16.000: 58→46
- left leap 17st @ beat 24.000: 46→63

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
