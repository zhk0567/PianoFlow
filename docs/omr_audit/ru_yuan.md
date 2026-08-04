# OMR audit — `ru_yuan`

- Generated: 2026-07-30 16:53
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\ru_yuan.pdf`
- MusicXML: `assets\scores\musicxml\ru_yuan.musicxml`
- JSON: `assets\scores\ru_yuan.json`
- JSON ≡ reparse: **True** (486/486 notes)
- BPM JSON/parse: 72 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=72) — practice tempo may be a catalog default
- 34 same-hand leap(s) ≥12 semitones (OMR risk)
- 25 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 24.333: 77→65
- right leap 12st @ beat 26.167: 76→64
- right leap 12st @ beat 92.417: 81→69
- right leap 12st @ beat 92.667: 69→81
- left leap 14st @ beat 4.000: 57→43
- left leap 13st @ beat 14.000: 53→40
- left leap 17st @ beat 20.000: 60→43
- left leap 15st @ beat 25.667: 60→45
- left leap 20st @ beat 27.667: 60→40
- left leap 19st @ beat 33.500: 57→38
- left leap 23st @ beat 39.250: 64→41
- left leap 12st @ beat 41.083: 53→41
- left leap 15st @ beat 44.833: 55→40
- left leap 19st @ beat 48.667: 57→38
- left leap 19st @ beat 54.667: 64→45
- left leap 18st @ beat 58.417: 65→47
- left leap 19st @ beat 62.417: 64→45
- left leap 18st @ beat 66.083: 59→41
- left leap 17st @ beat 71.750: 62→45
- left leap 19st @ beat 77.750: 64→45
- left leap 18st @ beat 81.250: 59→41
- left leap 17st @ beat 87.250: 62→45
- left leap 14st @ beat 91.000: 59→45
- left leap 15st @ beat 92.667: 60→45
- left leap 14st @ beat 96.167: 64→50
- left leap 20st @ beat 98.167: 65→45
- left leap 19st @ beat 101.833: 64→45
- left leap 15st @ beat 103.833: 60→45
- left leap 14st @ beat 109.750: 62→48
- left leap 17st @ beat 117.417: 62→45

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
