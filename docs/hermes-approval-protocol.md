# Hermes × 叙叨 审批消息协议（v1）

两端（iOS 原生 / 未来 Tauri 桌面）共用同一套 payload。服务端不改协议也可投递：走机器人 `sendMessage` 的自定义 `payload.type`。

## 目标

- Hermes 发出「危险命令 / 确认 / 澄清」类交互卡
- 用户点按钮（或文本回落）后，动作回到 Hermes，解除阻塞
- 未升级客户端仍可用文本完成审批

## 内容类型

| type | 常量建议 | 用途 |
|------|----------|------|
| `21000` | `WK_HERMES_CARD` | Hermes 下发的交互卡（审批 / 确认 / 澄清） |
| `21001` | `WK_HERMES_ACTION` | 客户端点击按钮后回传的动作 |
| `21002` | `WK_HERMES_TABLE` | 结构化表格（见 [hermes-table-protocol.md](./hermes-table-protocol.md)） |
| `1` | 文本 | 回落：未识别自定义类型时的说明文案；或用户手打动作 |

自定义号段落在唐僧文档的 **20000–30000** 本地/扩展区；`21000/21001` 专供 Hermes，避免与其它业务冲突。

> **实现备注（v1.5 官方 Robot API）**：`/robots/.../sendMessage` **只允许** `payload.type = 1`（文本）。因此下发卡实际以文本信封投递：
> ```
> <人类可读正文>
>
> ::hermes_card::{...21000 JSON...}
> ```
> 私有 iOS 在 `WKMessageUtil` 解码时还原为 `21000` 并渲染按钮；未升级客户端只看到正文。按钮回传优先使用 `::hermes_action::<action>:<id>` 文本。

## 下发卡：`type = 21000`

```json
{
  "type": 21000,
  "v": 1,
  "kind": "hermes.approval",
  "approval_id": "a1b2c3d4e5f6",
  "title": "Command Approval Required",
  "body": "rm -rf /tmp/demo",
  "description": "dangerous command",
  "content": "⚠️ 需要审批\n\nrm -rf /tmp/demo\n\n回复 once / session / always / deny\n或 ::hermes_action::once:a1b2c3d4e5f6",
  "buttons": [
    { "id": "once", "label": "✅ Allow Once", "style": "primary" },
    { "id": "session", "label": "✅ Session", "style": "secondary" },
    { "id": "always", "label": "✅ Always", "style": "secondary" },
    { "id": "deny", "label": "❌ Deny", "style": "danger" }
  ],
  "meta": {
    "session_hint": "optional opaque",
    "smart_denied": false
  }
}
```

### 字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `v` | 是 | 协议版本，当前 `1` |
| `kind` | 是 | `hermes.approval` / `hermes.confirm` / `hermes.clarify` |
| `approval_id` | 审批必填 | 短 id；客户端回传必须原样带上 |
| `confirm_id` | confirm 必填 | 与 Hermes `send_slash_confirm` 对齐 |
| `clarify_id` | clarify 必填 | 与 Hermes clarify 对齐 |
| `title` | 是 | 卡片标题 |
| `body` | 否 | 主内容（命令、说明正文） |
| `description` | 否 | 次要说明 |
| `content` | 是 | **会话摘要 / 未知客户端可读文本**（务必人类可读） |
| `buttons[].id` | 是 | 动作 id：`once` / `session` / `always` / `deny` / `cancel` 或自定义 |
| `buttons[].label` | 是 | 按钮文案 |
| `buttons[].style` | 否 | `primary` / `secondary` / `danger` |

### `kind` 与 Hermes API 对应

| kind | Hermes 适配器方法 | 典型按钮 |
|------|-------------------|----------|
| `hermes.approval` | `send_exec_approval` | once / session / always / deny |
| `hermes.confirm` | `send_slash_confirm` | once / always / cancel |
| `hermes.clarify` | `send_clarify` | 选项 id = `choice_0`… / `other`（适配器映射为选项原文） |

## 回传动作：`type = 21001`

客户端点击按钮后，向**同一频道**发一条消息（from = 用户）：

```json
{
  "type": 21001,
  "v": 1,
  "kind": "hermes.action",
  "approval_id": "a1b2c3d4e5f6",
  "action": "once",
  "source_message_id": "optional-origin-msg-id",
  "content": "::hermes_action::once:a1b2c3d4e5f6"
}
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `action` | 是 | 与按钮 `id` 一致 |
| `approval_id` / `confirm_id` / `clarify_id` | 其一 | 与下发卡一致 |
| `content` | 建议 | 文本回落同构，便于日志与未升级适配器识别 |

### 文本回落（无按钮 UI 时）

用户直接发文本（任一即可）：

```text
::hermes_action::once:a1b2c3d4e5f6
```

或 Hermes 原有斜杠（适配器不拦截时由网关处理）：

```text
/approve
/deny
```

## 机器人 API 用法

下发：

```http
POST /v1/robots/{robot_id}/{app_key}/sendMessage
{
  "channel_id": "<peer_uid 或 group_id>",
  "channel_type": 1,
  "payload": { /* 21000 对象 */ }
}
```

回传：客户端走正常发消息；机器人轮询 `events` 拿到 `payload.type == 21001` 或文本 `::hermes_action::...`，调用：

```python
from tools.approval import resolve_gateway_approval
resolve_gateway_approval(session_key, choice)  # choice: once|session|always|deny
```

## 客户端实现要点

1. 注册 `contentType = 21000` 的 Cell / 组件：标题 + 正文 + 按钮行  
2. 点击后发 `21001`，按钮置灰；可选本地把原卡标为已决  
3. 未实现按钮前：至少把 `content` 当文本展示  
4. **不要**把 `approval_id` 映射成 Hermes `session_key`（仅适配器内存映射）

## 桌面（Web / Electron）与 iOS

协议相同；仅渲染层不同。

- iOS：`ios/Modules/WuKongBase/.../Messages/WKHermes*`
- 桌面：`desktop/`（基于官方 TangSengDaoDaoWeb），见 `desktop/README.md`
  - `packages/tsdaodaobase/src/Messages/Hermes/`
  - 信封解包：`Service/HermesPayload.ts` / `Service/Convert.ts`
  - 静默 `21001`、本地已选态与 iOS 对齐

下一步（协议演进）：`21002` 表格卡（股票对比等），勿塞进 `21000`。

## 版本演进

- `v=1`：审批 / 确认 / 澄清信封 + 文本回落  
- 后续：`status` 字段（pending/resolved）、服务端代改原消息（若 API 支持）  

## 相关代码

- Hermes 插件：`~/.hermes/plugins/platforms/tsdd/adapter.py`  
- 机器人环境：`hermes-robot.env`（勿提交密钥）  
