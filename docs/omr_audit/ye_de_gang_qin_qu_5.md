# OMR audit — `ye_de_gang_qin_qu_5`

- Generated: 2026-08-05 20:31
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\ye_de_gang_qin_qu_5.pdf`
- MusicXML: `assets\scores\musicxml\ye_de_gang_qin_qu_5.musicxml`
- JSON: `assets\scores\ye_de_gang_qin_qu_5.json`
- JSON ≡ reparse: **True** (118/118 notes)
- BPM JSON/parse: 120 / 120
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 3 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 6.000: 81→69
- right leap 21st @ beat 16.000: 81→60
- left leap 13st @ beat 16.000: 52→65

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
