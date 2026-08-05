# OMR audit — `ru_yuan`

- Generated: 2026-08-04 19:37
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\ru_yuan.pdf`
- MusicXML: `assets\scores\musicxml\ru_yuan.musicxml`
- JSON: `assets\scores\ru_yuan.json`
- JSON ≡ reparse: **True** (486/486 notes)
- BPM JSON/parse: 66 / 66
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- 34 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: True
- octave_changes: `{}`
- times: `{"('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 24.500: 77→65
- right leap 12st @ beat 26.500: 76→64
- right leap 12st @ beat 95.417: 81→69
- right leap 12st @ beat 96.000: 69→81
- left leap 14st @ beat 4.000: 57→43
- left leap 13st @ beat 14.000: 53→40
- left leap 17st @ beat 20.000: 60→43
- left leap 15st @ beat 26.000: 60→45
- left leap 20st @ beat 28.000: 60→40
- left leap 19st @ beat 34.000: 57→38
- left leap 23st @ beat 40.000: 64→41
- left leap 12st @ beat 42.000: 53→41
- left leap 15st @ beat 46.000: 55→40
- left leap 19st @ beat 50.000: 57→38
- left leap 19st @ beat 56.000: 64→45
- left leap 18st @ beat 60.000: 65→47
- left leap 19st @ beat 64.000: 64→45
- left leap 18st @ beat 68.000: 59→41
- left leap 17st @ beat 74.000: 62→45
- left leap 19st @ beat 80.000: 64→45
- left leap 18st @ beat 84.000: 59→41
- left leap 17st @ beat 90.000: 62→45
- left leap 14st @ beat 94.000: 59→45
- left leap 15st @ beat 96.000: 60→45
- left leap 14st @ beat 100.000: 64→50
- left leap 20st @ beat 102.000: 65→45
- left leap 19st @ beat 106.000: 64→45
- left leap 15st @ beat 108.000: 60→45
- left leap 14st @ beat 114.000: 62→48
- left leap 17st @ beat 122.000: 62→45

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
