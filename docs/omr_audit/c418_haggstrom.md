# OMR audit — `c418_haggstrom`

- Generated: 2026-08-04 21:09
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\c418_haggstrom.pdf`
- MusicXML: `assets\scores\musicxml\c418_haggstrom.musicxml`
- JSON: `assets\scores\c418_haggstrom.json`
- JSON ≡ reparse: **True** (456/456 notes)
- BPM JSON/parse: 100 / 100
- keySignature JSON/parse: 1 / 1
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- MusicXML has no tempo; parser default bpm=100 (JSON bpm=100) — practice tempo may be a catalog default
- 103 same-hand leap(s) ≥12 semitones (OMR risk)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: False
- octave_changes: `{}`
- times: `{}`

## Same-hand leaps ≥12st
- right leap 12st @ beat 79.667: 81→69
- right leap 12st @ beat 80.667: 76→64
- right leap 12st @ beat 82.667: 81→69
- right leap 19st @ beat 88.000: 61→80
- right leap 14st @ beat 89.000: 80→66
- right leap 12st @ beat 102.000: 73→85
- right leap 19st @ beat 103.000: 85→66
- right leap 12st @ beat 105.000: 81→69
- right leap 12st @ beat 106.000: 76→64
- right leap 12st @ beat 108.000: 81→69
- right leap 12st @ beat 130.000: 79→67
- right leap 12st @ beat 135.000: 79→67
- right leap 12st @ beat 145.000: 79→67
- right leap 12st @ beat 150.000: 79→67
- right leap 13st @ beat 156.000: 84→71
- right leap 16st @ beat 157.000: 83→67
- right leap 12st @ beat 158.000: 79→67
- right leap 12st @ beat 162.000: 79→67
- right leap 12st @ beat 164.000: 79→67
- right leap 12st @ beat 169.000: 72→84
- right leap 12st @ beat 182.000: 72→84
- right leap 12st @ beat 184.000: 84→72
- right leap 12st @ beat 186.000: 79→67
- right leap 15st @ beat 189.000: 79→64
- right leap 12st @ beat 194.000: 79→67
- right leap 19st @ beat 197.000: 79→60
- right leap 12st @ beat 197.000: 60→72
- left leap 12st @ beat 29.000: 48→60
- left leap 12st @ beat 30.667: 60→48
- left leap 12st @ beat 30.667: 48→60

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
