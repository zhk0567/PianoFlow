# OMR audit — `radwimps_suzume`

- Generated: 2026-07-30 16:53
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\radwimps_suzume.pdf`
- MusicXML: `assets\scores\musicxml\radwimps_suzume.musicxml`
- JSON: `assets\scores\radwimps_suzume.json`
- JSON ≡ reparse: **True** (417/417 notes)
- BPM JSON/parse: 90 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=90) — practice tempo may be a catalog default
- 29 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- left leap 12st @ beat 31.333: 57→45
- left leap 12st @ beat 43.083: 50→38
- left leap 14st @ beat 48.583: 57→43
- left leap 14st @ beat 50.583: 55→41
- left leap 13st @ beat 52.583: 53→40
- left leap 14st @ beat 56.333: 57→43
- left leap 14st @ beat 58.333: 55→41
- left leap 13st @ beat 60.333: 53→40
- left leap 14st @ beat 64.167: 57→43
- left leap 14st @ beat 66.083: 55→41
- left leap 13st @ beat 68.083: 53→40
- left leap 14st @ beat 71.833: 57→43
- left leap 14st @ beat 73.833: 55→41
- left leap 13st @ beat 75.833: 53→40
- left leap 14st @ beat 79.500: 57→43
- left leap 14st @ beat 81.500: 55→41
- left leap 13st @ beat 83.500: 53→40
- left leap 14st @ beat 87.250: 57→43
- left leap 14st @ beat 89.250: 55→41
- left leap 13st @ beat 91.250: 53→40
- left leap 14st @ beat 95.000: 57→43
- left leap 14st @ beat 97.000: 55→41
- left leap 13st @ beat 99.000: 53→40
- left leap 14st @ beat 102.750: 57→43
- left leap 14st @ beat 104.750: 55→41
- left leap 13st @ beat 106.750: 53→40
- left leap 14st @ beat 110.750: 57→43
- left leap 14st @ beat 112.750: 55→41
- left leap 13st @ beat 114.750: 53→40

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
