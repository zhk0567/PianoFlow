# OMR audit — `merry_christmas_mr_lawrence`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\merry_christmas_mr_lawrence.pdf`
- MusicXML: `assets\scores\musicxml\merry_christmas_mr_lawrence.musicxml`
- JSON: `assets\scores\merry_christmas_mr_lawrence.json`
- JSON ≡ reparse: **True** (1617/1617 notes)
- BPM JSON/parse: 46 / 100
- keySignature JSON/parse: -5 / -5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=46) — practice tempo may be a catalog default
- 182 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 0.000: 63→76
- right leap 13st @ beat 1.000: 76→63
- right leap 21st @ beat 1.000: 63→84
- right leap 26st @ beat 1.500: 84→58
- right leap 18st @ beat 1.500: 58→76
- right leap 18st @ beat 3.000: 81→63
- right leap 13st @ beat 3.000: 63→76
- right leap 15st @ beat 4.000: 74→59
- right leap 12st @ beat 4.000: 72→84
- right leap 21st @ beat 4.500: 84→63
- right leap 19st @ beat 9.000: 65→46
- right leap 13st @ beat 9.000: 46→59
- right leap 12st @ beat 10.000: 65→53
- right leap 12st @ beat 11.000: 69→57
- right leap 12st @ beat 12.000: 65→77
- right leap 13st @ beat 12.500: 77→64
- right leap 30st @ beat 13.000: 75→45
- right leap 13st @ beat 14.500: 75→62
- right leap 14st @ beat 15.500: 74→60
- right leap 13st @ beat 25.500: 85→72
- right leap 14st @ beat 58.333: 84→70
- right leap 12st @ beat 80.833: 70→58
- right leap 12st @ beat 84.083: 66→54
- right leap 12st @ beat 90.083: 70→58
- right leap 12st @ beat 90.583: 70→58
- right leap 12st @ beat 90.583: 58→70
- right leap 13st @ beat 98.583: 70→57
- right leap 12st @ beat 110.750: 77→65
- right leap 13st @ beat 115.750: 85→72
- right leap 13st @ beat 147.250: 85→72

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
