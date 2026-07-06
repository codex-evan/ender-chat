# EncChat 本地构建指南（中国镜像源）

## 一、安装 Flutter SDK

### 方法1：使用 Scoop（推荐）

```powershell
# 1. 安装 Scoop（如未安装）
irm get.scoop.sh | iex

# 2. 安装 Flutter
scoop install flutter

# 3. 验证安装
flutter doctor
```

### 方法2：手动安装

```powershell
# 1. 下载 Flutter SDK（清华/阿里镜像）
# 下载地址: https://storage.flutter-io.cn/flutter_infra_release/releases/releases.txt
# 或直接下载: https://storage.flutter-io.cn/flutter_infra_release/releases/releases/flutter_windows_3.27.4-stable.zip

# 2. 解压到 C:\flutter
# 例如: C:\flutter\bin\flutter.exe

# 3. 添加到系统 PATH
# 右键"此电脑" > 属性 > 高级系统设置 > 环境变量
# 在"系统变量"中找到 Path，添加: C:\flutter\bin

# 4. 重启终端，验证
flutter --version
```

## 二、配置中国镜像源

### Flutter 镜像（自动配置）

运行构建脚本时会自动设置：
- `PUB_HOSTED_URL=https://pub.flutter-io.cn`
- `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`

### 永久配置（可选）

在系统环境变量中添加：

```powershell
# PowerShell
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "Machine")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "Machine")

# CMD
setx PUB_HOSTED_URL "https://pub.flutter-io.cn"
setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"
```

### Android Gradle 镜像

已在 `app/android/settings.gradle` 和 `app/android/build.gradle` 中配置阿里云 Maven 镜像：
- `https://maven.aliyun.com/repository/public`
- `https://maven.aliyun.com/repository/google`
- `https://maven.aliyun.com/repository/gradle-plugin`

## 三、安装 Android 构建依赖

### 1. 安装 JDK

```powershell
# 使用 Scoop
scoop install adoptopenjdk

# 或手动下载: https://adoptium.net/
# 设置 JAVA_HOME 环境变量
```

### 2. 安装 Android Studio（可选，用于构建 APK）

```powershell
# 使用 Scoop
scoop install android-studio

# 或使用命令行工具
# 下载: https://developer.android.com/studio#command-tools
# 解压后运行: sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

### 3. 安装 Android SDK 组件

```powershell
# 运行 flutter doctor 查看缺失项
flutter doctor

# 根据提示安装 Android SDK
flutter doctor --android-licenses
# 全部输入 y 接受许可
```

## 四、安装 Windows 构建依赖

### 1. 安装 Visual Studio Build Tools

```powershell
# 方法1：使用 Scoop
scoop install visualstudio2022buildtools --add-workload component.vctools.msbuild.v17

# 方法2：手动下载安装
# 访问 https://visualstudio.microsoft.com/visual-cpp-build-tools/
# 安装时勾选 "使用C++的桌面开发"
```

### 2. 安装 Windows SDK

```powershell
# VS Installer 中确保安装了:
# - Windows 10 SDK (10.0.19041.0) 或更高版本
# - MSBuild
# - C++ ATL
# - C++ MFC
```

## 五、运行构建

### 方式1：使用构建脚本（推荐）

```powershell
cd "C:\Users\jxgm\Documents\New project\app"
.\build-local.ps1
```

脚本会：
1. 检查 Flutter 是否安装
2. 配置中国镜像源
3. 清理旧构建
4. 获取依赖
5. 让你选择构建 Android / Windows / 两者
6. 输出构建产物位置

### 方式2：手动构建

```powershell
# 1. 进入项目目录
cd "C:\Users\jxgm\Documents\New project\app"

# 2. 配置镜像
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# 3. 获取依赖
flutter pub get

# 4. 构建 Android APK
flutter build apk --release

# 5. 构建 Windows EXE
flutter build windows --release
```

## 六、构建产物位置

- **Android APK**: `app\build\app\outputs\flutter-apk\app-release.apk`
- **Windows EXE**: `app\build\windows\x64\runner\Release\`

## 七、常见问题

### Q1: pub get 速度慢

确保已配置镜像：
```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
flutter pub get
```

### Q2: Android 构建失败

```powershell
# 清理并重新获取
cd app\android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### Q3: Windows 构建失败 - MSBuild 错误

```powershell
# 确保安装了 VS Build Tools
# 运行: vswhere -latest -find "**\MSBuild\**\Bin\MSBuild.exe"
# 确认路径在 PATH 中
```

### Q4: Flutter doctor 显示红叉

```powershell
# 逐项修复
flutter doctor -v
# 根据输出安装对应依赖
```

### Q5: 网络超时

```powershell
# 检查代理设置
$env:HTTP_PROXY = ""
$env:HTTPS_PROXY = ""

# 如果使用代理，确保代理能访问国内镜像
```

## 八、关于 iOS 构建

由于你没有 Mac，iOS IPA 只能通过 GitHub Actions 构建：

1. 访问: https://github.com/codex-evan/ender-chat/actions
2. 点击 "Build iOS IPA" → "Run workflow"
3. 等待 15-30 分钟
4. 在下载区域获取 Runner.ipa
