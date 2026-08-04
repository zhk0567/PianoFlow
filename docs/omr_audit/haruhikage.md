# OMR audit — `haruhikage`

- Generated: 2026-07-30 16:53
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\haruhikage.pdf`
- MusicXML: `assets\scores\musicxml\haruhikage.musicxml`
- JSON: `assets\scores\haruhikage.json`
- JSON ≡ reparse: **True** (1161/1161 notes)
- BPM JSON/parse: 92 / 100
- keySignature JSON/parse: 5 / 5
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=92) — practice tempo may be a catalog default
- 334 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('6', '8')": 3}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 36.000: 66→78
- right leap 12st @ beat 36.500: 71→83
- right leap 12st @ beat 37.000: 83→71
- right leap 12st @ beat 39.500: 83→71
- right leap 14st @ beat 51.250: 78→64
- right leap 15st @ beat 56.750: 78→63
- right leap 19st @ beat 61.250: 73→54
- right leap 12st @ beat 68.250: 83→71
- right leap 12st @ beat 68.250: 71→83
- right leap 12st @ beat 71.250: 83→71
- right leap 12st @ beat 71.250: 71→83
- right leap 12st @ beat 72.250: 83→71
- right leap 12st @ beat 75.250: 66→78
- right leap 12st @ beat 75.750: 71→83
- right leap 12st @ beat 76.250: 83→71
- right leap 12st @ beat 77.750: 83→71
- right leap 14st @ beat 88.250: 78→64
- right leap 15st @ beat 93.750: 78→63
- right leap 16st @ beat 97.250: 70→54
- right leap 14st @ beat 108.250: 73→59
- right leap 12st @ beat 112.250: 59→71
- right leap 13st @ beat 112.500: 71→58
- right leap 12st @ beat 125.500: 71→83
- right leap 16st @ beat 136.000: 70→54
- right leap 22st @ beat 139.000: 73→51
- right leap 12st @ beat 139.000: 51→63
- right leap 14st @ beat 139.250: 63→49
- right leap 12st @ beat 139.250: 49→61
- right leap 12st @ beat 139.500: 51→63
- right leap 12st @ beat 140.000: 63→51

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
