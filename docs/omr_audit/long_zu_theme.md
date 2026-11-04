# OMR audit — `long_zu_theme`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\long_zu_theme.pdf`
- MusicXML: `assets\scores\musicxml\long_zu_theme.musicxml`
- JSON: `assets\scores\long_zu_theme.json`
- JSON ≡ reparse: **True** (2994/2994 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 1098 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 19st @ beat 16.500: 78→59
- right leap 24st @ beat 16.500: 59→83
- right leap 21st @ beat 17.000: 83→62
- right leap 12st @ beat 50.500: 67→79
- right leap 27st @ beat 51.500: 86→59
- right leap 16st @ beat 54.500: 62→78
- right leap 29st @ beat 55.500: 86→57
- right leap 12st @ beat 63.500: 64→76
- right leap 16st @ beat 65.000: 83→67
- right leap 12st @ beat 65.000: 67→79
- right leap 15st @ beat 65.500: 79→64
- right leap 12st @ beat 65.500: 64→76
- right leap 12st @ beat 66.500: 81→69
- right leap 12st @ beat 66.500: 69→81
- right leap 12st @ beat 66.750: 81→69
- right leap 12st @ beat 66.750: 69→81
- right leap 12st @ beat 67.000: 81→69
- right leap 12st @ beat 67.000: 69→81
- right leap 17st @ beat 67.500: 81→64
- right leap 12st @ beat 67.500: 64→76
- right leap 12st @ beat 68.000: 76→64
- right leap 12st @ beat 68.000: 64→76
- right leap 17st @ beat 69.875: 81→64
- right leap 12st @ beat 69.875: 64→76
- right leap 14st @ beat 70.000: 76→62
- right leap 12st @ beat 70.000: 62→74
- right leap 12st @ beat 70.500: 64→76
- right leap 12st @ beat 71.000: 67→79
- right leap 12st @ beat 71.500: 69→81
- right leap 16st @ beat 72.750: 83→67

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
