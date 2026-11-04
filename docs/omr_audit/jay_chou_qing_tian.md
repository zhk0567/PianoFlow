# OMR audit — `jay_chou_qing_tian`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\jay_chou_qing_tian.pdf`
- MusicXML: `assets\scores\musicxml\jay_chou_qing_tian.musicxml`
- JSON: `assets\scores\jay_chou_qing_tian.json`
- JSON ≡ reparse: **True** (1131/1131 notes)
- BPM JSON/parse: 68 / 68
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 95 same-hand leap(s) ≥12 semitones (OMR risk)
- 19 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 19st @ beat 28.000: 74→55
- right leap 12st @ beat 40.500: 62→74
- left leap 19st @ beat 2.000: 59→40
- left leap 19st @ beat 4.000: 55→36
- left leap 14st @ beat 6.000: 52→38
- left leap 19st @ beat 10.000: 59→40
- left leap 12st @ beat 12.000: 55→43
- left leap 16st @ beat 16.000: 59→43
- left leap 12st @ beat 36.000: 55→43
- left leap 12st @ beat 37.000: 50→62
- left leap 12st @ beat 38.000: 55→43
- left leap 19st @ beat 38.500: 43→62
- left leap 20st @ beat 39.000: 62→42
- left leap 20st @ beat 39.500: 42→62
- left leap 12st @ beat 44.000: 55→43
- left leap 12st @ beat 45.000: 50→62
- left leap 12st @ beat 46.000: 55→43
- left leap 19st @ beat 46.500: 43→62
- left leap 20st @ beat 47.000: 62→42
- left leap 12st @ beat 52.000: 55→43
- left leap 12st @ beat 53.000: 50→62
- left leap 12st @ beat 54.000: 55→43
- left leap 19st @ beat 54.500: 43→62
- left leap 20st @ beat 55.000: 62→42
- left leap 20st @ beat 55.500: 42→62
- left leap 12st @ beat 60.000: 55→43
- left leap 12st @ beat 61.000: 50→62
- left leap 12st @ beat 62.000: 55→43
- left leap 19st @ beat 62.500: 43→62
- left leap 20st @ beat 63.000: 62→42

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
