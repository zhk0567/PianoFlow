# OMR audit — `ye_de_gang_qin_qu_5`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\ye_de_gang_qin_qu_5.pdf`
- MusicXML: `assets\scores\musicxml\ye_de_gang_qin_qu_5.musicxml`
- JSON: `assets\scores\ye_de_gang_qin_qu_5.json`
- JSON ≡ reparse: **True** (255/255 notes)
- BPM JSON/parse: 120 / 100
- keySignature JSON/parse: -3 / -3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=120) — practice tempo may be a catalog default
- clef-octave-change present {'1': 1} — verify concert pitch vs notation (do not double-apply in JSON)
- 55 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', '1')]`
- has_key: True
- has_tempo: False
- octave_changes: `{'1': 1}`
- times: `{}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 2.000: 72→84
- right leap 12st @ beat 10.000: 91→79
- right leap 12st @ beat 18.500: 87→75
- right leap 14st @ beat 18.500: 75→89
- right leap 12st @ beat 19.500: 89→77
- right leap 24st @ beat 45.000: 99→75
- right leap 15st @ beat 59.000: 94→79
- right leap 12st @ beat 76.000: 87→75
- right leap 14st @ beat 76.000: 75→89
- right leap 12st @ beat 77.000: 89→77
- right leap 16st @ beat 81.500: 91→75
- left leap 19st @ beat 4.000: 67→48
- left leap 19st @ beat 8.000: 63→44
- left leap 14st @ beat 12.000: 60→46
- left leap 17st @ beat 12.000: 46→63
- left leap 19st @ beat 16.000: 62→43
- left leap 22st @ beat 16.000: 43→65
- left leap 15st @ beat 17.000: 65→50
- left leap 12st @ beat 17.000: 50→62
- left leap 14st @ beat 20.000: 48→62
- left leap 19st @ beat 24.000: 63→44
- left leap 14st @ beat 28.000: 60→46
- left leap 17st @ beat 28.000: 46→63
- left leap 17st @ beat 32.000: 65→48
- left leap 19st @ beat 36.000: 67→48
- left leap 19st @ beat 40.000: 63→44
- left leap 14st @ beat 44.000: 60→46
- left leap 17st @ beat 44.000: 46→63
- left leap 14st @ beat 48.000: 62→48
- left leap 17st @ beat 48.000: 48→65

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
