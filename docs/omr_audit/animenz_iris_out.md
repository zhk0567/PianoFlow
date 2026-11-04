# OMR audit — `animenz_iris_out`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_iris_out.pdf`
- MusicXML: `assets\scores\musicxml\animenz_iris_out.musicxml`
- JSON: `assets\scores\animenz_iris_out.json`
- JSON ≡ reparse: **True** (2482/2482 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 569 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 14st @ beat 4.000: 75→61
- right leap 23st @ beat 5.250: 87→64
- right leap 13st @ beat 18.250: 68→55
- right leap 21st @ beat 68.000: 47→68
- right leap 24st @ beat 69.000: 80→56
- right leap 24st @ beat 73.000: 80→56
- right leap 24st @ beat 77.000: 82→58
- right leap 24st @ beat 81.000: 83→59
- right leap 12st @ beat 83.000: 56→68
- right leap 24st @ beat 85.000: 80→56
- right leap 12st @ beat 88.750: 83→71
- right leap 12st @ beat 89.750: 83→71
- right leap 12st @ beat 91.000: 71→59
- right leap 12st @ beat 91.000: 59→71
- right leap 12st @ beat 91.500: 61→73
- right leap 14st @ beat 92.500: 75→61
- right leap 12st @ beat 92.500: 61→73
- right leap 12st @ beat 93.000: 63→75
- right leap 12st @ beat 93.500: 75→63
- right leap 12st @ beat 93.500: 63→75
- right leap 13st @ beat 94.500: 76→63
- right leap 12st @ beat 94.500: 63→75
- right leap 12st @ beat 99.500: 72→84
- right leap 15st @ beat 101.000: 88→73
- right leap 12st @ beat 102.250: 87→75
- right leap 12st @ beat 102.750: 87→75
- right leap 12st @ beat 103.000: 87→75
- right leap 14st @ beat 103.250: 87→73
- right leap 12st @ beat 103.250: 73→85
- right leap 14st @ beat 103.500: 85→71

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
