# OMR audit — `animenz_key_trilogy`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_key_trilogy.pdf`
- MusicXML: `assets\scores\musicxml\animenz_key_trilogy.musicxml`
- JSON: `assets\scores\animenz_key_trilogy.json`
- JSON ≡ reparse: **True** (5364/5364 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 1068 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 11, "('3', '4')": 18, "('2', '4')": 9, "('6', '8')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 1.500: 86→73
- right leap 12st @ beat 3.500: 85→73
- right leap 12st @ beat 7.500: 88→76
- right leap 12st @ beat 12.500: 93→81
- right leap 21st @ beat 16.000: 90→69
- right leap 12st @ beat 35.000: 71→59
- right leap 16st @ beat 72.000: 78→62
- right leap 12st @ beat 75.000: 76→64
- right leap 21st @ beat 76.500: 78→57
- right leap 12st @ beat 85.500: 81→69
- right leap 12st @ beat 91.000: 76→64
- right leap 17st @ beat 108.000: 83→66
- right leap 12st @ beat 113.000: 79→67
- right leap 12st @ beat 113.000: 67→79
- right leap 13st @ beat 114.250: 79→66
- right leap 12st @ beat 114.250: 66→78
- right leap 12st @ beat 115.000: 78→66
- right leap 12st @ beat 115.000: 66→78
- right leap 12st @ beat 115.500: 78→66
- right leap 12st @ beat 115.500: 66→78
- right leap 12st @ beat 116.000: 67→79
- right leap 12st @ beat 117.000: 69→81
- right leap 13st @ beat 118.250: 83→70
- right leap 12st @ beat 118.250: 70→82
- right leap 14st @ beat 119.000: 82→68
- right leap 12st @ beat 119.000: 68→80
- right leap 12st @ beat 119.500: 80→68
- right leap 12st @ beat 119.500: 68→80
- right leap 17st @ beat 120.000: 80→63
- right leap 12st @ beat 120.000: 63→75

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
