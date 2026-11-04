# OMR audit — `everyday_world_oregairu`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\everyday_world_oregairu.pdf`
- MusicXML: `assets\scores\musicxml\everyday_world_oregairu.musicxml`
- JSON: `assets\scores\everyday_world_oregairu.json`
- JSON ≡ reparse: **True** (2632/2632 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 2 / 2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 314 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2, "('6', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 6.250: 85→73
- right leap 12st @ beat 6.500: 81→69
- right leap 14st @ beat 7.000: 81→67
- right leap 12st @ beat 16.000: 76→64
- right leap 12st @ beat 31.500: 57→69
- right leap 12st @ beat 34.000: 78→66
- right leap 12st @ beat 35.000: 78→66
- right leap 13st @ beat 42.000: 76→63
- right leap 12st @ beat 46.000: 76→64
- right leap 12st @ beat 47.000: 76→64
- right leap 12st @ beat 60.000: 81→69
- right leap 20st @ beat 62.000: 79→59
- right leap 12st @ beat 62.500: 66→78
- right leap 12st @ beat 63.500: 69→81
- right leap 14st @ beat 64.500: 83→69
- right leap 12st @ beat 64.500: 69→81
- right leap 12st @ beat 64.750: 81→69
- right leap 12st @ beat 65.000: 81→69
- right leap 15st @ beat 67.000: 81→66
- right leap 12st @ beat 67.000: 66→78
- right leap 12st @ beat 67.500: 67→79
- right leap 19st @ beat 68.500: 81→62
- right leap 12st @ beat 68.500: 62→74
- right leap 12st @ beat 71.500: 71→83
- right leap 14st @ beat 72.000: 83→69
- right leap 12st @ beat 75.500: 67→79
- right leap 14st @ beat 82.000: 78→64
- right leap 12st @ beat 83.000: 66→78
- right leap 12st @ beat 83.750: 79→67
- right leap 19st @ beat 84.500: 81→62

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
