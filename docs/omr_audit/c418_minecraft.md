# OMR audit — `c418_minecraft`

- Generated: 2026-08-04 21:09
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_minecraft.pdf`
- MusicXML: `assets\scores\musicxml\c418_minecraft.musicxml`
- JSON: `assets\scores\c418_minecraft.json`
- JSON ≡ reparse: **True** (186/186 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 4 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 83.000: 63→75
- right leap 12st @ beat 84.000: 75→63
- right leap 12st @ beat 84.000: 63→75
- left leap 12st @ beat 80.000: 61→49

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
