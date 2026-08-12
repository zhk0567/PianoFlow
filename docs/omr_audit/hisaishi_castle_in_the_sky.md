# OMR audit — `hisaishi_castle_in_the_sky`

- Generated: 2026-08-09 11:54
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\hisaishi_castle_in_the_sky.pdf`
- MusicXML: `assets\scores\musicxml\hisaishi_castle_in_the_sky.musicxml`
- JSON: `assets\scores\hisaishi_castle_in_the_sky.json`
- JSON ≡ reparse: **True** (213/213 notes)
- BPM JSON/parse: 80 / 80
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 2 same-hand leap(s) ≥12 semitones (OMR risk)
- 1 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- left leap 16st @ beat 80.000: 57→41
- left leap 14st @ beat 84.000: 41→55

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
