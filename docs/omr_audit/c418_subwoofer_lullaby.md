# OMR audit — `c418_subwoofer_lullaby`

- Generated: 2026-08-04 21:07
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_subwoofer_lullaby.pdf`
- MusicXML: `assets\scores\musicxml\c418_subwoofer_lullaby.musicxml`
- JSON: `assets\scores\c418_subwoofer_lullaby.json`
- JSON ≡ reparse: **True** (418/418 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 90 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 36.000: 60→72
- right leap 12st @ beat 42.500: 67→79
- right leap 14st @ beat 53.500: 62→76
- right leap 12st @ beat 54.000: 76→64
- right leap 12st @ beat 54.000: 64→76
- right leap 12st @ beat 56.000: 65→77
- right leap 14st @ beat 59.000: 67→81
- right leap 17st @ beat 61.000: 79→62
- right leap 14st @ beat 61.000: 62→76
- right leap 12st @ beat 66.000: 79→67
- right leap 12st @ beat 70.000: 79→67
- right leap 12st @ beat 74.000: 79→67
- right leap 12st @ beat 78.000: 79→67
- right leap 13st @ beat 121.000: 71→84
- right leap 15st @ beat 153.000: 64→79
- right leap 14st @ beat 178.000: 86→72
- right leap 12st @ beat 186.000: 67→79
- right leap 16st @ beat 195.000: 76→60
- left leap 12st @ beat 17.000: 48→60
- left leap 12st @ beat 18.000: 60→48
- left leap 12st @ beat 19.000: 48→60
- left leap 12st @ beat 20.000: 60→48
- left leap 12st @ beat 25.000: 48→60
- left leap 12st @ beat 26.000: 60→48
- left leap 12st @ beat 27.000: 48→60
- left leap 12st @ beat 28.000: 60→48
- left leap 12st @ beat 33.000: 48→60
- left leap 16st @ beat 34.000: 64→48
- left leap 12st @ beat 35.000: 48→60
- left leap 16st @ beat 36.000: 64→48

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
