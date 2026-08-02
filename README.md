# 叙叨 + 悟空 IM（本地部署）

官方 Compose 栈：WuKongIM（通讯）+ TangSengDaoDao（业务/Web/管理端）+ MySQL/Redis/MinIO。

> Apple Silicon：镜像为 `linux/amd64`，Docker Desktop 会模拟运行。

## 启动

```bash
cd ~/Projects/tsdd
docker compose up -d
docker compose ps
```

| 服务 | 地址 |
|------|------|
| Web 客户端 | http://192.168.5.249:82 或 http://127.0.0.1:82 |
| 管理后台 | http://127.0.0.1:83 （`superAdmin` / `.env` 的 `TS_ADMINPWD`） |
| API | http://127.0.0.1:8090/v1/ping |
| 悟空监控 | http://127.0.0.1:5300 |

## 账号怎么来（重要）

当前 Web 客户端 **没有注册入口**（官方「长按标题注册」只在手机 App）。本机配置正常，可用下面方式建号：

### A. 管理后台加用户（推荐）
1. 打开 http://127.0.0.1:83 （不是 82）
2. 账号 `superAdmin`，密码见 `.env` 的 `TS_ADMINPWD`
3. 用户管理 → 添加用户（手机号 + 密码）
4. 回到 http://127.0.0.1:82 ，用该手机号登录

### B. API 注册（开发用）
```bash
curl -X POST http://127.0.0.1:8090/v1/user/register \
  -H 'Content-Type: application/json' \
  -d '{"zone":"0086","phone":"13800138001","code":"123456","password":"a1234567"}'
```
验证码固定为 `.env` 的 `TS_SMSCODE`（默认 `123456`）。

### C. 私有化桌面 / Web（本仓库 `desktop/`）

官方 Web/PC 源码已放入 `desktop/`，并接入与 iOS 相同的 Hermes `21000/21001` 协议。见 `desktop/README.md`。

```bash
export PATH="$HOME/.hermes/node/bin:$PATH"   # 若本机 yarn 在此
cd ~/Projects/tsdd/desktop
yarn install --ignore-optional
yarn dev
```

默认 API：`http://127.0.0.1:8090/v1/`（可用 `REACT_APP_API_URL` 覆盖）。

### D. 私有化 iOS（本仓库 `ios/`）

官方 App Store 包**没有**改服务器入口，请用本仓库自编译客户端：

1. 安装完整 **Xcode**（见 `ios/README.md`）
2. 打开 `ios/TangSengDaoDaoiOS.xcworkspace`，Team 选你的开发者账号，真机运行
3. 登录页右上角齿轮 → 服务器 `192.168.5.249` / 端口 `8090` / `http`
4. APNs 离线推送：证书放到 `tsdd/configs/push/`，配置见该目录 README

默认 Bundle ID：`com.platoren.tsdd`。

## 配置

必改：`.env` 的 `EXTERNAL_IP`（局域网访问用；当前 `192.168.5.249`）。

## Hermes 机器人（已接通）

- 机器人用户：手机号 `13800000001`，显示名 Hermes  
- 凭证：`hermes-robot.env`（勿提交）  
- Hermes 插件：`~/.hermes/hermes-agent/plugins/platforms/tsdd/`  
- 在 Web 里打开与 **Hermes** 的私聊发消息即可（已与你的账号互加好友）

若收不到：确认 Docker 栈在跑，并检查 Hermes 日志里是否有 `✓ tsdd connected`。

注意：不要用 `launchctl submit -l com.hermes.gwrestart ... KeepAlive` 之类的方式循环重启 Gateway（之前有过这种残留任务会把服务打崩）。正常重启用外部终端执行一次 `hermes gateway restart` 即可。

## 停止

```bash
docker compose down
```

数据目录：`mysqldata/`、`miniodata/`、`wukongim/`、`tsdd/`。

> 🤖 **AI 辅助开发**：本项目代码编写、调试、UI 设计大量借助 AI 编程助手 [Hermes Agent](https://nousresearch.com) 完成。
