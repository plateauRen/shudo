# Hermes 音频播报协议（content type 21003）

与普通语音消息（`WK_VOICE`）完全分离。客户端在会话**顶栏播报条**播放，气泡内仅展示轻量卡片。

## 信封格式

机器人/服务端以 **type 1 文本**下发，正文含 marker + JSON：

```text
摘要文本（会话列表预览可用）
::hermes_audio::{"type":21003,"v":1,"kind":"hermes.audio","title":"播报标题","content":"摘要","url":"https://example.com/a.mp3","duration_ms":12000,"mime":"audio/mpeg"}
```

客户端在 `WKMessageUtil` / `HermesPayload` 中 unwrap 为 content type **21003**。

## Marker

| 项 | 值 |
|----|-----|
| Marker | `::hermes_audio::` |
| Content type | `21003` |
| kind | `hermes.audio` |

## Payload 字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | number | 是 | 固定 `21003` |
| `v` | number | 建议 | 协议版本，当前 `1` |
| `kind` | string | 是 | `hermes.audio` |
| `title` | string | 建议 | 顶栏与卡片标题 |
| `content` | string | 否 | 摘要文案 |
| `url` | string | 是 | `http`/`https` 或可下载路径 |
| `duration_ms` | number | 否 | 时长（毫秒），用于初始进度条 |
| `mime` | string | 否 | 如 `audio/mpeg` |
| `meta` | object | 否 | 扩展元数据 |

## 客户端行为

1. 列表/气泡：标题 +「在顶栏播放」，**不**复用语音波形 Cell。
2. 点击卡片或「播放」：会话顶栏绑定 `AVPlayer`（iOS）/ `HTMLAudioElement`（桌面），支持播放/暂停、进度拖动、关闭。
3. 同会话新到 Hermes 音频可替换当前顶栏条目。
4. 与 `WK_VOICE` 录音气泡互不影响。

## 对齐参考

信封解析顺序与卡片/表格一致，见 [hermes-table-protocol.md](./hermes-table-protocol.md) 与 `WKHermesPayload` / `HermesPayload.ts`。
