# OMR audit — `c418_clark`

- Generated: 2026-08-04 21:11
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_clark.pdf`
- MusicXML: `assets\scores\musicxml\c418_clark.musicxml`
- JSON: `assets\scores\c418_clark.json`
- JSON ≡ reparse: **True** (372/372 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 11 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 15.000: 79→67
- right leap 20st @ beat 30.500: 79→59
- right leap 12st @ beat 39.000: 72→60
- right leap 12st @ beat 39.000: 60→72
- right leap 22st @ beat 48.000: 79→57
- right leap 12st @ beat 55.000: 72→60
- right leap 12st @ beat 55.000: 60→72
- right leap 22st @ beat 64.000: 79→57
- right leap 12st @ beat 71.000: 72→60
- right leap 12st @ beat 71.000: 60→72
- left leap 15st @ beat 96.000: 45→60

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
