# OMR audit — `c418_death`

- Generated: 2026-08-04 21:07
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_death.pdf`
- MusicXML: `assets\scores\musicxml\c418_death.musicxml`
- JSON: `assets\scores\c418_death.json`
- JSON ≡ reparse: **True** (77/77 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 4 / 4
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 1 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2}`

## Same-hand leaps ≥12st
- left leap 14st @ beat 15.000: 47→61

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
