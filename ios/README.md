# 叙叨 iOS（私有化）

基于官方 [TangSengDaoDaoiOS](https://gitee.com/TangSengDaoDao/TangSengDaoDaoiOS) 的私有化改动。

## 已改内容

- 登录页右上角恢复「服务器配置」入口（协议 / 地址 / 端口）
- 默认 API：`http://192.168.5.249:8090`（与仓库 `.env` 的 `EXTERNAL_IP` 一致）
- Bundle ID：`com.platoren.tsdd`（含通知扩展）
- 新消息通知相关开关：服务端未下发时默认开启

## 编译前必须

1. **安装完整 Xcode**（本机目前只有 Command Line Tools，无法签名/真机调试）  
   App Store 搜索 Xcode，装完后执行：

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   xcodebuild -version
   ```

2. 安装 CocoaPods（如需重装依赖）：

   ```bash
   brew install cocoapods
   cd ~/Projects/tsdd/ios && pod install
   ```

3. 用 Xcode 打开 **`TangSengDaoDaoiOS.xcworkspace`**（不要开 `.xcodeproj`）

4. Signing & Capabilities  
   - Team：选你的 Apple Developer 团队  
   - Bundle ID：`com.platoren.tsdd`（若被占用可改成自己的，三个 Target 一起改）  
   - 勾选 **Push Notifications**、Background Modes → Remote notifications

5. 真机运行（模拟器拿不到 APNs device token）

## 登录与改服务器

1. 启动本机 Docker 栈（`docker compose up -d`）
2. App 登录页右上角齿轮 → 服务器地址填局域网 IP，端口 `8090`，协议 `http` → 提交
3. 用已有账号登录；或长按欢迎标题进入注册（验证码见 `.env` 的 `TS_SMSCODE`）

## APNs 离线推送（下一步）

证书配好后放到 `../tsdd/configs/push/`，并在 `../tsdd/configs/tsdd.yaml` 填写 `push.apns`（见该目录说明）。未配置时：App 在线/刚进后台仍可本地提醒，**杀进程后不会有远程推送**。
