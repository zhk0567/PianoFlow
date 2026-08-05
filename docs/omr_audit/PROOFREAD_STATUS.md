# OMR 人工校对进度（2026-08-04）

对照源：`third_party/scores_pdf/{id}.pdf`。

## 曲库谱种合计

| 档 | 数量 | 说明 |
|----|------|------|
| **formal** | 15 | 原教材 + 已升格前 12 首 OMR |
| **omrDraft** | **19** | 2026-08-04 新入库 C418 / Minecraft 钢琴 PDF |

`score_kind_policy.json` / Dart `omrProvenanceIds` = 上述 19 个 `c418_*` id。

---

## A. 已升 formal 的前批（12 首）

| id | BPM | SOP 开/中/尾 | formal |
|----|-----|--------------|--------|
| `hisaishi_castle_in_the_sky` 等 12 首 | — | ✅ | YES |

详见 git 历史与 `_sop_spotcheck.md`。另含 Fur Elise / Canon / Megalovania → **formal ×15**。

---

## B. 新入库 OMR 草稿（C418 ×19，未校对）

来源：用户提供的 Minecraft 钢琴 PDF（`Downloads/音乐/1..19.*.pdf`）。  
管线：`scripts/batch_import_c418_minecraft.ps1` → Audiveris → `omr-finish-import`（**固定 omrDraft**）。

| # | id | 曲名 | 状态 |
|---|----|------|------|
| 1 | `c418_key` | Key | omrDraft |
| 2 | `c418_door` | Door | omrDraft |
| 3 | `c418_subwoofer_lullaby` | Subwoofer Lullaby | omrDraft |
| 4 | `c418_death` | Death | omrDraft |
| 5 | `c418_living_mice` | Living Mice | omrDraft |
| 6 | `c418_dry_hands` | Dry Hands | omrDraft |
| 7 | `c418_moog_city` | Moog City | omrDraft |
| 8 | `c418_haggstrom` | Haggstrom | omrDraft |
| 9 | `c418_minecraft` | Minecraft | omrDraft |
| 10 | `c418_equinoxe` | Équinoxe | omrDraft |
| 11 | `c418_mice_on_venus` | Mice on Venus | omrDraft |
| 12 | `c418_wet_hands` | Wet Hands | omrDraft |
| 13 | `c418_clark` | Clark | omrDraft |
| 14 | `c418_excuse` | Excuse | omrDraft |
| 15 | `c418_sweden` | Sweden | omrDraft |
| 16 | `c418_clark_alt` | Clark (alt)（PDF #16） | omrDraft |
| 17 | `c418_danny` | Danny | omrDraft |
| 18 | `c418_droopy_likes_ricochet` | Droopy likes ricochet | omrDraft |
| 19 | `c418_beginning` | Beginning | omrDraft |

**诚实标注：** 未做 MuseScore 开/中/尾逐音；BPM 多为 OMR 默认；**禁止**标 formal，直到 `omr_promote_formal.py --confirm-sop-passed`。

PDF 归档：`third_party/scores_pdf/c418_*.pdf`  
原始副本：`third_party/scores_pdf/_c418_incoming/`

## 升 formal（以后）

```powershell
python .\scripts\omr_promote_formal.py --id c418_sweden --confirm-sop-passed
```

须先完成 `docs/omr_audit/<id>_SOP.md` 开/中/尾。

## 验证

```powershell
Set-Location F:\commercial\PianoFlow
python .\scripts\catalog_score_kind_guard.py
python .\scripts\catalog_integrity_guard.py
python .\scripts\score_kind_policy_sync.py --check
```

相关：[`曲谱导入SOP.md`](../曲谱导入SOP.md) · [`曲谱来源.md`](../曲谱来源.md)
