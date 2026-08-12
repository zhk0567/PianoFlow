# SOP 开/中/尾 — `radwimps_suzume`

日期：2026-08-09  
对照 PDF：`third_party/scores_pdf/radwimps_suzume.pdf`  
MusicXML：`assets/scores/musicxml/radwimps_suzume.musicxml`  
证据：`docs/omr_audit/_suzume_proof/`  
结论：**未通过全曲 — 禁止 formal**

## 验收清单

- [x] 源为 MusicXML（非 MIDI）
- [x] 调号/拍号/速度：key=0、4/4、♩=80
- [ ] 开篇 / 中段 / 尾段 **全部**逐音通过（尾段 m27–29 未重签）
- [ ] `scoreKind: formal`（**未晋升**）

## 本轮已对齐（相对 PDF 系统裁切）

| 段 | 小节 | 状态 |
|----|------|------|
| OPEN | m0–7 | 保留既有开篇校对稿 |
| MID | m8–15 | 自 `7615330` 恢复（撤销错误半音符主题重写） |
| MID | m16–26 | `_fix_suzume_m16_end.py` 按 `auto_p1_sys3–5` / `auto_p2_sys1` 重写 |
| END | m27–29 | **未重签**（PDF 末系统未逐音） |

## 阻塞 formal

1. m27–29（及 PDF 是否另有收束小节）未 MuseScore 逐音  
2. m16/m18/m24 等密段仍建议人工过目一次  
3. 开/中/尾清单未全部勾选  

```powershell
# 仅在全曲 SOP 通过后：
python .\scripts\omr_promote_formal.py --id radwimps_suzume --confirm-sop-passed
```
