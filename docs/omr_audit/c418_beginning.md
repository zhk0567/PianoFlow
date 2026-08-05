# OMR audit — `c418_beginning`

- Generated: 2026-08-04 21:15
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_beginning.pdf`
- MusicXML: `assets\scores\musicxml\c418_beginning.musicxml`
- JSON: `assets\scores\c418_beginning.json`
- JSON ≡ reparse: **True** (51/51 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -7 / -7
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 5 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 26st @ beat 28.000: 56→82
- left leap 12st @ beat 12.000: 68→56
- left leap 24st @ beat 39.000: 51→27
- left leap 12st @ beat 39.000: 27→39
- left leap 12st @ beat 42.000: 29→41

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
