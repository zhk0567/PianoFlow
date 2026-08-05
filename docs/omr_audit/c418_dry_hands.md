# OMR audit — `c418_dry_hands`

- Generated: 2026-08-04 21:08
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_dry_hands.pdf`
- MusicXML: `assets\scores\musicxml\c418_dry_hands.musicxml`
- JSON: `assets\scores\c418_dry_hands.json`
- JSON ≡ reparse: **True** (114/114 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 3 / 3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 19 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 4.000: 74→62
- right leap 12st @ beat 20.000: 73→61
- right leap 12st @ beat 22.000: 71→59
- right leap 12st @ beat 28.000: 73→61
- right leap 12st @ beat 64.000: 76→64
- right leap 12st @ beat 68.000: 74→62
- right leap 12st @ beat 77.500: 66→54
- left leap 14st @ beat 12.000: 61→47
- left leap 15st @ beat 16.000: 57→42
- left leap 17st @ beat 40.000: 52→35
- left leap 15st @ beat 41.000: 35→50
- left leap 15st @ beat 44.000: 50→35
- left leap 12st @ beat 45.000: 35→47
- left leap 15st @ beat 57.000: 35→50
- left leap 15st @ beat 60.000: 50→35
- left leap 12st @ beat 61.000: 35→47
- left leap 26st @ beat 76.000: 61→35
- left leap 12st @ beat 80.000: 47→35
- left leap 12st @ beat 80.000: 35→47

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
