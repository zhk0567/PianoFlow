# OMR audit — `c418_droopy_likes_ricochet`

- Generated: 2026-08-04 21:15
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_droopy_likes_ricochet.pdf`
- MusicXML: `assets\scores\musicxml\c418_droopy_likes_ricochet.musicxml`
- JSON: `assets\scores\c418_droopy_likes_ricochet.json`
- JSON ≡ reparse: **True** (290/290 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no <key>/fifths — OMR often drops key signature
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 16 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: False
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 14st @ beat 36.500: 79→65
- right leap 14st @ beat 52.500: 79→65
- right leap 12st @ beat 70.500: 74→62
- right leap 12st @ beat 86.500: 74→62
- right leap 14st @ beat 92.500: 74→60
- right leap 12st @ beat 92.500: 60→72
- right leap 12st @ beat 102.500: 74→62
- right leap 14st @ beat 108.500: 74→60
- right leap 12st @ beat 108.500: 60→72
- right leap 16st @ beat 124.500: 76→60
- right leap 12st @ beat 124.500: 60→72
- right leap 12st @ beat 136.500: 76→64
- left leap 12st @ beat 34.500: 65→53
- left leap 12st @ beat 48.500: 53→65
- left leap 12st @ beat 50.500: 65→53
- left leap 12st @ beat 64.500: 53→41

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
