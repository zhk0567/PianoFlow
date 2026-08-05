# jay_chou_qing_tian SOP 校对清单（已通过）

Score id: jay_chou_qing_tian
对照 PDF: third_party/scores_pdf/jay_chou_qing_tian.pdf
升 formal 日期: 2026-08-04

## 验收项（曲谱导入SOP）

| 项 | 状态 | 证据 |
|----|------|------|
| 源是 MusicXML（非 MIDI） | ✅ | OMR→校对后 MusicXML |
| 调号 / 拍号 / 速度 | ✅ | PDF 节拍器写入 + catalog BPM |
| 起句 8 小节 | ✅ | _sop_spotcheck.md OPEN + PDF p1 |
| 中段 8 小节 | ✅ | _sop_spotcheck.md MID |
| 尾段 8 小节 | ✅ | _sop_spotcheck.md END |
| JSON≡MusicXML | ✅ | omr_audit equal |
| catalog scoreKind | ✅ formal | omr_promote_formal.py --confirm-sop-passed |

## 结论

SOP 开/中/尾抽检通过；已升 **formal**。对照见 [PROOFREAD_STATUS.md](./PROOFREAD_STATUS.md)、[_sop_spotcheck.md](./_sop_spotcheck.md)。
