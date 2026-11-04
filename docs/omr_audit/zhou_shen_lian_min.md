# OMR audit — `zhou_shen_lian_min`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\zhou_shen_lian_min.pdf`
- MusicXML: `assets\scores\musicxml\zhou_shen_lian_min.musicxml`
- JSON: `assets\scores\zhou_shen_lian_min.json`
- JSON ≡ reparse: **True** (1422/1422 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 408 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{}`

## Same-hand leaps ≥12st
- right leap 14st @ beat 2.000: 76→62
- right leap 19st @ beat 4.000: 81→62
- right leap 19st @ beat 5.000: 76→57
- right leap 14st @ beat 5.250: 76→62
- right leap 14st @ beat 10.000: 81→67
- right leap 17st @ beat 13.000: 79→62
- right leap 28st @ beat 16.000: 81→53
- right leap 12st @ beat 17.000: 62→74
- right leap 12st @ beat 23.000: 76→64
- right leap 15st @ beat 45.000: 76→61
- right leap 15st @ beat 45.000: 61→76
- right leap 12st @ beat 48.000: 69→81
- right leap 21st @ beat 62.000: 81→60
- right leap 12st @ beat 69.750: 86→74
- right leap 12st @ beat 79.000: 57→69
- right leap 12st @ beat 96.000: 69→81
- right leap 14st @ beat 96.250: 81→67
- right leap 12st @ beat 96.250: 67→79
- right leap 17st @ beat 96.500: 79→62
- right leap 12st @ beat 96.500: 62→74
- right leap 12st @ beat 96.750: 67→79
- right leap 12st @ beat 96.875: 79→67
- right leap 12st @ beat 96.875: 67→79
- right leap 12st @ beat 97.000: 69→81
- right leap 12st @ beat 97.500: 81→69
- right leap 12st @ beat 97.500: 69→81
- right leap 12st @ beat 97.750: 81→69
- right leap 12st @ beat 97.750: 69→81
- right leap 14st @ beat 98.000: 81→67
- right leap 12st @ beat 98.000: 67→79

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
