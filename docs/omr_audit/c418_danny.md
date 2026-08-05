# OMR audit — `c418_danny`

- Generated: 2026-08-04 21:14
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_danny.pdf`
- MusicXML: `assets\scores\musicxml\c418_danny.musicxml`
- JSON: `assets\scores\c418_danny.json`
- JSON ≡ reparse: **True** (508/508 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 58 same-hand leap(s) ≥12 semitones (OMR risk)
- 6 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 3}`

## Same-hand leaps ≥12st
- right leap 15st @ beat 54.000: 74→59
- right leap 12st @ beat 65.000: 71→59
- right leap 14st @ beat 68.000: 67→81
- right leap 20st @ beat 69.000: 79→59
- right leap 20st @ beat 69.000: 59→79
- right leap 12st @ beat 73.000: 71→59
- right leap 12st @ beat 73.000: 59→71
- right leap 15st @ beat 83.000: 71→86
- right leap 14st @ beat 87.000: 79→65
- right leap 12st @ beat 87.000: 65→77
- right leap 13st @ beat 88.000: 77→64
- right leap 12st @ beat 88.000: 64→76
- right leap 13st @ beat 91.000: 72→59
- right leap 17st @ beat 94.667: 79→62
- right leap 12st @ beat 176.667: 50→62
- right leap 12st @ beat 177.667: 62→50
- right leap 12st @ beat 177.667: 50→62
- right leap 12st @ beat 181.667: 53→65
- right leap 12st @ beat 184.667: 50→62
- right leap 12st @ beat 185.667: 62→50
- right leap 12st @ beat 185.667: 50→62
- right leap 12st @ beat 189.667: 53→65
- right leap 12st @ beat 192.667: 50→62
- right leap 12st @ beat 193.667: 62→50
- right leap 12st @ beat 193.667: 50→62
- right leap 12st @ beat 197.667: 53→65
- right leap 12st @ beat 200.667: 50→62
- right leap 12st @ beat 201.667: 62→50
- right leap 12st @ beat 201.667: 50→62
- right leap 12st @ beat 205.667: 53→65

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
