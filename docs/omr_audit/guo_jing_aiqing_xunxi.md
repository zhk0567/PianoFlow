# OMR audit — `guo_jing_aiqing_xunxi`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\guo_jing_aiqing_xunxi.pdf`
- MusicXML: `assets\scores\musicxml\guo_jing_aiqing_xunxi.musicxml`
- JSON: `assets\scores\guo_jing_aiqing_xunxi.json`
- JSON ≡ reparse: **True** (1171/1171 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 2 / 2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 233 same-hand leap(s) ≥12 semitones (OMR risk)
- 24 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 20.000: 62→74
- right leap 12st @ beat 20.500: 74→62
- right leap 12st @ beat 23.000: 61→73
- right leap 12st @ beat 24.500: 74→62
- right leap 12st @ beat 26.000: 61→73
- right leap 12st @ beat 85.250: 66→78
- right leap 12st @ beat 85.750: 78→66
- right leap 12st @ beat 85.750: 66→78
- right leap 12st @ beat 86.000: 78→66
- right leap 12st @ beat 86.000: 66→78
- right leap 14st @ beat 86.250: 78→64
- right leap 12st @ beat 86.250: 64→76
- right leap 12st @ beat 96.500: 66→78
- right leap 12st @ beat 96.750: 69→81
- right leap 12st @ beat 97.000: 81→69
- right leap 12st @ beat 97.000: 69→81
- right leap 12st @ beat 97.250: 81→69
- right leap 12st @ beat 97.250: 69→81
- right leap 12st @ beat 97.750: 81→69
- right leap 12st @ beat 98.000: 69→81
- right leap 15st @ beat 98.250: 81→66
- right leap 12st @ beat 98.250: 66→78
- right leap 14st @ beat 98.750: 78→64
- right leap 12st @ beat 98.750: 64→76
- right leap 12st @ beat 99.000: 76→64
- right leap 12st @ beat 99.000: 64→76
- right leap 14st @ beat 99.250: 76→62
- right leap 12st @ beat 99.250: 62→74
- right leap 15st @ beat 99.750: 74→59
- right leap 12st @ beat 99.750: 59→71

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
