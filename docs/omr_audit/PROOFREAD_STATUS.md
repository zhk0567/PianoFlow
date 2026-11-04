# OMR 草稿校对状态 / Proofread Status

更新：2026-10-18（《铃芽之旅》第 2 页收口 + m31 补齐）  
规则：未完成开/中/尾 PDF 逐音抽检前 **禁止** `scoreKind: formal`。  
升格唯一入口：`python scripts/omr_promote_formal.py --id <id> --confirm-sop-passed`  
战役表：[docs/战役-企业级验收勾选.md](../战役-企业级验收勾选.md)

## 汇总（catalog 实数）

| 档 | 数量 | 含义 |
|----|------|------|
| formal | 12 | 已 SOP 升格 |
| omrDraft | 55 | 可练草稿；含 Downloads 批进 44 首 |
| simplified | 2 | 简谱档 |
| **合计** | **69** | `assets/scores/catalog.json` |
| policyOmr | 55 | 与 omrDraft 一一对应 |

---

## formal（已升）

| id | 标题 |
|----|------|
| `fur_elise_woo59` | 致爱丽丝 |
| `pachelbel_canon_d` | 卡农 |
| `toby_fox_megalovania` | Megalovania |
| `beethoven_moonlight_sonata` | 月光奏鸣曲 |
| `xiao_xing_xing` | 小星星 |
| `fen_shua_jiang` | 粉刷匠 |
| `blowin_in_the_wind` | Blowin' in the Wind |
| `bella_ciao` | Bella Ciao |
| `whistle` | Whistle |
| `ju_hua_tai` | 菊花台 |
| `jue_bie_shu` | 诀别书（2026-10-18：开篇修正 + 结尾 m103–m106 重建，SOP 通过） |
| `radwimps_suzume` | 铃芽之旅（2026-10-18：m27–29 复核，补齐 m31，页 2 小节对齐，SOP 通过） |

> 注：`ye_de_gang_qin_qu_5` 曾 formal，Downloads 新 PDF 覆盖后现为 **omrDraft**（新谱为准，未再校对前不升）。

---

## P4 升格队列（企业级）

### 1. 已完成（2026-10-18）

| id | 状态 | 债 |
|----|------|-----|
| `jue_bie_shu` | **formal**；新六页 PDF OMR + 人工开/中/尾校对 | 开篇 5 处修正；结尾 m103–m106 重建（含 8va）；`JSON ≡ XML`；见 `jue_bie_shu_SOP.md` |
| `radwimps_suzume` | **formal**；PDF 两页拆分 OMR + 开/中/尾复核 | m23 八度修正；m27–29 复核；m31 终止和弦补齐；页 2 去重并补 m29；`JSON ≡ XML` |

### 2. PROOFREAD 点名债（禁止猜改）

| id | 债 |
|----|-----|
| `sawano_call_of_silence` | m11–14 多源不一致；新 PDF 覆盖后需重抽检 |
| `hisaishi_castle_in_the_sky` | m21–24 未改 |

### 3. 高练 / 新进 omrDraft（抽样）

Downloads 批进（均为 omrDraft，待 SOP）：  
`animenz_*`、`queen_bohemian_rhapsody`、`truth_that_you_leave`、`bios_guilty_crown`、`tori_no_uta`、`sincerely_violet_evergarden` 等——完整列表见 catalog / `docs/omr_audit/_batch_import_report.json`。

每首升格前必须：开/中/尾各 ≥8 小节对照 `third_party/scores_pdf/<id>.pdf` + `omr_audit_score.py` + `*_SOP.md`。

---

## 工具

```powershell
.\scripts\enterprise-gates.ps1
python .\scripts\omr_audit_score.py --id <id>
python .\scripts\omr_promote_formal.py --id <id> --confirm-sop-passed
```

## 诚实声明

自动 OMR ≠ 出版级。企业级 = 可重复产线 + 诚实标注 + 校对过的才 formal。禁止未校对批量升格。
