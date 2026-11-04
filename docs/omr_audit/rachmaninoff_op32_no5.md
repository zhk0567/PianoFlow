# OMR audit — `rachmaninoff_op32_no5`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\rachmaninoff_op32_no5.pdf`
- MusicXML: `assets\scores\musicxml\rachmaninoff_op32_no5.musicxml`
- JSON: `assets\scores\rachmaninoff_op32_no5.json`
- JSON ≡ reparse: **True** (1213/1213 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 59 same-hand leap(s) ≥12 semitones (OMR risk)
- 12 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 2, "('2', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 25.500: 71→83
- right leap 12st @ beat 29.500: 71→83
- right leap 12st @ beat 31.500: 62→74
- right leap 14st @ beat 33.500: 71→57
- right leap 25st @ beat 40.000: 54→79
- right leap 12st @ beat 53.500: 71→83
- right leap 12st @ beat 57.500: 71→83
- right leap 12st @ beat 60.500: 62→74
- right leap 14st @ beat 61.500: 60→74
- right leap 12st @ beat 62.500: 62→74
- right leap 12st @ beat 64.500: 62→74
- right leap 14st @ beat 65.500: 60→74
- right leap 15st @ beat 66.500: 59→74
- right leap 12st @ beat 69.500: 57→69
- right leap 12st @ beat 73.500: 57→69
- right leap 20st @ beat 92.000: 66→46
- right leap 15st @ beat 100.000: 59→74
- right leap 20st @ beat 100.250: 79→59
- right leap 15st @ beat 101.000: 59→74
- right leap 31st @ beat 102.000: 74→43
- right leap 23st @ beat 108.000: 60→83
- right leap 12st @ beat 113.000: 91→79
- right leap 20st @ beat 126.000: 74→54
- right leap 18st @ beat 132.000: 61→79
- right leap 14st @ beat 133.250: 88→74
- right leap 32st @ beat 147.500: 91→59
- right leap 12st @ beat 149.500: 71→59
- left leap 22st @ beat 16.000: 67→45
- left leap 14st @ beat 16.000: 45→59
- left leap 24st @ beat 24.000: 38→62

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
