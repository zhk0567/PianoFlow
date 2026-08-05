# OMR audit — `radwimps_suzume`

- Generated: 2026-08-04 19:37
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\radwimps_suzume.pdf`
- MusicXML: `assets\scores\musicxml\radwimps_suzume.musicxml`
- JSON: `assets\scores\radwimps_suzume.json`
- JSON ≡ reparse: **True** (417/417 notes)
- BPM JSON/parse: 80 / 80
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- 29 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- left leap 12st @ beat 32.000: 57→45
- left leap 12st @ beat 44.000: 50→38
- left leap 14st @ beat 49.750: 57→43
- left leap 14st @ beat 52.000: 55→41
- left leap 13st @ beat 54.000: 53→40
- left leap 14st @ beat 57.750: 57→43
- left leap 14st @ beat 60.000: 55→41
- left leap 13st @ beat 62.000: 53→40
- left leap 14st @ beat 65.833: 57→43
- left leap 14st @ beat 68.000: 55→41
- left leap 13st @ beat 70.000: 53→40
- left leap 14st @ beat 73.750: 57→43
- left leap 14st @ beat 76.000: 55→41
- left leap 13st @ beat 78.000: 53→40
- left leap 14st @ beat 82.000: 57→43
- left leap 14st @ beat 84.000: 55→41
- left leap 13st @ beat 86.000: 53→40
- left leap 14st @ beat 89.750: 57→43
- left leap 14st @ beat 92.000: 55→41
- left leap 13st @ beat 94.000: 53→40
- left leap 14st @ beat 97.750: 57→43
- left leap 14st @ beat 100.000: 55→41
- left leap 13st @ beat 102.000: 53→40
- left leap 14st @ beat 106.000: 57→43
- left leap 14st @ beat 108.000: 55→41
- left leap 13st @ beat 110.000: 53→40
- left leap 14st @ beat 114.000: 57→43
- left leap 14st @ beat 116.000: 55→41
- left leap 13st @ beat 118.000: 53→40

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
