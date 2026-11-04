# OMR audit — `animenz_kuusou_mesorogiwi`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_kuusou_mesorogiwi.pdf`
- MusicXML: `assets\scores\musicxml\animenz_kuusou_mesorogiwi.musicxml`
- JSON: `assets\scores\animenz_kuusou_mesorogiwi.json`
- JSON ≡ reparse: **True** (2670/2670 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 1108 same-hand leap(s) ≥12 semitones (OMR risk)
- 40 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('2', '4')": 4}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 0.000: 75→87
- right leap 19st @ beat 0.333: 87→68
- right leap 12st @ beat 0.333: 68→80
- right leap 12st @ beat 0.667: 80→68
- right leap 12st @ beat 0.667: 68→80
- right leap 12st @ beat 1.000: 80→68
- right leap 12st @ beat 1.000: 68→80
- right leap 12st @ beat 3.000: 90→78
- right leap 12st @ beat 3.083: 77→89
- right leap 14st @ beat 3.167: 89→75
- right leap 12st @ beat 3.167: 75→87
- right leap 13st @ beat 8.000: 78→65
- right leap 12st @ beat 8.500: 77→65
- right leap 12st @ beat 10.000: 77→65
- right leap 13st @ beat 11.375: 77→64
- right leap 13st @ beat 12.500: 75→62
- right leap 12st @ beat 12.750: 75→63
- right leap 16st @ beat 14.375: 78→62
- right leap 21st @ beat 15.500: 75→54
- right leap 13st @ beat 16.250: 73→60
- right leap 24st @ beat 16.500: 82→58
- right leap 13st @ beat 16.750: 70→57
- right leap 19st @ beat 17.500: 75→56
- right leap 12st @ beat 18.000: 70→58
- right leap 16st @ beat 18.500: 72→56
- right leap 12st @ beat 19.875: 80→68
- right leap 27st @ beat 20.000: 68→41
- right leap 17st @ beat 20.000: 41→58
- right leap 12st @ beat 20.375: 85→73
- right leap 19st @ beat 20.500: 77→58

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
