# Hermes × 叙叨 表格消息协议（v1）

与审批卡共用信封思路；**独立类型 `21002`**，不要塞进 `21000`。

## 内容类型

| type | 常量 | 用途 |
|------|------|------|
| `21002` | `WK_HERMES_TABLE` / `hermesTable` | 结构化表格（股票对比等） |
| `1` | 文本 | 回落：未升级客户端只看 `content` 摘要 |

Robot API 仅允许 `type=1` 时，用文本信封：

```text
股票对比摘要…

::hermes_table::{...21002 JSON...}
```

## Payload：`type = 21002`

```json
{
  "type": 21002,
  "v": 1,
  "kind": "hermes.table",
  "title": "股票对比",
  "caption": "可选副标题",
  "content": "AAPL 190.2 +1.2% | MSFT 420.1 -0.3%",
  "columns": [
    { "id": "symbol", "label": "代码", "align": "left" },
    { "id": "price", "label": "现价", "align": "right" },
    { "id": "chg", "label": "涨跌%", "align": "right", "format": "pct_color" }
  ],
  "rows": [
    { "symbol": "AAPL", "price": "190.2", "chg": "+1.2%" },
    { "symbol": "MSFT", "price": "420.1", "chg": "-0.3%" }
  ],
  "meta": {}
}
```

### 字段

| 字段 | 必填 | 说明 |
|------|------|------|
| `v` | 是 | 协议版本，当前 `1` |
| `kind` | 是 | 固定 `hermes.table` |
| `title` | 建议 | 卡片标题 |
| `caption` | 否 | 副标题 / 说明 |
| `content` | 是 | **会话摘要 / 未升级客户端可读文本**（务必人类可读） |
| `columns[].id` | 是 | 列键，对应 `rows[]` 的字段名 |
| `columns[].label` | 是 | 表头文案 |
| `columns[].align` | 否 | `left` / `center` / `right`，默认 `left` |
| `columns[].format` | 否 | `text`（默认）/ `pct_color`（按首字符 `+`/`-` 着色） |
| `rows` | 是 | 对象数组；缺列显示为空字符串 |
| `meta` | 否 | 扩展 |

### 限制（客户端建议）

- 列数：建议 ≤ 6；过多横向滚动
- 行数：建议 ≤ 30；过多只渲染前 N 行并提示
- 单元格：纯文本，不做 HTML

## 客户端

- iOS：`WKHermesTableContent` / `WKHermesTableCell`
- 桌面：`Messages/Hermes/Table.*`
- 解包：与 `::hermes_card::` 同路径（`WKHermesPayload` / `HermesPayload.ts`）

## Hermes 适配器

`send_table(title, columns, rows, content=...)` → `_robot_text_envelope` 的表格变体（marker `::hermes_table::`）。
