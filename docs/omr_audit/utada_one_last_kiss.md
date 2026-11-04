# OMR audit — `utada_one_last_kiss`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\utada_one_last_kiss.pdf`
- MusicXML: `assets\scores\musicxml\utada_one_last_kiss.musicxml`
- JSON: `assets\scores\utada_one_last_kiss.json`
- JSON ≡ reparse: **True** (2891/2891 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 656 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('C', '2', None), ('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2, "('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 30.250: 78→66
- right leap 12st @ beat 30.750: 78→66
- right leap 14st @ beat 70.000: 87→73
- right leap 12st @ beat 76.750: 75→87
- right leap 14st @ beat 77.250: 87→73
- right leap 12st @ beat 77.250: 73→85
- right leap 14st @ beat 77.750: 85→71
- right leap 12st @ beat 77.750: 71→83
- right leap 12st @ beat 78.250: 83→71
- right leap 12st @ beat 78.250: 71→83
- right leap 12st @ beat 78.750: 75→87
- right leap 14st @ beat 79.250: 87→73
- right leap 12st @ beat 79.250: 73→85
- right leap 14st @ beat 79.750: 85→71
- right leap 12st @ beat 79.750: 71→83
- right leap 12st @ beat 80.250: 83→71
- right leap 12st @ beat 80.250: 71→83
- right leap 12st @ beat 80.750: 73→85
- right leap 14st @ beat 81.250: 85→71
- right leap 14st @ beat 86.000: 87→73
- right leap 12st @ beat 92.750: 75→87
- right leap 14st @ beat 93.250: 87→73
- right leap 12st @ beat 93.250: 73→85
- right leap 14st @ beat 93.750: 85→71
- right leap 12st @ beat 93.750: 71→83
- right leap 12st @ beat 94.250: 83→71
- right leap 12st @ beat 94.250: 71→83
- right leap 12st @ beat 94.750: 75→87
- right leap 14st @ beat 95.250: 87→73
- right leap 12st @ beat 95.250: 73→85

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
