# OMR audit — `beethoven_moonlight_sonata`

- Generated: 2026-07-30 16:53
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\beethoven_moonlight_sonata.pdf`
- MusicXML: `assets\scores\musicxml\beethoven_moonlight_sonata.musicxml`
- JSON: `assets\scores\beethoven_moonlight_sonata.json`
- JSON ≡ reparse: **True** (1169/1169 notes)
- BPM JSON/parse: 54 / 100
- keySignature JSON/parse: 4 / 4
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=54) — practice tempo may be a catalog default
- 244 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{}`

## Same-hand leaps ≥12st
- right leap 24st @ beat 0.000: 56→80
- right leap 19st @ beat 0.333: 80→61
- right leap 12st @ beat 27.500: 56→68
- right leap 12st @ beat 33.000: 56→68
- right leap 12st @ beat 36.000: 57→69
- right leap 12st @ beat 39.000: 56→68
- right leap 12st @ beat 43.500: 71→59
- right leap 12st @ beat 58.500: 55→67
- right leap 12st @ beat 64.000: 55→67
- right leap 12st @ beat 68.000: 54→66
- right leap 13st @ beat 85.500: 59→72
- right leap 12st @ beat 90.000: 59→71
- right leap 13st @ beat 95.500: 59→72
- right leap 12st @ beat 100.000: 59→71
- right leap 12st @ beat 103.000: 59→71
- right leap 12st @ beat 106.000: 59→71
- right leap 12st @ beat 109.000: 57→69
- right leap 12st @ beat 128.500: 61→73
- right leap 12st @ beat 134.000: 61→73
- right leap 12st @ beat 137.000: 60→72
- right leap 12st @ beat 139.500: 63→75
- right leap 12st @ beat 144.000: 63→75
- right leap 12st @ beat 145.500: 64→76
- right leap 12st @ beat 148.500: 63→75
- right leap 12st @ beat 151.500: 72→60
- right leap 12st @ beat 161.500: 52→64
- right leap 12st @ beat 164.000: 76→64
- right leap 16st @ beat 193.500: 82→66
- right leap 12st @ beat 267.500: 71→59
- right leap 12st @ beat 267.500: 59→71

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
