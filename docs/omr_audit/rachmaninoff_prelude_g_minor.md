# OMR audit — `rachmaninoff_prelude_g_minor`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\rachmaninoff_prelude_g_minor.pdf`
- MusicXML: `assets\scores\musicxml\rachmaninoff_prelude_g_minor.musicxml`
- JSON: `assets\scores\rachmaninoff_prelude_g_minor.json`
- JSON ≡ reparse: **True** (2292/2292 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 569 same-hand leap(s) ≥12 semitones (OMR risk)
- 10 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 3}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 11.500: 70→58
- right leap 16st @ beat 13.500: 74→58
- right leap 12st @ beat 14.750: 79→67
- right leap 24st @ beat 15.000: 79→55
- right leap 12st @ beat 15.000: 55→67
- right leap 22st @ beat 15.250: 79→57
- right leap 12st @ beat 16.250: 78→66
- right leap 12st @ beat 16.500: 78→66
- right leap 24st @ beat 17.000: 78→54
- right leap 12st @ beat 20.000: 50→62
- right leap 12st @ beat 20.250: 74→62
- right leap 12st @ beat 20.500: 74→62
- right leap 19st @ beat 21.000: 74→55
- right leap 12st @ beat 22.750: 74→62
- right leap 12st @ beat 23.000: 74→62
- right leap 20st @ beat 23.500: 74→54
- right leap 12st @ beat 25.500: 69→57
- right leap 13st @ beat 28.000: 70→57
- right leap 12st @ beat 29.000: 67→55
- right leap 16st @ beat 32.000: 66→50
- right leap 12st @ beat 44.000: 70→58
- right leap 20st @ beat 47.500: 82→62
- right leap 12st @ beat 49.250: 78→66
- right leap 16st @ beat 49.500: 78→62
- right leap 12st @ beat 50.250: 82→70
- right leap 20st @ beat 50.500: 82→62
- right leap 20st @ beat 51.500: 82→62
- right leap 15st @ beat 54.000: 81→66
- right leap 21st @ beat 55.000: 79→58
- right leap 15st @ beat 58.000: 82→67

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
