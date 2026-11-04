# OMR audit — `animenz_akuma_no_ko`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_akuma_no_ko.pdf`
- MusicXML: `assets\scores\musicxml\animenz_akuma_no_ko.musicxml`
- JSON: `assets\scores\animenz_akuma_no_ko.json`
- JSON ≡ reparse: **True** (2717/2717 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 726 same-hand leap(s) ≥12 semitones (OMR risk)
- 29 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 3, "('2', '4')": 2}`

## Same-hand leaps ≥12st
- right leap 18st @ beat 2.000: 78→60
- right leap 20st @ beat 4.000: 81→61
- right leap 18st @ beat 6.000: 78→60
- right leap 22st @ beat 8.000: 81→59
- right leap 18st @ beat 10.000: 78→60
- right leap 20st @ beat 12.000: 81→61
- right leap 18st @ beat 14.000: 78→60
- right leap 12st @ beat 32.000: 71→83
- right leap 12st @ beat 33.000: 78→90
- right leap 14st @ beat 34.000: 90→76
- right leap 12st @ beat 34.000: 76→88
- right leap 12st @ beat 34.500: 78→90
- right leap 12st @ beat 35.000: 81→93
- right leap 22st @ beat 36.000: 93→71
- right leap 12st @ beat 36.000: 71→83
- right leap 12st @ beat 37.000: 78→90
- right leap 14st @ beat 38.000: 90→76
- right leap 12st @ beat 38.000: 76→88
- right leap 12st @ beat 38.500: 78→90
- right leap 12st @ beat 39.000: 81→93
- right leap 24st @ beat 39.750: 93→69
- right leap 12st @ beat 53.750: 66→78
- right leap 12st @ beat 54.750: 81→69
- right leap 12st @ beat 55.000: 81→69
- right leap 15st @ beat 55.250: 81→66
- right leap 12st @ beat 55.250: 66→78
- right leap 17st @ beat 57.500: 83→66
- right leap 12st @ beat 57.500: 66→78
- right leap 13st @ beat 58.500: 86→73
- right leap 12st @ beat 58.500: 73→85

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
