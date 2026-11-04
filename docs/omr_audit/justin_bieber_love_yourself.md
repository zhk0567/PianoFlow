# OMR audit — `justin_bieber_love_yourself`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\justin_bieber_love_yourself.pdf`
- MusicXML: `assets\scores\musicxml\justin_bieber_love_yourself.musicxml`
- JSON: `assets\scores\justin_bieber_love_yourself.json`
- JSON ≡ reparse: **True** (1246/1246 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 12 same-hand leap(s) ≥12 semitones (OMR risk)
- 3 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 65.500: 60→72
- right leap 12st @ beat 224.500: 72→60
- right leap 12st @ beat 232.500: 72→60
- right leap 12st @ beat 247.000: 67→79
- right leap 12st @ beat 255.000: 76→88
- left leap 12st @ beat 28.000: 60→48
- left leap 18st @ beat 32.000: 59→41
- left leap 12st @ beat 60.000: 60→48
- left leap 12st @ beat 140.000: 60→48
- left leap 12st @ beat 220.000: 60→48
- left leap 12st @ beat 236.000: 60→48
- left leap 12st @ beat 252.000: 60→48

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
