# OMR audit — `animenz_grand_escape`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_grand_escape.pdf`
- MusicXML: `assets\scores\musicxml\animenz_grand_escape.musicxml`
- JSON: `assets\scores\animenz_grand_escape.json`
- JSON ≡ reparse: **True** (2814/2814 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 4 / 4
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 864 same-hand leap(s) ≥12 semitones (OMR risk)
- 21 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 16.000: 73→85
- right leap 12st @ beat 22.000: 83→71
- right leap 12st @ beat 24.000: 73→85
- right leap 12st @ beat 30.000: 83→71
- right leap 12st @ beat 32.000: 73→85
- right leap 14st @ beat 33.500: 73→87
- right leap 12st @ beat 34.500: 80→92
- right leap 19st @ beat 35.000: 92→73
- right leap 19st @ beat 35.000: 73→92
- right leap 14st @ beat 36.500: 87→73
- right leap 12st @ beat 36.750: 73→85
- right leap 12st @ beat 38.000: 83→71
- right leap 12st @ beat 38.000: 71→83
- right leap 12st @ beat 39.250: 71→83
- right leap 12st @ beat 40.000: 73→85
- right leap 14st @ beat 41.500: 73→87
- right leap 12st @ beat 42.500: 80→92
- right leap 19st @ beat 43.000: 92→73
- right leap 19st @ beat 43.000: 73→92
- right leap 14st @ beat 44.500: 87→73
- right leap 12st @ beat 44.750: 73→85
- right leap 12st @ beat 46.000: 83→71
- right leap 12st @ beat 46.000: 71→83
- right leap 12st @ beat 47.250: 71→83
- right leap 12st @ beat 48.000: 73→85
- right leap 14st @ beat 49.500: 73→87
- right leap 12st @ beat 50.500: 80→92
- right leap 19st @ beat 51.000: 92→73
- right leap 19st @ beat 51.000: 73→92
- right leap 14st @ beat 52.500: 87→73

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
