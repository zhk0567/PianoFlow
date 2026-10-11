# SOP 开/中/尾签字 — `jue_bie_shu`（诀别书）

日期：2026-10-05（转正第 13 轮：按扫描重写中段多处；**未升 formal**）  
对照 PDF：`third_party/scores_pdf/jue_bie_shu.pdf`  
对照 MusicXML：`assets/scores/musicxml/jue_bie_shu.musicxml`  
证据：`docs/omr_audit/_jue_bie_shu_proof/insp_m69.png`、`insp_m77.png`、`insp_m85.png`、`insp_m89.png`  
结论：**未通过 — 禁止 formal**（中段还有对不上的小节，全音符未签）

## 来源与档位

| 项 | 现状 |
|----|------|
| 谱源 | PDF → OMR → 对照重写（**非 MIDI**） |
| `scoreKind` | **`omrDraft`** |
| 四端同步 | JSON/XML 已对齐（1753 notes） |

## 验收清单

- [x] 谱源 MusicXML，非 MIDI
- [x] key=-1、4/4、♩=96
- [ ] 开/中/尾 **全部**逐音通过（m1–13、m106–108 已对；R12/R13 按扫描改了中段一批。m56–68、m61–64、m104 等仍未签；全音符未逐一签）
- [ ] `scoreKind: formal`（**未晋升**）
- [x] 四端 MusicXML 对齐

## 抽检范围

| 段 | PDF | 小节 | 结论 |
|----|-----|------|------|
| OPEN | p1 | m1–8 | **与 PDF 一致** |
| OPEN | p1 | m9–12 | **R8：低音谱表改为高音谱号读音（F4+A4，保留音 B♭3）** |
| OPEN | p1 | m13 | **R9：右手与 PDF 一致；补上低音 A3 全音符，连到 m14** |
| MID | p1 | m14–22 | **实心符头与扫描一致**；全音符未另签 |
| MID | p2 | m32–39、m52、m55 | **实心符头与扫描一致** |
| MID | p3 | m69–71 左手 | **R10/R11：改为 C3+C4+E4+G4** |
| MID | p3 | m77 | **R11：按扫描重写右手 D4 / G4+B4 与左手 F3、A3+C4** |
| MID | p4 | m85、m89–91 左手 | **R11：D 小三改为 C 大三（C3+C4+E4+G4）** |
| MID | p3–p4 | 其余 m23–105 | **未逐音签完，禁止 formal** |
| END | p5 | m106–108 | **R8，本轮实心符头复核通过** |

## 本轮（R7）开篇重写

旧稿开篇为 `D5 C5 D5 F5` + 高位 Bb 柱式，与 PDF p1 系统（`r7_p1_s1_lines.png`）不符。

| 小节 | 新稿要点 |
|------|----------|
| m1 | RH F4–G4–A4–D5；LH F2 + BbDF |
| m2 | RH D5；LH BbDF |
| m3 | RH F4–G4–A4–C5；LH F2 + ACF |
| m4 | RH C5；LH ACF |
| m5 | RH F4–G4–A4–Bb4；LH F2 + GBbDF |
| m6 | RH Bb4；LH GBbDF |
| m7 | RH C6–A5–G5–F5；LH F2 C3 F3 G3 |
| m8 | RH F5；LH G3（替换先前 Bb 柱式） |

脚本：`scripts/_fix_jue_bie_shu_r7_open.py`。

## 本轮（R8）

- m9–12：PDF 低音谱表是高音谱号。旧稿按低音谱号把 F4+A4 记成 A2+C3。已上移十二个音级，并在 m9 写入高音谱号。
- m106–108：旧稿是全休止。PDF 第 5 页右手在 8va 下为 A5–D6–A5–G5 / 八分交替 / B5，左手高音谱号 C–E–G–C 连到结束。音高按实音写入（8va 高八度）。

脚本：`scripts/_fix_jue_bie_shu_r8.py`。

## 本轮（R9）

PDF 第 1 页 m13–14 这一行：低音谱表仍是高音谱号。和弦是四分休止 + E4+G4，下面还有一个 A3 全音符连到下一小节。旧稿只有 m14 的 A3，m13 没有，连线也断了。m14 末尾的低音谱号位置是对的（从 m15 起换低音谱号），没有往前挪。

脚本：`scripts/_fix_jue_bie_shu_r9.py`。证据：`docs/omr_audit/_jue_bie_shu_proof/p1_sys2.png`。

中段签完之前不要跑 `omr_promote_formal.py`。

## 本轮（R10）

五页扫描都按小节线对上了谱（25 行，小节数一致）。实心符头用谱线位置去对：m14–22、m32–39、m52、m55、m80、m102、m106–108 对得上。全音符、二分音符这轮没认（空心符头），不算签过。

m70、m71 左手四次都是同一个和弦。扫描位置比稿高四度，改成 C3 + C4/E4/G4。notes 仍是 1779。

其余对不上的（尤其 m48–51、m61–64、m74–79、m87–95、m100）没有改，避免把识别噪声写进谱。仍是 omrDraft。

脚本：`scripts/_fix_jue_bie_shu_r10.py`。对照：`scripts/_jbs_audit.py`。

## 本轮（R11）

m69 左手与 m70–71 同一套 C 和弦，旧稿还是 F。m85、m89–91 左手扫描也是 C3 + C4/E4/G4，旧稿写成 D 小三。m77 按第 3 页扫描重写：右手 D4、G4+B4、A4–G4–G4、两组 G4+B4、G4 E4；左手 F3 与 A3+C4 交替四次。notes 1779→1773。仍 omrDraft。

脚本：`scripts/_fix_jue_bie_shu_r11.py`。证据：`insp_m69.png`、`insp_m77.png`、`insp_m85.png`、`insp_m89.png`。

## 本轮（R12 / R13）

按扫描裁切重写：m48–51 右手（十六分、五度、附点），m73–76 / m78–79 中声部音型，m81 右手改成与 m85 相同的音阶，m86/m88/m98/m100 左手，m87 右手，m92 收束，m93–95 右手从 F6+A6 降到 G5/A5 音型，m103 右手 D5+F5。notes 1773→1753。m56–68、m61–64、m104 仍未按扫描逐音签完。禁止 formal。

脚本：`scripts/_fix_jue_bie_shu_r12.py`、`scripts/_fix_jue_bie_shu_r13.py`。
