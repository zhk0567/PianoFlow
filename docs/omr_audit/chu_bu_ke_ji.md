# OMR audit — `chu_bu_ke_ji`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\chu_bu_ke_ji.pdf`
- MusicXML: `assets\scores\musicxml\chu_bu_ke_ji.musicxml`
- JSON: `assets\scores\chu_bu_ke_ji.json`
- JSON ≡ reparse: **True** (400/400 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 206 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 0.250: 81→69
- right leap 12st @ beat 2.000: 69→81
- right leap 12st @ beat 2.250: 81→69
- right leap 12st @ beat 4.000: 69→81
- right leap 12st @ beat 4.250: 81→69
- right leap 12st @ beat 6.000: 69→81
- right leap 12st @ beat 6.250: 81→69
- right leap 12st @ beat 8.000: 69→81
- right leap 12st @ beat 8.250: 81→69
- right leap 12st @ beat 10.000: 69→81
- right leap 12st @ beat 10.250: 81→69
- right leap 12st @ beat 12.000: 69→81
- right leap 12st @ beat 12.250: 81→69
- right leap 12st @ beat 14.000: 69→81
- right leap 12st @ beat 14.250: 81→69
- right leap 12st @ beat 16.500: 81→69
- right leap 12st @ beat 17.000: 81→69
- right leap 12st @ beat 17.500: 81→69
- right leap 12st @ beat 18.000: 81→69
- right leap 12st @ beat 18.500: 81→69
- right leap 12st @ beat 19.000: 81→69
- right leap 12st @ beat 19.500: 81→69
- right leap 12st @ beat 20.000: 81→69
- right leap 22st @ beat 21.500: 81→59
- right leap 12st @ beat 21.500: 59→71
- right leap 12st @ beat 22.000: 60→72
- right leap 12st @ beat 22.500: 64→76
- right leap 12st @ beat 23.000: 67→79
- right leap 12st @ beat 23.500: 71→83
- right leap 14st @ beat 24.000: 83→69

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
