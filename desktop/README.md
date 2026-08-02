# 叙叨 Web / PC（本机定制）

基于官方 [TangSengDaoDaoWeb](https://github.com/TangSengDaoDao/TangSengDaoDaoWeb)，在 `packages/tsdaodaobase` 中接入与 iOS 相同的 Hermes 协议：

| type | 说明 |
|------|------|
| `21000` | 审批 / 确认 / 澄清交互卡（`::hermes_card::{json}`） |
| `21001` | 按钮回传（静默，不进会话气泡；`::hermes_action::{json}`） |
| `21002` | 结构化表格（`::hermes_table::{json}`；气泡 / 详情 / 复制 HTML+TSV） |
| `21003` | 音频播报（`::hermes_audio::{json}`；气泡 + 会话顶栏播放条） |

另含：`/` 斜杠指令、`@bot` inline GIF、消息翻译（侧栏设置 + 长按 + 气泡译文）。

信封：`::hermes_card|table|audio::{json}`（Robot API 仅允许 type=1 时使用）。协议与对齐清单见 `../docs/hermes-*.md`、`../docs/hermes-web-parity.md`。

## 开发

建议 Node ≥ 18、Yarn 1.22。日常联调优先用本机 dev，不要依赖未重建的旧 `:82` 镜像。

```bash
cd desktop
yarn install
yarn dev
```

浏览器打开控制台提示的本地地址（通常 `http://localhost:3000`）。

默认 API：`http://127.0.0.1:8090/v1/`（与本仓库 Docker 栈一致）。

覆盖地址：

```bash
REACT_APP_API_URL=http://192.168.5.249:8090/v1/ yarn dev
```

## Docker（Compose `:82`）

根目录 `docker-compose.yaml` 的 `tangsengdaodaoweb` 使用 **`Dockerfile.ghcr`**（nginx + 本机构建产物），镜像名 `shudo-web:local`。生产静态资源走 nginx，`/api/` 代理到 API。

```bash
cd ~/Projects/tsdd/desktop
yarn install
yarn build

cd ~/Projects/tsdd
docker compose build tangsengdaodaoweb
docker compose up -d tangsengdaodaoweb
```

打开 http://127.0.0.1:82 。改完前端后需重新 `yarn build` + `docker compose build` 才会反映到 `:82`；本地热更新仍用 `yarn dev`（`:3000`）。

完整多阶段构建（容器内 `yarn install && yarn build`）可用 `Dockerfile`，但首次拉 `node` 镜像可能很慢。

## Electron 桌面包

```bash
yarn build
yarn build-ele:mac   # 或 win / linux
```

## Hermes 相关代码

- `packages/tsdaodaobase/src/Messages/Hermes/` — 卡片 / 表格 / 音频 UI
- `packages/tsdaodaobase/src/Service/HermesPayload.ts` — 信封解包
- `packages/tsdaodaobase/src/Service/HermesActionStore.ts` — 本地已选态
- `packages/tsdaodaobase/src/Service/HermesAudioPlayer.ts` — 顶栏播放器
- `packages/tsdaodaobase/src/Components/HermesAudioBar/` — 顶栏 UI
- `packages/tsdaodaobase/src/Service/HermesSlashCommands.ts` / `RobotMenusService.ts` — 斜杠
- `packages/tsdaodaobase/src/Service/InlineQuery.ts` — `@bot` inline
- `packages/tsdaodaobase/src/Service/TranslateManager.ts` — 翻译
