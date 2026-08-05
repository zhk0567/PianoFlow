# OMR audit — `c418_living_mice`

- Generated: 2026-08-04 21:08
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_living_mice.pdf`
- MusicXML: `assets\scores\musicxml\c418_living_mice.musicxml`
- JSON: `assets\scores\c418_living_mice.json`
- JSON ≡ reparse: **True** (597/597 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 150 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 4}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 58.500: 64→76
- right leap 12st @ beat 74.500: 64→76
- right leap 12st @ beat 76.000: 74→62
- right leap 14st @ beat 87.500: 74→60
- right leap 12st @ beat 104.500: 79→67
- right leap 12st @ beat 108.500: 74→62
- right leap 12st @ beat 110.500: 72→84
- right leap 41st @ beat 112.500: 86→45
- right leap 26st @ beat 112.500: 62→88
- right leap 31st @ beat 113.000: 88→57
- right leap 20st @ beat 113.250: 64→84
- right leap 20st @ beat 113.500: 84→64
- right leap 13st @ beat 113.500: 71→84
- right leap 24st @ beat 114.000: 84→60
- right leap 16st @ beat 114.000: 67→83
- right leap 38st @ beat 114.500: 83→45
- right leap 15st @ beat 114.500: 45→60
- right leap 16st @ beat 114.500: 67→83
- right leap 15st @ beat 115.000: 79→64
- right leap 16st @ beat 115.500: 60→76
- right leap 28st @ beat 116.000: 76→48
- right leap 23st @ beat 116.000: 48→71
- right leap 28st @ beat 116.500: 71→43
- right leap 12st @ beat 116.500: 43→55
- right leap 26st @ beat 116.500: 62→88
- right leap 31st @ beat 117.000: 88→57
- right leap 12st @ beat 118.000: 71→59
- right leap 25st @ beat 118.000: 59→84
- right leap 22st @ beat 118.250: 84→62
- right leap 25st @ beat 118.500: 59→84

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
