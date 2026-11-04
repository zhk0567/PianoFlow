# OMR audit — `bios_guilty_crown`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\bios_guilty_crown.pdf`
- MusicXML: `assets\scores\musicxml\bios_guilty_crown.musicxml`
- JSON: `assets\scores\bios_guilty_crown.json`
- JSON ≡ reparse: **True** (3723/3723 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 3 / 3
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 875 same-hand leap(s) ≥12 semitones (OMR risk)
- 10 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 14st @ beat 34.000: 73→59
- right leap 14st @ beat 41.000: 73→59
- right leap 17st @ beat 45.000: 71→54
- right leap 15st @ beat 53.000: 71→56
- right leap 12st @ beat 62.000: 66→78
- right leap 12st @ beat 63.000: 78→66
- right leap 14st @ beat 64.000: 66→80
- right leap 15st @ beat 65.000: 80→65
- right leap 12st @ beat 70.000: 66→78
- right leap 12st @ beat 71.000: 78→66
- right leap 14st @ beat 72.000: 66→80
- right leap 15st @ beat 73.000: 80→65
- right leap 16st @ beat 89.000: 77→61
- right leap 16st @ beat 91.750: 70→54
- right leap 12st @ beat 91.750: 54→66
- right leap 12st @ beat 92.250: 66→54
- right leap 12st @ beat 92.250: 54→66
- right leap 12st @ beat 92.750: 66→78
- right leap 13st @ beat 93.000: 78→65
- right leap 12st @ beat 94.000: 78→66
- right leap 12st @ beat 94.500: 90→78
- right leap 17st @ beat 95.000: 78→61
- right leap 36st @ beat 96.000: 90→54
- right leap 12st @ beat 96.000: 54→66
- right leap 12st @ beat 97.000: 66→54
- right leap 12st @ beat 97.500: 75→63
- right leap 12st @ beat 97.500: 63→75
- right leap 16st @ beat 98.000: 77→61
- right leap 12st @ beat 98.500: 89→77
- right leap 16st @ beat 99.000: 77→61

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
