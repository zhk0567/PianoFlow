# OMR 草稿校对状态 / Proofread Status

更新：2026-08-09（机器-only：时长层 bad=0 + type←duration 对齐 1040 音；**无一升 formal**）  
规则：未完成开/中/尾 PDF 逐音抽检前 **禁止** `scoreKind: formal`。用户确认不做人眼校对 → 只改进 `omrDraft`，不放宽升格。

## 汇总

| 档 | 数量 | 含义 |
|----|------|------|
| A 五线 Audiveris | 12 | 仍 omrDraft；城堡 m21–24 / Silence m11–14 / 铃芽尾 等待人工 |
| B 简谱转写 | 3 | wish / pure / an_he 仍 omrDraft |
| 已升 formal | 11 | 月光 + 小星星/粉刷匠/Blowin'/`bella_ciao`/`ju_hua_tai`/`whistle`/`ye_de` 等 |

当前 catalog：formal×11 + omrDraft×15 = 26。

---

## A · 五线谱 Audiveris OMR

| id | 标题 | 状态 | 备注 |
|----|------|------|------|
| `sawano_call_of_silence` | Call of Silence | **m1–10 + m15–19 既有；m11–14 未改** | `_silence_sop/sys*`+`bars/m11–14` 已重渲；RH 多源不一致 **禁止猜改**；8va/尾未签 |
| `ru_yuan` | 如愿 | 开篇+短拍已修 | 中后段音高待细校 |
| `jay_chou_qing_tian` | 晴天 | 开篇+时长垫片；声部时长 bad=0 | 音高后段待细校 |
| `christina_perri_a_thousand_years` | A Thousand Years | intro–m18 | m19+ 待续（曲长） |
| `xiang_yun_duan` | 向云端 | m1–6；tiny-over trim；时长 bad=0 | 音高后段待续 |
| `jue_bie_shu` | 诀别书 | m1–7 | m8+ 待续 |
| `radwimps_suzume` | 铃芽之旅 | **m0–26 已大幅对齐 PDF；尾短拍已垫** | 见 `radwimps_suzume_SOP.md`；m27–29 几何读音不稳未猜改音高；时长 mismatch=0；**仍 omrDraft** |
| `haruhikage` | 春日影 | m1–8；m5 type-2x 已减半；时长 bad=0 | m9+ 音高待续；大跳仍 OMR 风险 |
| `hisaishi_castle_in_the_sky` | 天空之城 | 开篇+m49；**m21–24 未改** | SOP 多源不一致，禁止猜改 |
| `rush_e` | Rush E | m1+m4 | m5+ 待续 |
| `rimsky_flight_of_the_bumblebee` | 野蜂飞舞 | 开篇八度；休止/短拍时长修；bad=0 | 密谱音高高风险 |
| `clayderman_reve_damour` | 梦中的婚礼 | pickup + 尾段时值 | 中段待细校 |

### 已升 formal（原 A 档）

| id | 标题 | 状态 |
|----|------|------|
| `beethoven_moonlight_sonata` | 月光奏鸣曲 | **formal** |

### 工具

```powershell
# 一过性修谱脚本已迁 scripts/_archive/；日常只用：
python .\scripts\omr_audit_score.py --id <id>
python .\scripts\omr_promote_formal.py --id <id> --confirm-sop-passed
```

---

## B · 简谱 PDF → 转写草稿

| id | 状态 | 备注 |
|----|------|------|
| `xiao_xing_xing` / `fen_shua_jiang` / `bella_ciao` / `ju_hua_tai` / `whistle` / `ye_de_gang_qin_qu_5` | **formal** | 已 SOP |
| `when_you_wish_upon_a_star` | omrDraft | 密谱/多声部；OCR 不足全曲 |
| `pure_imagination` | omrDraft | PDF 长于 XML；未假补全 |
| `an_he_qiao` | omrDraft | 中/尾 RH 时值多源不一致 |

---

## 机器-only 下一优先（不升 formal）

1. **音高债**（无 MuseScore/第二权威不猜改）：铃芽 m27–29、Silence m11–14、城堡 m21–24；各曲中后段  
2. 春日影等同手大跳：疑似跨谱表/八度 OMR 错，勿按启发式瞎翻八度  
3. 节奏/时值/type 显示层：已收口；再动需新证据  

已修：伪 `divisions`、type-2x 小节、pad/trim/clamp、`type`←`duration`（见 `scripts/_archive/` 内 `_fix_omr_duration_doubling.py` 等一过脚本）。

## 诚实声明

用户不做人眼看谱；机器继续改进可练性与时值，但 **formal×11 + omrDraft×15 不变**，禁止把草稿标正式谱。
