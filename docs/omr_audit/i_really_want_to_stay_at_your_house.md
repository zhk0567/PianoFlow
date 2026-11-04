# OMR audit — `i_really_want_to_stay_at_your_house`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\i_really_want_to_stay_at_your_house.pdf`
- MusicXML: `assets\scores\musicxml\i_really_want_to_stay_at_your_house.musicxml`
- JSON: `assets\scores\i_really_want_to_stay_at_your_house.json`
- JSON ≡ reparse: **True** (2465/2465 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -6 / -6
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 753 same-hand leap(s) ≥12 semitones (OMR risk)
- 5 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 4.500: 78→65
- right leap 12st @ beat 20.250: 78→66
- right leap 12st @ beat 20.250: 66→78
- right leap 12st @ beat 20.750: 78→66
- right leap 12st @ beat 20.750: 66→78
- right leap 13st @ beat 21.250: 78→65
- right leap 12st @ beat 21.250: 65→77
- right leap 12st @ beat 21.750: 77→65
- right leap 12st @ beat 21.750: 65→77
- right leap 12st @ beat 22.250: 77→65
- right leap 13st @ beat 22.250: 65→78
- right leap 12st @ beat 22.750: 78→66
- right leap 12st @ beat 22.750: 66→78
- right leap 12st @ beat 23.250: 78→66
- right leap 14st @ beat 23.750: 66→80
- right leap 15st @ beat 24.250: 80→65
- right leap 12st @ beat 24.250: 68→80
- right leap 15st @ beat 25.250: 80→65
- right leap 12st @ beat 35.750: 78→66
- right leap 12st @ beat 50.500: 65→77
- right leap 12st @ beat 51.500: 78→66
- right leap 12st @ beat 51.500: 66→78
- right leap 12st @ beat 52.000: 78→66
- right leap 12st @ beat 52.000: 66→78
- right leap 13st @ beat 52.500: 78→65
- right leap 15st @ beat 52.500: 65→80
- right leap 15st @ beat 53.000: 80→65
- right leap 15st @ beat 53.000: 65→80
- right leap 15st @ beat 53.500: 80→65
- right leap 21st @ beat 62.500: 80→59

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
