# OMR audit — `c418_wet_hands`

- Generated: 2026-08-04 21:11
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_wet_hands.pdf`
- MusicXML: `assets\scores\musicxml\c418_wet_hands.musicxml`
- JSON: `assets\scores\c418_wet_hands.json`
- JSON ≡ reparse: **True** (239/239 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 3 / 3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 24 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 29.500: 66→54
- right leap 12st @ beat 30.000: 54→66
- right leap 12st @ beat 59.500: 64→76
- right leap 12st @ beat 60.000: 66→78
- right leap 12st @ beat 60.833: 78→66
- right leap 12st @ beat 60.833: 66→78
- right leap 14st @ beat 68.833: 78→64
- right leap 14st @ beat 71.833: 73→59
- right leap 20st @ beat 80.833: 59→79
- left leap 12st @ beat 8.000: 57→45
- left leap 12st @ beat 16.000: 57→45
- left leap 12st @ beat 24.000: 57→45
- left leap 14st @ beat 32.000: 57→43
- left leap 14st @ beat 40.000: 57→43
- left leap 12st @ beat 48.000: 57→45
- left leap 12st @ beat 57.000: 59→47
- left leap 14st @ beat 60.833: 61→47
- left leap 18st @ beat 64.833: 61→43
- left leap 12st @ beat 68.833: 57→45
- left leap 17st @ beat 72.833: 57→40
- left leap 12st @ beat 88.833: 52→40
- left leap 16st @ beat 92.833: 56→40
- left leap 16st @ beat 96.833: 56→40
- left leap 12st @ beat 100.833: 52→40

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
