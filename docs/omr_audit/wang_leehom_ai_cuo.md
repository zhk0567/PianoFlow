# OMR audit — `wang_leehom_ai_cuo`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\wang_leehom_ai_cuo.pdf`
- MusicXML: `assets\scores\musicxml\wang_leehom_ai_cuo.musicxml`
- JSON: `assets\scores\wang_leehom_ai_cuo.json`
- JSON ≡ reparse: **True** (2062/2062 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 4 / 4
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 363 same-hand leap(s) ≥12 semitones (OMR risk)
- 2 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '3', None), ('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 17.000: 60→73
- right leap 12st @ beat 25.000: 61→73
- right leap 15st @ beat 29.500: 65→80
- right leap 12st @ beat 29.500: 80→92
- right leap 14st @ beat 30.000: 92→78
- right leap 12st @ beat 30.000: 78→90
- right leap 13st @ beat 30.500: 90→77
- right leap 12st @ beat 30.500: 77→89
- right leap 14st @ beat 31.000: 89→75
- right leap 12st @ beat 31.000: 75→87
- right leap 14st @ beat 31.500: 87→73
- right leap 12st @ beat 31.500: 73→85
- right leap 15st @ beat 32.000: 85→70
- right leap 12st @ beat 42.000: 68→80
- right leap 22st @ beat 43.500: 80→58
- right leap 15st @ beat 43.500: 58→73
- right leap 17st @ beat 44.000: 73→56
- right leap 22st @ beat 48.000: 53→75
- right leap 15st @ beat 53.000: 75→60
- right leap 12st @ beat 60.000: 79→67
- right leap 12st @ beat 64.000: 79→67
- right leap 14st @ beat 70.500: 89→75
- right leap 12st @ beat 70.500: 75→87
- right leap 15st @ beat 71.000: 87→72
- right leap 12st @ beat 71.000: 72→84
- right leap 14st @ beat 71.500: 84→70
- right leap 12st @ beat 71.750: 75→87
- right leap 12st @ beat 72.000: 87→75
- right leap 12st @ beat 76.000: 79→67
- right leap 12st @ beat 79.250: 75→63

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
