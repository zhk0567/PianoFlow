# OMR audit — `beethoven_moonlight_sonata`

- Generated: 2026-08-04 19:37
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\beethoven_moonlight_sonata.pdf`
- MusicXML: `assets\scores\musicxml\beethoven_moonlight_sonata.musicxml`
- JSON: `assets\scores\beethoven_moonlight_sonata.json`
- JSON ≡ reparse: **True** (1168/1168 notes)
- BPM JSON/parse: 44 / 44
- keySignature JSON/parse: 4 / 4
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 252 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 22.000: 56→68
- right leap 12st @ beat 23.000: 68→56
- right leap 12st @ beat 23.000: 56→68
- right leap 12st @ beat 27.000: 56→68
- right leap 12st @ beat 28.000: 68→56
- right leap 12st @ beat 28.000: 56→68
- right leap 12st @ beat 31.000: 57→69
- right leap 12st @ beat 33.000: 56→68
- right leap 14st @ beat 37.000: 57→71
- right leap 12st @ beat 37.333: 71→59
- right leap 12st @ beat 49.000: 55→67
- right leap 12st @ beat 50.000: 67→55
- right leap 12st @ beat 50.000: 55→67
- right leap 12st @ beat 54.000: 55→67
- right leap 12st @ beat 55.000: 67→55
- right leap 12st @ beat 55.000: 55→67
- right leap 12st @ beat 59.000: 66→54
- right leap 12st @ beat 74.500: 59→71
- right leap 13st @ beat 75.500: 59→72
- right leap 12st @ beat 79.500: 59→71
- right leap 13st @ beat 81.333: 59→72
- right leap 12st @ beat 82.833: 59→71
- right leap 12st @ beat 83.833: 59→71
- right leap 12st @ beat 84.833: 59→71
- right leap 12st @ beat 85.833: 57→69
- right leap 12st @ beat 92.333: 61→73
- right leap 12st @ beat 94.167: 61→73
- right leap 12st @ beat 95.167: 60→72
- right leap 12st @ beat 96.000: 63→75
- right leap 12st @ beat 97.500: 63→75

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
