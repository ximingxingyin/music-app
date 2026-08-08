# 出包指南：Release APK / AAB

> **状态**：v1.0
> **前提**：本工程代码已就绪，按本文档逐步操作可在本地生成 release APK。

---

## 0. 准备清单

- ✅ Flutter SDK ≥ 3.22
- ✅ Android Studio Hedgehog+
- ✅ JDK 17
- ✅ Android SDK Platform 34 / Build-Tools 34.0.0
- ✅ 真机一台（Android 8.0+ / API 26+）
- ✅ USB 数据线 + 真机已开启"开发者模式"+"USB 调试"

---

## 1. 生成签名 Keystore

签名 keystore 用于证明 APK 是你发布的，没签名 Play Store 不让上架，**调试用 APK 也不能长期用**。

### 命令

```bash
cd music_app/android
keytool -genkey -v \
  -keystore release.keystore \
  -alias ximing \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=Ximing, OU=Personal, O=Personal, L=City, S=State, C=CN"
```

### 重要

⚠️ **keystore 文件 + 密码必须永久保存**：
- 丢失 = 无法更新已上架的 App（必须重新上架）
- 泄露 = 别人可以伪造你的更新
- **建议**：备份到 1Password / Bitwarden 等密码管理器

### 创建 key.properties

```bash
cat > music_app/android/key.properties <<EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=ximing
storeFile=release.keystore
EOF
```

⚠️ **key.properties 不要提交到 Git**（已加入 `.gitignore` 模板）。

---

## 2. 修改应用 ID / 名称（可选）

如果想换个名字发布：

### 修改包名

`android/app/build.gradle`：
```gradle
defaultConfig {
    applicationId "com.yourname.music"  // 改这里
    ...
}
```

同步修改 Kotlin 包路径：
```bash
mkdir -p android/app/src/main/kotlin/com/yourname/music
mv android/app/src/main/kotlin/com/ximing/music/* \
   android/app/src/main/kotlin/com/yourname/music/
# 然后改 MainActivity.kt 第一行 package
# 改 AndroidManifest.xml 中所有 com.ximing.music 引用
```

### 修改 App 名

`android/app/src/main/AndroidManifest.xml`：
```xml
<application
    android:label="你的 App 名"
    ...
```

---

## 3. 首次构建

```bash
cd music_app

# 1. 装依赖
flutter pub get

# 2. 生成 Drift 代码
dart run build_runner build --delete-conflicting-outputs

# 3. 检查环境
flutter doctor

# 4. 构建 APK
flutter build apk --release

# 5. 产物位置
# build/app/outputs/flutter-apk/app-release.apk
```

### 构建选项

```bash
# 分架构打包（推荐，体积小 50%+）
flutter build apk --release --split-per-abi

# 产物：
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk

# 仅 arm64（覆盖 95% 设备，体积最小）
flutter build apk --release --target-platform=android-arm64
```

---

## 4. 构建 App Bundle（AAB）

AAB 是 Google Play 上架格式。

```bash
flutter build appbundle --release
# 产物：build/app/outputs/bundle/release/app-release.aab
```

---

## 5. 安装到真机

### 方式 A：ADB 安装

```bash
# USB 连接手机（开启 USB 调试）
adb devices
# 应该看到你的设备列表

# 安装
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 强制覆盖安装（已有旧版）
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 卸载
adb uninstall com.ximing.music
```

### 方式 B：直接传 APK

把 `app-release.apk` 拷到手机，用文件管理器点击安装（需开启"未知来源应用"权限）。

---

## 6. 体积优化

| 优化项 | 效果 |
|---|---|
| `--split-per-abi` | 体积减少 50%+ |
| `--target-platform=android-arm64` | 进一步减少 30% |
| 启用 R8 (`minifyEnabled true`) | 已默认 |
| 启用 `shrinkResources` | 已默认 |
| 删除未用资源 | 手动 |

**典型大小**：
- 单架构 APK：8-12 MB
- 分架构 APK（每个）：4-6 MB
- AAB：8-15 MB（按需下发）

---

## 7. 常见构建错误

### 错误 1：Gradle 版本冲突

```
Minimum supported Gradle version is X.X
```

解决：`android/gradle/wrapper/gradle-wrapper.properties` 中升级版本：
```
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-all.zip
```

### 错误 2：依赖冲突

```
Execution failed for task ':app:processDebugResources'
```

解决：
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### 错误 3：keystore 密码错误

```
Keystore was tampered with, or password was incorrect
```

解决：检查 `key.properties` 里的密码是否与生成时一致。

### 错误 4：Kotlin 编译错误

```
e: file://.../MainActivity.kt
```

解决：检查 Kotlin 版本：
```
android/settings.gradle:
id "org.jetbrains.kotlin.android" version "1.9.22" apply false
```

### 错误 5：NDK 版本不匹配

```
No version of NDK matched the requested version
```

解决：`android/app/build.gradle`：
```gradle
ndkVersion "26.1.10909125"  // 改成 Flutter doctor 推荐的版本
```

---

## 8. 发布到应用市场

### Google Play（海外）

1. 注册 Google Play Console（$25 一次性）
2. 创建应用 → 填写元数据
3. 上传 AAB 文件
4. 填写隐私政策、权限说明
5. 提交审核

### 国内应用市场

| 市场 | 资质要求 |
|---|---|
| 华为应用市场 | 公司营业执照 + 软件著作权 |
| 小米应用商店 | 公司资质 |
| OPPO / vivo | 公司资质 |
| 腾讯应用宝 | 公司资质 + 网络文化经营许可证 |

⚠️ 个人开发者**几乎无法上架**国内应用市场。

---

## 9. 升级发布

首次上架后，升级只需：

```bash
# 1. 升级 versionCode / versionName（android/app/build.gradle）
# versionCode 1 → 2
# versionName "1.0.0" → "1.0.1"

# 2. 用同一个 keystore 重新构建
flutter build appbundle --release

# 3. 上传新版本
```

⚠️ **同一个 keystore** 才能升级覆盖，丢失就只能重新上架。

---

## 10. 调试 Release 包

如果 release 包有问题但 debug 包正常：

```bash
# 安装带日志的 release 包
flutter run --release --verbose

# 或用 Android Studio Profile 模式
flutter run --profile
```

日志查看：
```bash
adb logcat | grep -i flutter
```

---

## ✅ 完成检查清单

- [ ] 签名 keystore 已生成并备份
- [ ] key.properties 已创建（不提交到 Git）
- [ ] 应用 ID / 名称已定制
- [ ] Release APK 构建成功
- [ ] 真机安装成功
- [ ] 启动正常
- [ ] 核心功能（扫描 / 播放 / 设置）正常
- [ ] 通知栏 / Widget / 快捷方式正常
- [ ] 后台播放、来电暂停正常

---

**如果一切就绪，这就是你的 v1.0 Release。** 🎉