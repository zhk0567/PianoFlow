# OMR audit — `c418_clark_alt`

- Generated: 2026-08-04 21:14
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_clark_alt.pdf`
- MusicXML: `assets\scores\musicxml\c418_clark_alt.musicxml`
- JSON: `assets\scores\c418_clark_alt.json`
- JSON ≡ reparse: **True** (323/323 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 23 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 80.000: 67→55
- right leap 19st @ beat 88.000: 72→53
- right leap 13st @ beat 116.000: 77→64
- right leap 12st @ beat 116.000: 64→76
- right leap 19st @ beat 120.000: 72→53
- right leap 15st @ beat 136.000: 74→59
- right leap 19st @ beat 145.500: 64→83
- right leap 19st @ beat 152.000: 72→53
- left leap 15st @ beat 64.000: 53→38
- left leap 12st @ beat 72.000: 40→52
- left leap 12st @ beat 75.000: 55→43
- left leap 14st @ beat 76.000: 43→57
- left leap 17st @ beat 80.000: 57→40
- left leap 12st @ beat 104.000: 40→52
- left leap 12st @ beat 107.000: 55→43
- left leap 14st @ beat 108.000: 43→57
- left leap 17st @ beat 112.000: 57→40
- left leap 12st @ beat 112.000: 40→52
- left leap 12st @ beat 136.000: 40→52
- left leap 12st @ beat 139.000: 55→43
- left leap 14st @ beat 140.000: 43→57
- left leap 17st @ beat 144.000: 57→40
- left leap 13st @ beat 160.000: 40→53

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
