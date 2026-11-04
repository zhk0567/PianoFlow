# OMR audit — `sincerely_violet_evergarden`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\sincerely_violet_evergarden.pdf`
- MusicXML: `assets\scores\musicxml\sincerely_violet_evergarden.musicxml`
- JSON: `assets\scores\sincerely_violet_evergarden.json`
- JSON ≡ reparse: **True** (4405/4405 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 907 same-hand leap(s) ≥12 semitones (OMR risk)
- 9 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 4.000: 84→72
- right leap 12st @ beat 32.000: 77→65
- right leap 12st @ beat 39.000: 65→77
- right leap 16st @ beat 48.000: 81→65
- right leap 12st @ beat 60.000: 79→67
- right leap 12st @ beat 68.000: 81→69
- right leap 12st @ beat 72.000: 81→69
- right leap 12st @ beat 76.000: 81→69
- right leap 12st @ beat 84.500: 86→74
- right leap 12st @ beat 92.500: 86→74
- right leap 14st @ beat 96.500: 88→74
- right leap 12st @ beat 100.500: 86→74
- right leap 19st @ beat 112.500: 93→74
- right leap 12st @ beat 116.500: 86→74
- right leap 12st @ beat 120.500: 86→74
- right leap 12st @ beat 124.500: 86→74
- right leap 12st @ beat 129.000: 86→74
- right leap 12st @ beat 132.500: 86→74
- right leap 12st @ beat 136.500: 86→74
- right leap 12st @ beat 141.000: 78→66
- right leap 12st @ beat 144.000: 64→76
- right leap 14st @ beat 145.000: 76→62
- right leap 19st @ beat 150.000: 62→81
- right leap 24st @ beat 151.500: 81→57
- right leap 12st @ beat 152.000: 64→76
- right leap 14st @ beat 153.000: 76→62
- right leap 19st @ beat 158.000: 62→81
- right leap 24st @ beat 159.500: 81→57
- right leap 12st @ beat 166.500: 74→62
- right leap 14st @ beat 166.500: 62→76

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
