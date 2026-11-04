# OMR audit — `kexi_mei_ruguo`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\kexi_mei_ruguo.pdf`
- MusicXML: `assets\scores\musicxml\kexi_mei_ruguo.musicxml`
- JSON: `assets\scores\kexi_mei_ruguo.json`
- JSON ≡ reparse: **True** (2200/2200 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- clef-octave-change present {'1': 1} — verify concert pitch vs notation (do not double-apply in JSON)
- 582 same-hand leap(s) ≥12 semitones (OMR risk)
- 16 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None), ('G', '2', '1')]`
- has_key: False
- has_tempo: False
- octave_changes: `{'1': 1}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 6.000: 50→62
- right leap 12st @ beat 10.000: 52→40
- right leap 24st @ beat 16.000: 60→84
- right leap 12st @ beat 30.000: 79→67
- right leap 19st @ beat 32.500: 79→60
- right leap 19st @ beat 48.500: 79→60
- right leap 12st @ beat 60.250: 74→62
- right leap 12st @ beat 60.500: 62→74
- right leap 12st @ beat 60.750: 74→62
- right leap 17st @ beat 61.000: 62→79
- right leap 32st @ beat 62.500: 91→59
- right leap 12st @ beat 75.750: 62→74
- right leap 24st @ beat 78.250: 79→55
- right leap 12st @ beat 79.750: 64→52
- right leap 12st @ beat 79.750: 52→64
- right leap 12st @ beat 88.250: 57→69
- right leap 13st @ beat 101.750: 77→64
- right leap 16st @ beat 102.250: 76→60
- right leap 13st @ beat 107.750: 65→52
- right leap 12st @ beat 107.750: 52→64
- right leap 12st @ beat 120.000: 76→64
- right leap 12st @ beat 120.750: 71→83
- right leap 14st @ beat 121.500: 83→69
- right leap 12st @ beat 121.500: 69→81
- right leap 14st @ beat 121.750: 81→67
- right leap 14st @ beat 122.250: 79→65
- right leap 12st @ beat 124.750: 57→69
- right leap 12st @ beat 130.250: 72→60
- right leap 12st @ beat 157.750: 81→69
- right leap 12st @ beat 176.750: 72→60

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
