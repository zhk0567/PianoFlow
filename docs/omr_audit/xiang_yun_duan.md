# OMR audit — `xiang_yun_duan`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\xiang_yun_duan.pdf`
- MusicXML: `assets\scores\musicxml\xiang_yun_duan.musicxml`
- JSON: `assets\scores\xiang_yun_duan.json`
- JSON ≡ reparse: **True** (1545/1545 notes)
- BPM JSON/parse: 70 / 70
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 233 same-hand leap(s) ≥12 semitones (OMR risk)
- 10 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 63.000: 65→77
- right leap 12st @ beat 66.000: 77→65
- right leap 12st @ beat 69.000: 74→62
- right leap 19st @ beat 73.000: 79→60
- right leap 15st @ beat 74.000: 62→77
- right leap 12st @ beat 76.000: 77→65
- right leap 14st @ beat 78.750: 65→79
- right leap 12st @ beat 81.000: 77→65
- right leap 12st @ beat 93.000: 70→58
- right leap 15st @ beat 97.000: 77→62
- right leap 14st @ beat 101.000: 74→60
- right leap 14st @ beat 102.750: 58→72
- right leap 12st @ beat 103.000: 72→60
- right leap 12st @ beat 107.000: 77→65
- right leap 26st @ beat 111.000: 84→58
- right leap 12st @ beat 112.500: 65→77
- right leap 17st @ beat 113.750: 82→65
- right leap 14st @ beat 124.750: 72→58
- right leap 12st @ beat 125.500: 70→58
- right leap 19st @ beat 151.500: 77→58
- right leap 12st @ beat 160.000: 62→74
- right leap 15st @ beat 175.250: 77→62
- right leap 12st @ beat 175.250: 62→74
- right leap 12st @ beat 175.500: 74→62
- right leap 12st @ beat 175.500: 62→74
- right leap 12st @ beat 175.750: 65→77
- right leap 12st @ beat 176.000: 77→65
- right leap 12st @ beat 176.000: 65→77
- right leap 15st @ beat 177.000: 77→62
- right leap 12st @ beat 177.250: 62→74

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
