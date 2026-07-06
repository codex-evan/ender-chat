# ============================================
# EncChat 本地构建脚本 (中国镜像源)
# ============================================
# 使用前请先安装 Flutter SDK (见下方安装说明)
# ============================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  EncChat 本地构建工具" -ForegroundColor Cyan
Write-Host "  使用中国镜像源" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 检查 Flutter ----------
Write-Host "[1/6] 检查 Flutter SDK..." -ForegroundColor Yellow
try {
    $flutterVer = flutter --version 2>&1 | Select-String "Flutter"
    Write-Host "  Flutter 已安装: $flutterVer" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  [错误] Flutter 未安装或未加入 PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "  请安装 Flutter SDK:" -ForegroundColor Yellow
    Write-Host "  方法1 (推荐): scoop install flutter" -ForegroundColor White
    Write-Host "  方法2: 手动下载 https://storage.flutter-io.cn" -ForegroundColor White
    Write-Host "  方法3: 解压后将 flutter\bin 加入系统 PATH" -ForegroundColor White
    Write-Host ""
    Read-Host "按回车键退出"
    exit 1
}

# ---------- 配置镜像 ----------
Write-Host "[2/6] 配置中国镜像源..." -ForegroundColor Yellow

$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# 创建 .npmrc 用于 Flutter 内部 npm 包
$npmrcPath = Join-Path $env:USERPROFILE ".npmrc"
@"
registry=https://registry.npmmirror.com
flutter_mirror=https://storage.flutter-io.cn
pub_mirror=https://pub.flutter-io.cn
"@ | Set-Content $npmrcPath -Encoding UTF8

Write-Host "  PUB_HOSTED_URL = $env:PUB_HOSTED_URL" -ForegroundColor Green
Write-Host "  FLUTTER_STORAGE_BASE_URL = $env:FLUTTER_STORAGE_BASE_URL" -ForegroundColor Green

# ---------- 清理旧构建 ----------
Write-Host "[3/6] 清理旧构建文件..." -ForegroundColor Yellow
Set-Location (Join-Path $scriptDir "app")
flutter clean 2>$null

# ---------- 获取依赖 ----------
Write-Host "[4/6] 获取 Flutter 依赖..." -ForegroundColor Yellow
flutter pub get
flutter pub upgrade

# ---------- 配置 Android ----------
Write-Host "[5/6] 配置 Android 构建..." -ForegroundColor Yellow

# 创建 local.properties
@"
flutter.sdk=C:\flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
"@ | Set-Content (Join-Path $scriptDir "app\local.properties") -Encoding UTF8

# 创建/更新 gradle.properties
@"
org.gradle.jvmargs=-Xmx4608m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
"@ | Set-Content (Join-Path $scriptDir "app\android\gradle.properties") -Encoding UTF8

# ---------- 选择构建目标 ----------
Write-Host ""
Write-Host "请选择要构建的目标平台:" -ForegroundColor Cyan
Write-Host "  1. Android APK" -ForegroundColor White
Write-Host "  2. Windows EXE" -ForegroundColor White
Write-Host "  3. 两者都构建" -ForegroundColor White
Write-Host ""
$choice = Read-Host "请输入选项 (1/2/3)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "[6/6] 构建 Android APK..." -ForegroundColor Yellow
        flutter build apk --release
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Android APK 构建完成!" -ForegroundColor Green
        Write-Host "  位置: app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Green
    }
    "2" {
        Write-Host ""
        Write-Host "[6/6] 构建 Windows EXE..." -ForegroundColor Yellow
        flutter build windows --release
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Windows EXE 构建完成!" -ForegroundColor Green
        Write-Host "  位置: app\build\windows\x64\runner\Release\" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Green
    }
    "3" {
        Write-Host ""
        Write-Host "[6/6] 构建 Android APK..." -ForegroundColor Yellow
        flutter build apk --release
        Write-Host ""
        Write-Host "[6/6] 构建 Windows EXE..." -ForegroundColor Yellow
        flutter build windows --release
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  全部构建完成!" -ForegroundColor Green
        Write-Host "  Android: app\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
        Write-Host "  Windows: app\build\windows\x64\runner\Release\" -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Green
    }
    default {
        Write-Host "无效选项，退出。" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Read-Host "按回车键退出"
