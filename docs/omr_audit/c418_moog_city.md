# OMR audit — `c418_moog_city`

- Generated: 2026-08-04 21:08
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_moog_city.pdf`
- MusicXML: `assets\scores\musicxml\c418_moog_city.musicxml`
- JSON: `assets\scores\c418_moog_city.json`
- JSON ≡ reparse: **True** (718/718 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 97 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 16st @ beat 2.000: 67→83
- right leap 15st @ beat 3.000: 79→64
- right leap 15st @ beat 7.000: 79→64
- right leap 15st @ beat 11.000: 79→64
- right leap 15st @ beat 15.000: 79→64
- right leap 15st @ beat 19.000: 79→64
- right leap 15st @ beat 23.000: 79→64
- right leap 15st @ beat 27.000: 79→64
- right leap 15st @ beat 31.000: 79→64
- right leap 15st @ beat 35.000: 79→64
- right leap 15st @ beat 39.000: 79→64
- right leap 15st @ beat 43.000: 79→64
- right leap 15st @ beat 47.000: 79→64
- right leap 15st @ beat 51.500: 79→64
- right leap 15st @ beat 55.500: 79→64
- right leap 15st @ beat 59.500: 79→64
- right leap 15st @ beat 63.500: 79→64
- right leap 15st @ beat 67.500: 79→64
- right leap 15st @ beat 71.500: 79→64
- right leap 15st @ beat 75.500: 79→64
- right leap 15st @ beat 79.500: 79→64
- right leap 15st @ beat 83.500: 79→64
- right leap 15st @ beat 87.500: 79→64
- right leap 14st @ beat 95.500: 86→72
- right leap 14st @ beat 127.500: 86→72
- right leap 12st @ beat 130.500: 81→69
- right leap 12st @ beat 143.500: 81→69
- right leap 17st @ beat 151.500: 76→59
- right leap 12st @ beat 167.500: 71→59
- right leap 12st @ beat 179.500: 71→59

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
