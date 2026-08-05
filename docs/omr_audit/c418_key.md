# OMR audit — `c418_key`

- Generated: 2026-08-04 21:06
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_key.pdf`
- MusicXML: `assets\scores\musicxml\c418_key.musicxml`
- JSON: `assets\scores\c418_key.json`
- JSON ≡ reparse: **True** (111/111 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 6 / 6
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 3 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('C', '4', None), ('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 16st @ beat 32.000: 73→89
- right leap 16st @ beat 48.000: 73→89
- left leap 19st @ beat 16.500: 47→66

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
