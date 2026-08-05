# OMR audit — `c418_door`

- Generated: 2026-08-04 21:06
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_door.pdf`
- MusicXML: `assets\scores\musicxml\c418_door.musicxml`
- JSON: `assets\scores\c418_door.json`
- JSON ≡ reparse: **True** (336/336 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -1 / -1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 32 same-hand leap(s) ≥12 semitones (OMR risk)
- 2 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 26.667: 58→70
- right leap 12st @ beat 27.000: 70→58
- right leap 12st @ beat 27.000: 58→70
- right leap 12st @ beat 76.000: 79→67
- right leap 16st @ beat 78.000: 76→60
- right leap 12st @ beat 100.000: 69→81
- right leap 16st @ beat 101.000: 81→65
- right leap 12st @ beat 101.000: 67→79
- right leap 19st @ beat 102.500: 79→60
- right leap 16st @ beat 110.000: 76→60
- right leap 14st @ beat 128.000: 67→53
- right leap 12st @ beat 133.500: 65→77
- right leap 12st @ beat 157.000: 76→64
- right leap 12st @ beat 158.000: 72→60
- right leap 12st @ beat 159.500: 69→57
- left leap 12st @ beat 39.000: 54→42
- left leap 12st @ beat 39.000: 42→54
- left leap 12st @ beat 43.000: 54→42
- left leap 12st @ beat 43.000: 42→54
- left leap 22st @ beat 47.000: 54→32
- left leap 24st @ beat 102.500: 29→53
- left leap 24st @ beat 107.000: 53→29
- left leap 12st @ beat 111.000: 29→41
- left leap 12st @ beat 115.000: 34→46
- left leap 24st @ beat 132.000: 55→31
- left leap 12st @ beat 132.000: 31→43
- left leap 12st @ beat 136.000: 43→31
- left leap 12st @ beat 136.000: 31→43
- left leap 12st @ beat 140.000: 45→57
- left leap 12st @ beat 144.000: 57→45

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
