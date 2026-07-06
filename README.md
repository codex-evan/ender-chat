# EncChat - Anonymous End-to-End Encrypted Chat

跨平台匿名端到端加密聊天应用。无账号、无登录、无手机号、无邮箱。

## 功能特性

- **完全匿名**: 无需注册，不收集任何个人信息
- **端到端加密**: X25519 密钥交换 + AES-256-GCM 消息加密
- **跨平台**: iOS / Android / Windows 桌面
- **多媒体支持**: 文本、图片、视频、文档、文件传输
- **防截屏录屏**: Android FLAG_SECURE, iOS 检测+模糊, Windows 窗口保护
- **本地加密存储**: 密保词派生密钥，遗忘不可恢复
- **自动销毁**: 消息最多保存7天，双方退出即删除
- **中英双语**: 代码结构支持后续国际化

## 快速开始

### 服务器端部署

`ash
# SSH 到服务器
ssh root@162.211.181.145

# 在服务器上部署
cd /opt/enc-chat
# 或直接克隆本项目到服务器

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 设置服务器地址

# 启动服务
npm start

# 或使用 Docker
docker-compose up -d
`

### Flutter 客户端

`ash
cd app
flutter pub get

# 运行
flutter run

# 构建
flutter build apk --release          # Android
flutter build ios --release          # iOS
flutter build windows --release      # Windows
`

## 项目结构

`
├── server/              # Node.js WebSocket 服务器
│   ├── src/
│   │   └── server.js    # 主服务（仅处理密文）
│   ├── .env.example
│   ├── Dockerfile
│   └── docker-compose.yml
├── shared/
│   └── crypto/          # 共享加密库 (TypeScript)
├── app/                 # Flutter 跨平台应用
│   ├── lib/
│   │   ├── main.dart    # 入口
│   │   ├── screens/     # UI 页面
│   │   ├── widgets/     # 组件
│   │   ├── models/      # 数据模型
│   │   ├── services/    # 业务逻辑
│   │   ├── i18n/        # 国际化
│   │   └── crypto/      # 客户端加密
│   ├── android/
│   ├── ios/
│   └── windows/
└── docs/
    ├── PRD.md
    ├── SECURITY_ARCHITECTURE.md
    └── DEPLOYMENT.md
`

## 服务器配置

- **地址**: 162.211.181.145
- **端口**: 3000
- **WebSocket**: ws://162.211.181.145:3000/ws
- **健康检查**: http://162.211.181.145:3000/health

## 加密方案

| 组件 | 算法 | 说明 |
|------|------|------|
| 密钥交换 | X25519 | 现代 ECDH |
| 消息加密 | AES-256-GCM | 认证加密 |
| 密钥派生 | HKDF-SHA256 | RFC 5869 |
| 密保词 | PBKDF2-SHA256 | 10万次迭代 |
| 文件加密 | 分块 AES-256-GCM | 1MB 分块 |

## 安全架构

详见 [docs/SECURITY_ARCHITECTURE.md](docs/SECURITY_ARCHITECTURE.md)

### 防截屏/录屏

| 平台 | 阻止截屏 | 阻止录屏 | 检测截屏 | 模糊界面 |
|------|---------|---------|---------|---------|
| Android | ✅ 完全 | ✅ 完全 | 部分 | ✅ |
| iOS | ❌ 系统限制 | ❌ 系统限制 | ✅ 可检测 | ✅ |
| Windows | ❌ 系统限制 | ❌ 系统限制 | 有限 | ✅ |

## 隐私声明

- 本应用不需要注册
- 不收集手机号、邮箱、真实姓名
- 服务器无法看到聊天内容
- 消息和文件在发送前已加密
- 服务器只保存密文，最多7天
- 如果双方退出且未保存，消息将删除
- 如果选择本地保存，数据只保存在本机
- 密保词忘记后无法恢复

## 许可证

私有 / 专有
