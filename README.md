# 叙叨 (Shudo) — 私有化即时通讯平台

**叙叨** 是一个基于开源 IM 生态的私有化即时通讯平台，支持 iOS / Web / 桌面端，集成 AI 助手 Hermes。

## 📦 项目组成

```
shudo/
├── desktop/          # Web / 桌面客户端（React + Electron）
├── ios/              # iOS 客户端（Objective-C）
├── services/         # 自研后端服务
│   ├── shudo-org/    #   话题（子频道）分组管理
│   └── translate/    #   消息翻译 API
├── docker-compose.yaml  # 完整服务栈
└── docs/             # 文档
```

## 🏗️ 基于的开源项目

| 组件 | 上游项目 | 说明 |
|------|---------|------|
| **通讯层** | [WuKongIM](https://github.com/WuKongIM/WuKongIM) v2 | 悟空 IM 服务端 |
| **业务层** | [TangSengDaoDao](https://github.com/TangSengDaoDao/TangSengDaoDao) v1.5 | 唐僧叨叨服务端 |
| **Web 端** | [TangSengDaoDaoWeb](https://github.com/TangSengDaoDao/TangSengDaoDaoWeb) | 唐僧叨叨 Web 客户端 |
| **iOS 端** | WuKongBase (TangSengDaoDao iOS) | 唐僧叨叨 iOS 客户端 |

## ✨ 叙叨自研改动

### 🔧 后端服务（services/）

| 服务 | 功能 | 技术栈 |
|------|------|--------|
| **shudo-org** | 话题（子频道）创建/管理/分组 | Python FastAPI + MySQL |
| **translate** | 多引擎消息翻译（Google/DeepL/LibreTranslate） | Python FastAPI |

### 🖥️ Web / 桌面端改动

| 改动 | 说明 |
|------|------|
| **Hermes AI 集成** | 卡片消息(21000)、按钮回传(21001)、表格(21002)、音频播报(21003) |
| **输入框飞书风格重设计** | 圆角外壳 + 发送按钮 + iOS 风格工具栏图标 |
| **@mention 裁切修复** | 修复高亮层裁切导致 @人名只显示首字符的 Bug |
| **音频消息卡片** | 播放/暂停按钮 + 实时进度条 + 顶栏播放器 |
| **话题（子频道）** | 创建话题、管理话题、话题分组 |
| **品牌主题** | 石青/玄青/松烟/雾蓝 四套主题色 |
| **消息翻译** | 侧栏设置 + 长按翻译 + 气泡译文展示 |
| **斜杠指令** | `/` 触发 AI 指令面板 |
| **@bot inline** | @机器人触发内联 GIF 搜索 |
| **`/v1/shudo` 代理** | CRA setupProxy 转发至 shudo-org 服务 |

### 📱 iOS 端改动

| 改动 | 说明 |
|------|------|
| **品牌定制** | 应用名「叙叨」、Logo、启动图、主题色 |
| **Hermes 集成** | 与 Web 端对齐的卡片/表格/音频消息渲染 |
| **话题管理** | 子频道列表、创建、归档、删除 |
| **毛玻璃 Chrome** | Liquid Glass 输入框底栏效果 |
| **M80 富文本增强** | 修复 @提及解析、行高计算 |

---

## 🚀 快速启动

```bash
# 1. 启动后端服务栈
cp .env.example .env   # 编辑 EXTERNAL_IP 等配置
docker compose up -d

# 2. Web 开发
cd desktop
yarn install
yarn dev               # → http://localhost:3000

# 3. iOS 开发
open ios/TangSengDaoDaoiOS.xcworkspace
# Xcode → 选择 WuKongChatiOS scheme → Run
```

详见各子目录的 README。

## 📄 许可证

本项目基于上游开源项目修改，各组件遵循其原始许可证。自研部分（`services/`）采用 MIT License。
