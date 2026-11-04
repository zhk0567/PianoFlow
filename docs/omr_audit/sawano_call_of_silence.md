# OMR audit — `sawano_call_of_silence`

- Generated: 2026-10-18 09:48
- scoreKind: **omrDraft**
- PDF: `third_party\scores_pdf\sawano_call_of_silence.pdf`
- MusicXML: `assets\scores\musicxml\sawano_call_of_silence.musicxml`
- JSON: `assets\scores\sawano_call_of_silence.json`
- JSON ≡ reparse: **True** (603/603 notes)
- BPM JSON/parse: 60 / 60
- keySignature JSON/parse: 0 / 0
- Promote to formal? **NO** (automated audits never promote)

## Issues
- (none)

## Warnings
- omrDraft: PDF image proofreading required before scoreKind=formal
- 122 same-hand leap(s) ≥12 semitones (OMR risk)
- 30 unusual duration value(s)

## MusicXML structure
- clefs: `[('F', '4', None), ('G', '2', None)]`
- has_key: True
- has_tempo: True
- octave_changes: `{}`
- times: `{"('4', '4')": 1}`

## Same-hand leaps ≥12st
- right leap 13st @ beat 28.000: 77→64
- right leap 12st @ beat 85.500: 88→76
- right leap 12st @ beat 111.000: 76→88
- right leap 14st @ beat 111.500: 88→74
- right leap 12st @ beat 111.500: 74→86
- right leap 12st @ beat 112.000: 86→74
- right leap 12st @ beat 112.000: 74→86
- right leap 14st @ beat 112.250: 86→72
- right leap 12st @ beat 112.250: 72→84
- right leap 12st @ beat 112.500: 84→72
- right leap 12st @ beat 112.500: 72→84
- right leap 12st @ beat 112.750: 79→91
- right leap 19st @ beat 113.000: 91→72
- right leap 12st @ beat 113.000: 72→84
- right leap 13st @ beat 113.500: 84→71
- right leap 12st @ beat 113.500: 71→83
- right leap 12st @ beat 113.750: 72→84
- right leap 12st @ beat 116.000: 84→72
- right leap 12st @ beat 116.000: 72→84
- right leap 12st @ beat 117.500: 76→88
- right leap 14st @ beat 117.750: 88→74
- right leap 12st @ beat 117.750: 74→86
- right leap 12st @ beat 120.000: 86→74
- right leap 12st @ beat 120.000: 74→86
- right leap 14st @ beat 120.250: 86→72
- right leap 12st @ beat 120.250: 72→84
- right leap 19st @ beat 120.500: 84→65
- right leap 14st @ beat 120.500: 65→79
- right leap 12st @ beat 120.750: 76→88
- right leap 14st @ beat 121.000: 88→74

## Promote blockers
- Human visual proofread against PDF not automated (PDF is image-only).
- Policy: omrDraft must not become formal without checklist in 曲谱导入SOP.md

## Next human steps
1. Open PDF + MusicXML in MuseScore side-by-side
2. Check opening 8 bars, mid 8, ending 8 vs PDF (SOP checklist)
3. Fix MusicXML, re-run `python .\scripts\musicxml_to_score.py --id ...`
4. Re-run this audit; only then set `scoreKind: formal`
