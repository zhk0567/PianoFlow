# OMR audit — `matryoshka_sacred_play`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\matryoshka_sacred_play.pdf`
- MusicXML: `assets\scores\musicxml\matryoshka_sacred_play.musicxml`
- JSON: `assets\scores\matryoshka_sacred_play.json`
- JSON ≡ reparse: **True** (1231/1231 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 305 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 86.000: 83→71
- right leap 12st @ beat 97.000: 83→71
- right leap 12st @ beat 97.750: 71→83
- right leap 12st @ beat 99.000: 82→70
- right leap 13st @ beat 99.750: 70→83
- right leap 12st @ beat 101.000: 83→71
- right leap 12st @ beat 105.000: 83→71
- right leap 12st @ beat 105.750: 71→83
- right leap 12st @ beat 107.000: 82→70
- right leap 13st @ beat 107.750: 70→83
- right leap 12st @ beat 113.000: 83→71
- right leap 12st @ beat 113.750: 71→83
- right leap 12st @ beat 115.000: 82→70
- right leap 13st @ beat 115.750: 70→83
- right leap 12st @ beat 117.000: 83→71
- right leap 12st @ beat 121.000: 85→73
- right leap 12st @ beat 121.750: 73→85
- right leap 12st @ beat 125.000: 83→71
- right leap 12st @ beat 198.000: 83→71
- right leap 12st @ beat 206.500: 66→78
- right leap 12st @ beat 207.000: 78→66
- right leap 12st @ beat 207.000: 66→78
- right leap 12st @ beat 207.750: 73→85
- right leap 14st @ beat 208.000: 85→71
- right leap 12st @ beat 208.000: 71→83
- right leap 12st @ beat 209.000: 83→71
- right leap 12st @ beat 209.750: 71→83
- right leap 13st @ beat 210.000: 83→70
- right leap 12st @ beat 210.000: 70→82
- right leap 12st @ beat 211.000: 82→70

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
