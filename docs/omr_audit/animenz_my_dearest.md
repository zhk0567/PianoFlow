# OMR audit — `animenz_my_dearest`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_my_dearest.pdf`
- MusicXML: `assets\scores\musicxml\animenz_my_dearest.musicxml`
- JSON: `assets\scores\animenz_my_dearest.json`
- JSON ≡ reparse: **True** (3643/3643 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 777 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 43.750: 79→91
- right leap 31st @ beat 46.250: 91→60
- right leap 12st @ beat 46.250: 60→72
- right leap 12st @ beat 46.750: 62→74
- right leap 14st @ beat 47.250: 74→60
- right leap 12st @ beat 47.250: 60→72
- right leap 24st @ beat 48.500: 84→60
- right leap 12st @ beat 48.750: 72→60
- right leap 12st @ beat 49.625: 84→72
- right leap 12st @ beat 49.750: 84→72
- right leap 13st @ beat 50.500: 84→71
- right leap 14st @ beat 51.250: 83→69
- right leap 12st @ beat 51.250: 69→81
- right leap 14st @ beat 51.750: 81→67
- right leap 19st @ beat 52.500: 79→60
- right leap 12st @ beat 53.625: 79→67
- right leap 12st @ beat 53.750: 79→67
- right leap 14st @ beat 54.500: 79→65
- right leap 13st @ beat 55.250: 77→64
- right leap 12st @ beat 55.250: 64→76
- right leap 14st @ beat 55.750: 76→62
- right leap 15st @ beat 56.500: 74→59
- right leap 12st @ beat 57.625: 74→62
- right leap 12st @ beat 59.250: 65→77
- right leap 13st @ beat 59.750: 77→64
- right leap 12st @ beat 60.750: 88→76
- right leap 26st @ beat 61.500: 88→62
- right leap 12st @ beat 61.750: 74→62
- right leap 14st @ beat 62.250: 74→60
- right leap 23st @ beat 64.500: 83→60

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
