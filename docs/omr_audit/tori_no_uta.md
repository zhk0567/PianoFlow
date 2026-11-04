# OMR audit — `tori_no_uta`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\tori_no_uta.pdf`
- MusicXML: `assets\scores\musicxml\tori_no_uta.musicxml`
- JSON: `assets\scores\tori_no_uta.json`
- JSON ≡ reparse: **True** (5550/5550 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 1011 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 10, "('3', '4')": 8, "('6', '8')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 1.500: 86→73
- right leap 12st @ beat 3.500: 85→73
- right leap 12st @ beat 7.500: 88→76
- right leap 12st @ beat 11.500: 93→81
- right leap 21st @ beat 16.000: 90→69
- right leap 12st @ beat 35.000: 71→59
- right leap 12st @ beat 75.000: 76→64
- right leap 14st @ beat 75.500: 78→64
- right leap 12st @ beat 75.500: 69→81
- right leap 21st @ beat 76.500: 78→57
- right leap 12st @ beat 85.500: 81→69
- right leap 12st @ beat 91.000: 76→64
- right leap 14st @ beat 91.500: 78→64
- right leap 12st @ beat 91.500: 69→81
- right leap 12st @ beat 108.500: 83→71
- right leap 12st @ beat 111.000: 80→92
- right leap 12st @ beat 111.500: 92→80
- right leap 12st @ beat 111.500: 80→92
- right leap 12st @ beat 112.250: 92→80
- right leap 12st @ beat 112.250: 80→92
- right leap 12st @ beat 112.500: 92→80
- right leap 12st @ beat 112.500: 80→92
- right leap 12st @ beat 113.000: 92→80
- right leap 12st @ beat 113.000: 80→92
- right leap 14st @ beat 114.250: 92→78
- right leap 12st @ beat 114.250: 78→90
- right leap 12st @ beat 114.500: 90→78
- right leap 12st @ beat 114.500: 78→90
- right leap 12st @ beat 115.000: 90→78
- right leap 12st @ beat 115.000: 78→90

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
