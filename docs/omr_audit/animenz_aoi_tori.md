# OMR audit — `animenz_aoi_tori`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_aoi_tori.pdf`
- MusicXML: `assets\scores\musicxml\animenz_aoi_tori.musicxml`
- JSON: `assets\scores\animenz_aoi_tori.json`
- JSON ≡ reparse: **True** (2925/2925 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 3 / 3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 656 same-hand leap(s) ≥12 semitones (OMR risk)
- 12 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 19.500: 81→68
- right leap 12st @ beat 24.000: 66→78
- right leap 16st @ beat 37.500: 78→62
- right leap 12st @ beat 53.500: 85→73
- right leap 21st @ beat 54.000: 85→64
- right leap 14st @ beat 56.500: 85→71
- right leap 12st @ beat 57.000: 83→71
- right leap 12st @ beat 59.500: 83→71
- right leap 15st @ beat 60.000: 73→88
- right leap 19st @ beat 68.000: 80→61
- right leap 12st @ beat 85.250: 69→81
- right leap 17st @ beat 99.750: 78→61
- right leap 12st @ beat 115.250: 66→78
- right leap 12st @ beat 115.750: 69→81
- right leap 12st @ beat 116.250: 71→83
- right leap 19st @ beat 117.750: 85→66
- right leap 12st @ beat 117.750: 66→78
- right leap 12st @ beat 118.250: 69→81
- right leap 12st @ beat 119.250: 71→83
- right leap 12st @ beat 120.750: 85→73
- right leap 12st @ beat 122.250: 76→88
- right leap 14st @ beat 123.250: 88→74
- right leap 12st @ beat 123.250: 74→86
- right leap 13st @ beat 123.750: 86→73
- right leap 21st @ beat 125.250: 80→59
- right leap 12st @ beat 131.250: 73→61
- right leap 12st @ beat 131.250: 61→73
- right leap 12st @ beat 131.750: 66→78
- right leap 12st @ beat 132.250: 68→80
- right leap 13st @ beat 134.750: 81→68

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
