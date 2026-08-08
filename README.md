# 袭明音乐 v1.0 (ximing-music)

> **个人用的本地音乐播放器 + 合规在线电台 + AI 创作**
> Flutter / Android · MIT License · 9570 行代码

---

## ✨ 73 项功能完整清单

### 🎵 核心播放（8 项）

- 本地音乐扫描（基于 MediaStore）
- 后台播放（just_audio + audio_service）
- 播放控制（上一首 / 下一首 / 暂停 / 进度拖动）
- 播放模式（顺序 / 单曲循环 / 列表循环 / 随机）
- 播放速度 0.5x-2.0x（7 档）
- 音量 / 亮度手势控制（左右滑区域）
- ±10s 快进快退按钮
- 睡眠定时（15/30/45/60/90 分钟）

### 📚 曲库管理（10 项）

- 本地专辑封面自动提取
- 曲目 / 专辑 / 艺术家三种聚合视图
- 扫描排除文件夹（黑名单）
- 清理脏数据（已不存在的文件）
- 按专辑 / 艺术家批量删除
- 单首删除（带确认）
- 扫描进度提示（实时 + 取消）

### 🔍 搜索（5 项）

- 全局搜索入口
- 本地搜索（曲名 / 艺术家 / 专辑）
- Jamendo 在线搜索（欧美独立 CC）
- Audius 全文搜索
- 搜索历史 + 热门搜索（持久化）

### ❤️ 收藏与歌单（6 项）

- 收藏（❤️）
- 收藏 Tab 集中查看
- 创建 / 删除 / 重命名歌单
- 加入 / 移除歌单曲目
- 收藏 / 歌单数据持久化

### 📝 歌词（7 项）

- LRC 自动识别同名文件
- LRC 手动指定（file_picker）
- 歌词点击跳转 + 长按复制
- 双击快进 / 三击快退
- 双语翻译行（同行双时间戳合并）
- 歌词设置（字号 4 档 / 居中 / 翻译 / 滚动速度）

### 📻 在线电台（8 项）

- Jamendo / Audius 热门
- 中文网络电台直播（Radio Browser 开放 API，搜索 / 热门）
- 公版音乐库（Internet Archive 开放 API，在线搜索 / 播放 / 下载）
- 在线曲目下载到本地
- 离线播放（自动用本地缓存）
- 缓存管理（统计 + 单删 + 一键清空）
- LRU 自动清理（500MB 上限）

### 🤖 AI 能力（4 项）

- AI 智能场景分类（5 种 + 自然语言）
- AI 音乐创作（6 种风格 / 真实减法合成 / 鼓组 / 混响 / 音乐结构）
- 已生成曲目保存到本地曲库

### 📊 数据与统计（5 项）

- 播放历史（按天分组）
- 清空播放历史
- 数据统计页（曲目数 / 总时长 / AI 数 / 缓存大小）
- 歌单导入 / 导出 m3u

### 🎨 个性化（3 项）

- 主题模式（暗 / 亮 / 跟随系统）
- 主色调（紫 / 蓝 / 绿 / 粉 / 橙 5 色）
- 通知栏样式（持续显示 / 快进按钮 / 样式）

### 📱 Android 系统集成（9 项）

- 桌面 Widget 2×2
- 应用快捷方式 ×3
- Deep link 处理（ximing://）
- 触屏手势（左右滑切歌 / 上下滑调音量亮度）
- 系统音量控制（Kotlin AudioManager 桥接）
- 屏幕亮度控制（screen_brightness 包）
- 来电 / 耳机拔出自动暂停

### 🛠️ 系统与体验（10 项）

- 首次启动引导（3 页 + 权限申请）
- 空状态文案
- 错误处理（所有异步操作 try-catch）
- 应用内升级提示
- 关于页
- 持久化设置（SharedPreferences）
- 数据库迁移（v1→v2→v3）
- Riverpod 状态管理（55 个 Provider）
- go_router 路由（18 个）

---

## 🏗️ 技术架构

| 层 | 技术 |
|---|---|
| UI | Flutter 3.22+ · Material 3 · go_router · Riverpod |
| 状态管理 | flutter_riverpod 2.5 |
| 数据持久化 | Drift 2.20（SQLite） |
| 音频 | just_audio 0.9 · audio_service 0.18 · just_audio_background |
| 媒体扫描 | on_audio_query 2.9 |
| 在线资源 | http · Audius Web3 |
| 文件选择 | file_picker 8.1 |
| 音频会话 | audio_session 0.1 |
| 屏幕亮度 | screen_brightness 0.2 |
| AI 合成 | 自研（零依赖、纯客户端） |
| 原生集成 | Kotlin (MethodChannel + Activity + Widget + BroadcastReceiver) |

---

## 📦 项目规模

| 项 | 数 |
|---|---|
| 总代码 | **9570 行 Dart + 233 行 Kotlin** |
| Dart 文件 | **55 个** |
| Kotlin 文件 | 4 个 |
| Android 资源 | 18 个 |
| Provider 数 | 55 个 |
| 路由数 | 18 个 |
| 数据库表 | 5 个 |
| Flutter 依赖 | 18 个包 |

---

## 🚀 出包步骤（Release APK）

