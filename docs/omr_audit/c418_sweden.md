# OMR audit — `c418_sweden`

- Generated: 2026-08-04 21:12
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_sweden.pdf`
- MusicXML: `assets\scores\musicxml\c418_sweden.musicxml`
- JSON: `assets\scores\c418_sweden.json`
- JSON ≡ reparse: **True** (281/281 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 2 / 2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 43 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 12.000: 66→54
- right leap 12st @ beat 16.000: 64→52
- right leap 12st @ beat 20.000: 66→54
- right leap 12st @ beat 24.000: 64→52
- right leap 14st @ beat 26.000: 71→57
- right leap 12st @ beat 30.000: 69→57
- right leap 12st @ beat 32.000: 64→52
- right leap 15st @ beat 32.500: 59→74
- right leap 12st @ beat 34.000: 69→57
- right leap 14st @ beat 40.000: 66→52
- right leap 15st @ beat 44.000: 76→61
- right leap 16st @ beat 46.000: 73→57
- right leap 17st @ beat 48.000: 69→52
- right leap 12st @ beat 49.000: 59→71
- right leap 12st @ beat 50.000: 69→57
- right leap 12st @ beat 54.000: 69→57
- right leap 12st @ beat 56.000: 64→52
- right leap 14st @ beat 58.000: 71→57
- right leap 12st @ beat 62.000: 69→57
- right leap 12st @ beat 64.000: 64→52
- right leap 12st @ beat 67.500: 74→62
- right leap 12st @ beat 70.000: 69→57
- right leap 14st @ beat 78.000: 64→50
- right leap 17st @ beat 80.000: 59→42
- right leap 13st @ beat 83.500: 42→55
- right leap 12st @ beat 85.500: 74→62
- right leap 14st @ beat 85.500: 62→76
- right leap 12st @ beat 85.750: 76→64
- right leap 12st @ beat 88.000: 71→59
- left leap 14st @ beat 42.000: 43→57

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
