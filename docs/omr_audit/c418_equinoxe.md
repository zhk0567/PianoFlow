# OMR audit — `c418_equinoxe`

- Generated: 2026-08-04 21:10
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_equinoxe.pdf`
- MusicXML: `assets\scores\musicxml\c418_equinoxe.musicxml`
- JSON: `assets\scores\c418_equinoxe.json`
- JSON ≡ reparse: **True** (233/233 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 79 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('2', '2')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 4.000: 60→72
- right leap 15st @ beat 12.000: 64→79
- right leap 15st @ beat 24.000: 79→64
- right leap 12st @ beat 24.000: 64→76
- right leap 14st @ beat 27.000: 76→62
- right leap 12st @ beat 27.000: 62→74
- right leap 12st @ beat 28.000: 67→79
- right leap 12st @ beat 31.000: 69→81
- right leap 17st @ beat 32.000: 81→64
- right leap 12st @ beat 32.000: 64→76
- right leap 14st @ beat 35.000: 76→62
- right leap 12st @ beat 35.000: 62→74
- right leap 14st @ beat 36.000: 74→60
- right leap 12st @ beat 40.000: 64→76
- right leap 14st @ beat 43.000: 76→62
- right leap 12st @ beat 43.000: 62→74
- right leap 12st @ beat 44.000: 67→79
- right leap 12st @ beat 47.000: 69→81
- right leap 17st @ beat 48.000: 81→64
- right leap 12st @ beat 48.000: 64→76
- right leap 14st @ beat 51.000: 76→62
- right leap 12st @ beat 51.000: 62→74
- right leap 12st @ beat 56.000: 64→76
- right leap 14st @ beat 59.000: 76→62
- right leap 12st @ beat 59.000: 62→74
- right leap 12st @ beat 60.000: 67→79
- right leap 12st @ beat 63.000: 69→81
- right leap 17st @ beat 64.000: 81→64
- right leap 12st @ beat 64.000: 64→76
- right leap 14st @ beat 67.000: 76→62

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
