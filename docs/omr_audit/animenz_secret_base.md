# OMR audit — `animenz_secret_base`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\animenz_secret_base.pdf`
- MusicXML: `assets\scores\musicxml\animenz_secret_base.musicxml`
- JSON: `assets\scores\animenz_secret_base.json`
- JSON ≡ reparse: **True** (2046/2046 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 6 / 6
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 343 same-hand leap(s) ≥12 semitones (OMR risk)
- 1 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2}`

## Same-hand leaps ≥12st
- right leap 15st @ beat 32.000: 63→78
- right leap 12st @ beat 66.000: 63→75
- right leap 24st @ beat 67.000: 87→63
- right leap 12st @ beat 70.500: 65→77
- right leap 26st @ beat 71.500: 89→63
- right leap 12st @ beat 74.500: 66→78
- right leap 32st @ beat 75.500: 90→58
- right leap 12st @ beat 82.000: 63→75
- right leap 24st @ beat 83.000: 87→63
- right leap 12st @ beat 87.000: 65→77
- right leap 24st @ beat 88.000: 89→65
- right leap 16st @ beat 92.000: 66→82
- right leap 26st @ beat 95.000: 94→68
- right leap 17st @ beat 98.000: 63→80
- right leap 12st @ beat 104.000: 75→63
- right leap 12st @ beat 108.000: 61→73
- right leap 12st @ beat 112.000: 75→63
- right leap 12st @ beat 176.000: 73→61
- right leap 12st @ beat 184.000: 70→58
- right leap 12st @ beat 204.000: 75→87
- right leap 13st @ beat 216.000: 90→77
- right leap 12st @ beat 220.000: 87→75
- right leap 12st @ beat 230.500: 90→78
- right leap 12st @ beat 231.000: 90→78
- right leap 12st @ beat 232.000: 90→78
- right leap 12st @ beat 248.000: 85→73
- right leap 19st @ beat 258.500: 87→68
- right leap 12st @ beat 260.000: 78→90
- right leap 17st @ beat 261.000: 90→73
- right leap 12st @ beat 283.500: 85→73

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
