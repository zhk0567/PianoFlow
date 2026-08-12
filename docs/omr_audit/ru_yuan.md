# OMR audit — `ru_yuan`

- Generated: 2026-08-09 11:54
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\ru_yuan.pdf`
- MusicXML: `assets\scores\musicxml\ru_yuan.musicxml`
- JSON: `assets\scores\ru_yuan.json`
- JSON ≡ reparse: **True** (484/484 notes)
- BPM JSON/parse: 66 / 66
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 38 same-hand leap(s) ≥12 semitones (OMR risk)
- 39 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 24.333: 77→65
- right leap 12st @ beat 26.500: 76→64
- right leap 14st @ beat 96.417: 83→69
- right leap 15st @ beat 96.667: 69→84
- left leap 14st @ beat 2.000: 55→41
- left leap 14st @ beat 6.000: 55→41
- left leap 14st @ beat 10.000: 55→41
- left leap 17st @ beat 20.000: 60→43
- left leap 12st @ beat 26.000: 57→45
- left leap 15st @ beat 26.333: 45→60
- left leap 20st @ beat 28.000: 60→40
- left leap 12st @ beat 34.833: 45→57
- left leap 23st @ beat 42.000: 64→41
- left leap 15st @ beat 46.000: 55→40
- left leap 14st @ beat 50.000: 52→38
- left leap 12st @ beat 50.833: 45→57
- left leap 19st @ beat 56.000: 64→45
- left leap 13st @ beat 60.000: 60→47
- left leap 18st @ beat 60.000: 47→65
- left leap 19st @ beat 64.500: 64→45
- left leap 18st @ beat 68.000: 59→41
- left leap 12st @ beat 74.000: 57→45
- left leap 17st @ beat 74.167: 45→62
- left leap 19st @ beat 80.500: 64→45
- left leap 18st @ beat 84.000: 59→41
- left leap 17st @ beat 90.000: 62→45
- left leap 14st @ beat 96.000: 59→45
- left leap 12st @ beat 96.667: 45→57
- left leap 14st @ beat 100.250: 64→50
- left leap 20st @ beat 104.000: 65→45

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
