# OMR audit — `animenz_dango_daikazoku`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_dango_daikazoku.pdf`
- MusicXML: `assets\scores\musicxml\animenz_dango_daikazoku.musicxml`
- JSON: `assets\scores\animenz_dango_daikazoku.json`
- JSON ≡ reparse: **True** (1279/1279 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -4 / -4
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
- times: `{}`

## Same-hand leaps ≥12st
- right leap 17st @ beat 1.000: 80→63
- right leap 12st @ beat 1.000: 63→75
- right leap 12st @ beat 2.000: 65→77
- right leap 12st @ beat 3.000: 68→80
- right leap 19st @ beat 6.000: 92→73
- right leap 12st @ beat 6.000: 73→85
- right leap 12st @ beat 8.000: 85→73
- right leap 12st @ beat 8.000: 73→85
- right leap 12st @ beat 24.000: 87→75
- right leap 12st @ beat 26.000: 84→72
- right leap 20st @ beat 42.000: 80→60
- right leap 12st @ beat 42.000: 60→72
- right leap 12st @ beat 42.500: 63→75
- right leap 12st @ beat 43.000: 68→80
- right leap 12st @ beat 43.500: 70→82
- right leap 12st @ beat 46.500: 68→80
- right leap 12st @ beat 47.000: 70→82
- right leap 12st @ beat 47.500: 72→84
- right leap 17st @ beat 48.500: 87→70
- right leap 12st @ beat 48.500: 70→82
- right leap 12st @ beat 49.000: 72→84
- right leap 12st @ beat 50.000: 84→72
- right leap 12st @ beat 52.000: 82→70
- right leap 12st @ beat 54.500: 70→82
- right leap 14st @ beat 55.000: 82→68
- right leap 12st @ beat 55.000: 68→80
- right leap 12st @ beat 55.500: 75→87
- right leap 15st @ beat 56.000: 87→72
- right leap 12st @ beat 58.000: 84→72
- right leap 12st @ beat 60.000: 82→70

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
