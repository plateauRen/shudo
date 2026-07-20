# 叙叨 Web / PC（本机定制）

基于官方 [TangSengDaoDaoWeb](https://github.com/TangSengDaoDao/TangSengDaoDaoWeb)，在 `packages/tsdaodaobase` 中接入与 iOS 相同的 Hermes 协议：

| type | 说明 |
|------|------|
| `21000` | 审批 / 确认 / 澄清交互卡 |
| `21001` | 按钮回传（静默，不进会话气泡） |

信封：`::hermes_card::{json}`（Robot API 仅允许 type=1 时使用）。

## 开发

建议 Node ≥ 18、Yarn 1.22。

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

## Electron 桌面包

```bash
yarn build
yarn build-ele:mac   # 或 win / linux
```

## Hermes 相关代码

- `packages/tsdaodaobase/src/Messages/Hermes/` — 卡片 UI
- `packages/tsdaodaobase/src/Service/HermesPayload.ts` — 信封解包
- `packages/tsdaodaobase/src/Service/HermesActionStore.ts` — 本地已选态
- 协议文档：`../docs/hermes-approval-protocol.md`
