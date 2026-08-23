# PianoFlow 跨端契约

## 谱面

- **交换格式**：MusicXML（`.musicxml` / `.xml`）
- **质量档 `scoreKind`**（必须诚实）：
  - `formal` — 已校对 / 教材级；**禁止**未校对 OMR 或 MIDI 冒充
  - `omrDraft` — OMR 草稿（UI：「OMR草稿」）
  - `simplified` — 简化谱
  - `userImport` — 用户导入；**永远不是** formal

## 曲目清单

- Schema：[`catalog.schema.json`](./catalog.schema.json)
- 样例：[`samples/catalog.json`](./samples/catalog.json)
- 样例谱：[`samples/musicxml/`](./samples/musicxml/)

各端只读本契约即可进练；账号云同步为二期，不在四端收工范围内。
