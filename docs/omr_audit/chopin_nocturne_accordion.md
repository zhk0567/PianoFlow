# OMR audit — `chopin_nocturne_accordion`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\chopin_nocturne_accordion.pdf`
- MusicXML: `assets\scores\musicxml\chopin_nocturne_accordion.musicxml`
- JSON: `assets\scores\chopin_nocturne_accordion.json`
- JSON ≡ reparse: **True** (815/815 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -3 / -3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 189 same-hand leap(s) ≥12 semitones (OMR risk)
- 1 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 8.500: 72→84
- right leap 29st @ beat 22.500: 77→48
- right leap 12st @ beat 25.500: 65→53
- right leap 21st @ beat 27.000: 56→77
- right leap 17st @ beat 27.500: 77→60
- right leap 15st @ beat 28.000: 60→75
- right leap 17st @ beat 28.500: 75→58
- right leap 17st @ beat 28.500: 58→75
- right leap 14st @ beat 31.500: 72→86
- right leap 12st @ beat 51.500: 77→65
- right leap 19st @ beat 63.333: 67→86
- right leap 12st @ beat 83.500: 77→65
- right leap 12st @ beat 92.000: 80→68
- right leap 12st @ beat 92.250: 74→86
- right leap 14st @ beat 95.500: 72→86
- right leap 14st @ beat 115.250: 75→89
- right leap 12st @ beat 122.750: 87→75
- right leap 12st @ beat 122.750: 75→87
- right leap 16st @ beat 123.000: 87→71
- right leap 12st @ beat 123.000: 71→83
- right leap 13st @ beat 123.500: 83→70
- right leap 12st @ beat 123.500: 70→82
- right leap 12st @ beat 123.750: 74→86
- right leap 16st @ beat 124.000: 86→70
- right leap 12st @ beat 124.000: 70→82
- right leap 12st @ beat 124.250: 72→84
- right leap 16st @ beat 124.500: 84→68
- right leap 12st @ beat 124.500: 68→80
- right leap 13st @ beat 125.000: 80→67
- right leap 12st @ beat 125.000: 67→79

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
