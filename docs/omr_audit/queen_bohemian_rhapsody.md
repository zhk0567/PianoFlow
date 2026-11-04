# OMR audit — `queen_bohemian_rhapsody`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\queen_bohemian_rhapsody.pdf`
- MusicXML: `assets\scores\musicxml\queen_bohemian_rhapsody.musicxml`
- JSON: `assets\scores\queen_bohemian_rhapsody.json`
- JSON ≡ reparse: **True** (2396/2396 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -3 / -3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 923 same-hand leap(s) ≥12 semitones (OMR risk)
- 34 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 3, "('5', '4')": 3, "('3', '4')": 3, "('2', '4')": 6}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 25.000: 65→53
- right leap 15st @ beat 31.500: 75→60
- right leap 21st @ beat 35.500: 74→53
- right leap 18st @ beat 55.500: 75→57
- right leap 12st @ beat 58.500: 67→79
- right leap 14st @ beat 61.000: 79→65
- right leap 12st @ beat 61.000: 65→77
- right leap 19st @ beat 61.500: 77→58
- right leap 12st @ beat 63.500: 67→79
- right leap 14st @ beat 64.500: 79→65
- right leap 12st @ beat 64.500: 65→77
- right leap 15st @ beat 65.500: 77→62
- right leap 12st @ beat 69.000: 67→79
- right leap 14st @ beat 70.000: 79→65
- right leap 12st @ beat 70.000: 65→77
- right leap 17st @ beat 70.500: 77→60
- right leap 12st @ beat 72.500: 69→81
- right leap 14st @ beat 73.500: 81→67
- right leap 12st @ beat 73.500: 67→79
- right leap 17st @ beat 74.000: 79→62
- right leap 12st @ beat 76.000: 62→74
- right leap 12st @ beat 76.000: 74→86
- right leap 14st @ beat 78.000: 86→72
- right leap 12st @ beat 78.000: 72→84
- right leap 22st @ beat 79.000: 84→62
- right leap 12st @ beat 86.000: 67→79
- right leap 14st @ beat 87.000: 79→65
- right leap 12st @ beat 87.000: 65→77
- right leap 12st @ beat 87.500: 77→65
- right leap 14st @ beat 91.000: 81→67

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
