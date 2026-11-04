# OMR audit — `shan_yichun_zhu_yu`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\shan_yichun_zhu_yu.pdf`
- MusicXML: `assets\scores\musicxml\shan_yichun_zhu_yu.musicxml`
- JSON: `assets\scores\shan_yichun_zhu_yu.json`
- JSON ≡ reparse: **True** (1669/1669 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 409 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('6', '8')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 19.500: 69→81
- right leap 12st @ beat 25.500: 81→69
- right leap 12st @ beat 30.000: 69→81
- right leap 12st @ beat 31.500: 69→81
- right leap 12st @ beat 36.000: 74→62
- right leap 15st @ beat 45.000: 84→69
- right leap 14st @ beat 48.000: 76→62
- right leap 12st @ beat 48.500: 62→74
- right leap 12st @ beat 50.750: 74→62
- right leap 12st @ beat 51.250: 62→74
- right leap 12st @ beat 58.750: 69→81
- right leap 12st @ beat 61.750: 72→84
- right leap 15st @ beat 62.750: 84→69
- right leap 12st @ beat 62.750: 69→81
- right leap 14st @ beat 64.250: 81→67
- right leap 12st @ beat 64.250: 67→79
- right leap 15st @ beat 66.750: 81→66
- right leap 12st @ beat 68.750: 69→81
- right leap 12st @ beat 69.750: 81→69
- right leap 12st @ beat 71.250: 74→86
- right leap 14st @ beat 71.750: 86→72
- right leap 12st @ beat 71.750: 72→84
- right leap 15st @ beat 74.750: 84→69
- right leap 12st @ beat 74.750: 69→81
- right leap 12st @ beat 75.250: 70→82
- right leap 13st @ beat 75.500: 82→69
- right leap 12st @ beat 76.250: 67→79
- right leap 12st @ beat 77.750: 66→78
- right leap 12st @ beat 78.000: 78→66
- right leap 12st @ beat 78.000: 66→78

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
