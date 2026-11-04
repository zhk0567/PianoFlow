# OMR audit — `jojo_steel_ball_run_dance`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\jojo_steel_ball_run_dance.pdf`
- MusicXML: `assets\scores\musicxml\jojo_steel_ball_run_dance.musicxml`
- JSON: `assets\scores\jojo_steel_ball_run_dance.json`
- JSON ≡ reparse: **True** (3543/3543 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -3 / -3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 1174 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 10.000: 87→75
- right leap 13st @ beat 12.750: 87→74
- right leap 12st @ beat 15.500: 84→72
- right leap 24st @ beat 16.000: 84→60
- right leap 13st @ beat 17.750: 79→66
- right leap 12st @ beat 21.500: 75→63
- right leap 12st @ beat 22.500: 63→75
- right leap 12st @ beat 23.000: 67→79
- right leap 12st @ beat 23.500: 71→83
- right leap 14st @ beat 24.750: 86→72
- right leap 12st @ beat 24.750: 72→84
- right leap 12st @ beat 25.000: 84→72
- right leap 12st @ beat 25.000: 72→84
- right leap 12st @ beat 26.000: 87→75
- right leap 15st @ beat 26.500: 87→72
- right leap 12st @ beat 26.500: 72→84
- right leap 12st @ beat 27.000: 82→94
- right leap 19st @ beat 27.500: 94→75
- right leap 12st @ beat 27.500: 75→87
- right leap 13st @ beat 28.000: 87→74
- right leap 12st @ beat 28.750: 86→74
- right leap 12st @ beat 28.875: 86→74
- right leap 14st @ beat 29.250: 86→72
- right leap 12st @ beat 29.750: 84→72
- right leap 24st @ beat 30.250: 84→60
- right leap 12st @ beat 34.250: 60→72
- right leap 12st @ beat 43.750: 86→74
- right leap 31st @ beat 45.750: 86→55
- right leap 12st @ beat 47.750: 84→96
- right leap 38st @ beat 48.250: 96→58

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