### 0. 准备

- Flutter SDK ≥ 3.22
- Android Studio Hedgehog+
- JDK 17
- Android SDK 34 + Build-Tools 34.0.0
- 真机 Android 8.0+

### 1. 生成签名

```bash
cd music_app/android
keytool -genkey -v \
  -keystore release.keystore \
  -alias ximing \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=Ximing, OU=Personal, O=Personal, L=City, S=State, C=CN"

cat > key.properties <<EOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=ximing
storeFile=release.keystore
EOF
```

⚠️ **keystore 必须永久备份！丢失 = 无法更新已上架的 App。**

### 2. 构建

```bash
cd music_app

# 装依赖
flutter pub get

# 生成 Drift 代码
dart run build_runner build --delete-conflicting-outputs

# 构建 Release APK（分架构，体积最小）
flutter build apk --release --split-per-abi

# 产物
ls build/app/outputs/flutter-apk/
# app-arm64-v8a-release.apk    ~5 MB
# app-armeabi-v7a-release.apk  ~4 MB
# app-x86_64-release.apk        ~5 MB
```

### 3. 安装到手机

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

详细步骤 + 常见错误处理：[docs/RELEASE.md](docs/RELEASE.md)

---

## ✅ 真机实测

下载 release APK 装到手机后，按 [docs/TESTING.md](docs/TESTING.md) 逐项测试（约 1-2 小时）。

13 大类 / 80+ 测试项：
- 首次启动
- 扫描本地音乐
- 播放控制（含后台 / 通知栏 / 蓝牙）
- 歌词（自动 / 手动 / 双语 / 手势）
- 收藏 / 歌单
- 搜索（含历史）
- 设置与个性化
- Android 系统集成（Widget / 快捷方式 / 手势）
- AI 创作
- 错误 / 边界场景
- 数据统计
- 性能
- 崩溃 / 异常

---

## 📁 项目结构

```
music_app/
├── README.md                       本文档
├── docs/
│   ├── RELEASE.md                  出包指南
│   └── TESTING.md                  真机实测 checklist
├── pubspec.yaml                    依赖
├── analysis_options.yaml
├── android/                        Android 工程
│   ├── app/
│   │   ├── build.gradle            构建配置（含签名 + R8）
│   │   ├── proguard-rules.pro      ProGuard 规则
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/com/ximing/music/
│   │       │   ├── MainActivity.kt          Deep link 入口
│   │       │   ├── MusicWidgetProvider.kt   桌面 Widget
│   │       │   ├── MediaControlReceiver.kt  Widget 按钮接收
│   │       │   └── VolumeChannel.kt        系统音量桥接
│   │       └── res/                图标 + 布局 + 配置
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle/wrapper/
└── lib/
    ├── main.dart                   入口
    ├── app.dart                    Router + ProviderScope
    ├── core/                        常量 / 主题 / 工具
    ├── data/                        数据库 + 模型 + 仓库
    ├── services/                    扫描 / 播放器 / 在线 / LRC / AI / 效果
    ├── providers/                   Riverpod 状态层（55 个）
    └── ui/                          13 个页面 + 9 个 widget
```

---

## 🛡️ 隐私与合规

**本 App 不内置任何版权音乐。** 所有在线内容来自：

- **Jamendo**：CC 协议开放 API
- **Audius**：Web3 开放流媒体

用户上传 / 分享的内容由用户自行承担责任。

如需上架应用市场，请准备：

- 用户协议
- 隐私政策
- 版权声明
- 内容审核机制（如适用）

---

## 📋 版本历史

| 版本 | 主要内容 |
|---|---|
| v0.1 | 基础播放 + 搜索 + LRC + AI 场景 |
| v0.2 | 首次启动引导 + 本地搜索 + LRC 同步 + 收藏 / 歌单 |
| v0.3 | 全局搜索 + LRC 手动指定 + 歌词设置 |
| v0.4 | 睡眠定时 + 均衡器 UI + Audius 搜索 + LRC 翻译 + AI 场景 |
| v0.5 | 本地专辑封面 + 播放速度 + 播放历史 |
| v0.6 | 在线缓存 + AI 创作（WAV 合成） |
| v0.7 | 桌面 Widget + 应用快捷方式 + 触屏手势 + 通知栏 + 来电暂停 |
| v0.7.1 | Bug 修复（音量 / 快捷方式）+ 6 个实用性功能 |
| v0.8 | 12 个 P0+P1 功能（主题 / 主色调 / 搜索历史 / m3u / 双击三击 / 通知栏） |
| v0.9 | AI 质量升级（减法合成 / 鼓组 / 混响 / 音乐理论 / 结构） |
| **v1.0** | **Release 出包配置 + 实测 checklist** |

---

## 🤝 致谢

- **开源包**：just_audio · audio_service · on_audio_query · drift · flutter_riverpod · go_router · file_picker · screen_brightness · audio_session
- **灵感来源**：Spotify · Apple Music · 网易云音乐 · Poweramp · Stellio
- **AI 创作思路**：基于减法合成（Subtractive Synthesis）和音乐理论常识

---

## 📄 License

MIT License（仅限代码本身）。
音乐版权归原权利人所有。