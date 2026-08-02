# Hermes / 输入能力：iOS ↔ Web 对齐清单

基于 iOS `WuKongBase` 与 `desktop/packages/tsdaodaobase`（叙叨 Web）对照。  
**日常开发请用 `desktop` 的 http://localhost:3000**（热更新）。Compose `:82` 已改为构建本仓库 `desktop/`（`shudo-web:local`）；改前端后需 `docker compose build tangsengdaodaoweb` 才会更新 `:82`。

协议文档：

- [hermes-approval-protocol.md](./hermes-approval-protocol.md) — `21000` / `21001`
- [hermes-table-protocol.md](./hermes-table-protocol.md) — `21002`
- [hermes-audio-protocol.md](./hermes-audio-protocol.md) — `21003`

## 能力矩阵

| 功能 | 协议 | iOS | desktop Web | 同步状态 |
|------|------|-----|-------------|----------|
| 交互卡（审批/确认/澄清） | `21000` `::hermes_card::` | ✅ | ✅ `Messages/Hermes/` | 已齐 |
| 按钮回传（静默不进气泡） | `21001` `::hermes_action::` | ✅ | ✅ `HermesActionStore` | 已齐 |
| 结构化表格 | `21002` `::hermes_table::` | ✅ 气泡/详情/复制 HTML+TSV | ✅ 气泡/模态/复制 | 基本齐 |
| 音频播报（非语音消息） | `21003` `::hermes_audio::` | ✅ 气泡 + 顶栏 `AVPlayer` | ✅ 气泡 + 顶栏播放条 | **P0 已补** |
| 信封解包 | markers → types | ✅ `WKHermesPayload` | ✅ 含 audio | 已齐 |
| `/` 斜杠指令 | robot command | ✅ 服务端 menus + 实体发送 | ✅ menus sync + `bot_command`/`robot_id` | **P1 已补** |
| 机器人 inline query（`@bot`） | `robot/inline_query` | ✅ GIF 面板 | ✅ GIF 面板 | **P1 已补** |
| 富文本输入 + 表格粘贴 | `format=html` | ✅ TipTap WebView | ✅ `RichComposerPanel` | 已齐（宿主 UX 不同） |
| 消息翻译 | HTTP `:8091` | ✅ 设置/长按/气泡 | ✅ 设置/长按/气泡 | **P1 已补** |
| Liquid Glass / 导航搜索 | — | ✅ | N/A | 不需要 |

## Web 同步 backlog

### P0 — 音频播报 ✅

已实现：`HermesPayload` 解包、`HermesAudioContent`/`HermesAudioCell`（含 `Audio.css`）、会话顶栏 `HermesAudioBar`（`HTMLAudioElement`）；会话区用 flex 避免顶栏挤掉消息列表高度。

### ~~P0 — 音频播报~~（完成）

~~1. ...~~

### P1 — 斜杠 / 机器人输入 ✅

- 接入 `POST robot/sync`，合并服务端 menus + 本地中文兜底  
- 发送带 `entities: [{type: bot_command}]` 与 `robot_id`（`RobotCommandText`）  
- `@username query` → `robot/inline_query`，GIF 结果横向面板（对齐 iOS）

### P1 — 翻译 ✅

- 侧栏「翻译设置」：自动翻译 + 目标语言  
- 长按菜单「翻译 / 显示原文」  
- 文本气泡下方展示译文；自动翻译入站消息  

### P1 — 表格抛光 ✅

- `pct_color`、复制全部（HTML+TSV）、详情可选中文本、⋯ 增删行列均已具备  
- HTML 消息含 `<table>` 时复制走 `htmlToPlainTextWithTables` 

### P2 — 发布 ✅

- `docker-compose.yaml` 的 `tangsengdaodaoweb` → `build: ./desktop`（`Dockerfile.ghcr`），镜像 `shudo-web:local`  
- 流程：本机 `cd desktop && yarn build`，再 `docker compose build tangsengdaodaoweb && docker compose up -d tangsengdaodaoweb`  
- `desktop/README.md` / 根 `README.md` 已写明 `21000`–`21003` 与 `:82` 重建方式

## iOS 关键文件（对照用）

| 能力 | 主要路径 |
|------|----------|
| 卡/动作 | `WKHermesCardCell` / `WKHermesActionContent` / `WKHermesActionStore` |
| 表格 | `WKHermesTableCell` / `WKBubbleMessageDetailVC` |
| 音频 | `WKHermesAudioCell` / `WKHermesAudioBar` / `WKConversationView` |
| 解包 | `WuKongIMSDK/.../WKHermesPayload.m` / `WKMessageUtil.m` |
| 富文本 | `WKRichComposerVC` / `WKRichEditorPool` / `WKRichEditorWebView` |
| 斜杠 | `WKConversationView+Robot.m` / `WKSlashCommandSuggestView` |
| 翻译 | `WKTranslateManager` / `WKTranslateSettingVC` / `WKTextMessageCell` |

## Web 已有路径

| 能力 | 主要路径 |
|------|----------|
| 卡/表格 | `desktop/packages/tsdaodaobase/src/Messages/Hermes/` |
| 解包 | `.../Service/HermesPayload.ts` |
| 斜杠 | `.../Service/HermesSlashCommands.ts` / `MessageInput` |
| 富文本 | `desktop/packages/rich-editor/` + `Conversation` 内 `RichComposerPanel` |
