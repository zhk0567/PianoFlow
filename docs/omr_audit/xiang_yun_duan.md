# OMR audit — `xiang_yun_duan`

- Generated: 2026-08-04 19:37
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\xiang_yun_duan.pdf`
- MusicXML: `assets\scores\musicxml\xiang_yun_duan.musicxml`
- JSON: `assets\scores\xiang_yun_duan.json`
- JSON ≡ reparse: **True** (1570/1570 notes)
- BPM JSON/parse: 70 / 70
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 239 same-hand leap(s) ≥12 semitones (OMR risk)
- 2 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 14st @ beat 28.500: 72→58
- right leap 12st @ beat 31.000: 65→77
- right leap 12st @ beat 63.500: 65→77
- right leap 12st @ beat 66.500: 77→65
- right leap 12st @ beat 69.500: 74→62
- right leap 19st @ beat 73.500: 79→60
- right leap 15st @ beat 74.500: 62→77
- right leap 12st @ beat 78.000: 77→65
- right leap 12st @ beat 83.000: 77→65
- right leap 12st @ beat 95.000: 70→58
- right leap 15st @ beat 99.000: 77→62
- right leap 14st @ beat 103.000: 74→60
- right leap 14st @ beat 104.750: 58→72
- right leap 12st @ beat 105.000: 72→60
- right leap 12st @ beat 109.000: 77→65
- right leap 26st @ beat 113.000: 84→58
- right leap 12st @ beat 114.500: 65→77
- right leap 17st @ beat 115.750: 82→65
- right leap 14st @ beat 126.750: 72→58
- right leap 12st @ beat 127.500: 70→58
- right leap 19st @ beat 155.125: 77→58
- right leap 12st @ beat 163.875: 62→74
- right leap 15st @ beat 179.750: 77→62
- right leap 12st @ beat 179.750: 62→74
- right leap 12st @ beat 180.000: 74→62
- right leap 12st @ beat 180.000: 62→74
- right leap 12st @ beat 180.250: 65→77
- right leap 12st @ beat 180.500: 77→65
- right leap 12st @ beat 180.500: 65→77
- right leap 15st @ beat 181.500: 77→62

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
