# OMR audit — `animenz_guren_no_yumiya`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_guren_no_yumiya.pdf`
- MusicXML: `assets\scores\musicxml\animenz_guren_no_yumiya.musicxml`
- JSON: `assets\scores\animenz_guren_no_yumiya.json`
- JSON ≡ reparse: **True** (1509/1509 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 376 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2, "('2', '4')": 1, "('3', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 15.500: 71→84
- right leap 14st @ beat 17.500: 88→74
- right leap 12st @ beat 18.000: 86→74
- right leap 15st @ beat 18.500: 86→71
- right leap 12st @ beat 20.000: 85→73
- right leap 12st @ beat 21.000: 76→88
- right leap 14st @ beat 22.000: 88→74
- right leap 12st @ beat 23.000: 86→74
- right leap 15st @ beat 23.500: 86→71
- right leap 12st @ beat 24.500: 85→73
- right leap 12st @ beat 25.000: 76→88
- right leap 14st @ beat 25.500: 88→74
- right leap 12st @ beat 26.000: 86→74
- right leap 15st @ beat 26.500: 86→71
- right leap 12st @ beat 27.500: 85→73
- right leap 13st @ beat 28.000: 85→72
- right leap 12st @ beat 28.500: 75→87
- right leap 14st @ beat 29.000: 87→73
- right leap 12st @ beat 29.500: 85→73
- right leap 13st @ beat 30.000: 85→72
- right leap 12st @ beat 31.000: 92→80
- right leap 24st @ beat 32.000: 92→68
- right leap 19st @ beat 33.000: 80→61
- right leap 12st @ beat 33.000: 61→73
- right leap 15st @ beat 33.750: 78→63
- right leap 12st @ beat 33.750: 63→75
- right leap 15st @ beat 34.750: 76→61
- right leap 12st @ beat 34.750: 61→73
- right leap 16st @ beat 35.750: 75→59
- right leap 19st @ beat 38.000: 80→61

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
