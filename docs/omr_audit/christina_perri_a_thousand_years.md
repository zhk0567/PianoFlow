# OMR audit — `christina_perri_a_thousand_years`

- Generated: 2026-08-04 19:37
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\christina_perri_a_thousand_years.pdf`
- MusicXML: `assets\scores\musicxml\christina_perri_a_thousand_years.musicxml`
- JSON: `assets\scores\christina_perri_a_thousand_years.json`
- JSON ≡ reparse: **True** (969/969 notes)
- BPM JSON/parse: 50 / 50
- keySignature JSON/parse: -2 / -2
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 34 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('6', '8')": 1}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 63.000: 67→79
- right leap 12st @ beat 138.000: 67→79
- left leap 12st @ beat 0.000: 46→58
- left leap 19st @ beat 1.500: 65→46
- left leap 12st @ beat 1.500: 46→58
- left leap 19st @ beat 3.000: 65→46
- left leap 12st @ beat 3.000: 46→58
- left leap 20st @ beat 4.500: 65→45
- left leap 12st @ beat 4.500: 45→57
- left leap 22st @ beat 6.000: 65→43
- left leap 15st @ beat 6.000: 43→58
- left leap 22st @ beat 7.500: 65→43
- left leap 15st @ beat 7.500: 43→58
- left leap 22st @ beat 9.000: 65→43
- left leap 15st @ beat 9.000: 43→58
- left leap 24st @ beat 10.500: 65→41
- left leap 17st @ beat 10.500: 41→58
- left leap 26st @ beat 12.000: 65→39
- left leap 24st @ beat 12.000: 39→63
- left leap 28st @ beat 13.500: 67→39
- left leap 24st @ beat 13.500: 39→63
- left leap 28st @ beat 15.000: 67→39
- left leap 24st @ beat 15.000: 39→63
- left leap 28st @ beat 16.500: 67→39
- left leap 24st @ beat 16.500: 39→63
- left leap 22st @ beat 18.000: 63→41
- left leap 24st @ beat 18.000: 41→65
- left leap 24st @ beat 19.500: 65→41
- left leap 24st @ beat 19.500: 41→65
- left leap 24st @ beat 21.000: 65→41

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
