# OMR audit — `christina_perri_a_thousand_years`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\christina_perri_a_thousand_years.pdf`
- MusicXML: `assets\scores\musicxml\christina_perri_a_thousand_years.musicxml`
- JSON: `assets\scores\christina_perri_a_thousand_years.json`
- JSON ≡ reparse: **True** (954/954 notes)
- BPM JSON/parse: 50 / 50
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 8 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('6', '8')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 63.000: 67→79
- right leap 12st @ beat 138.000: 67→79
- left leap 12st @ beat 25.500: 53→41
- left leap 12st @ beat 27.000: 53→41
- left leap 12st @ beat 28.500: 53→41
- left leap 12st @ beat 37.500: 55→43
- left leap 12st @ beat 45.000: 53→41
- left leap 14st @ beat 117.000: 65→51

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
