package com.ximing.music

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main Activity。
 *
 * 职责：
 *   1. 注册系统音量控制 MethodChannel
 *   2. 接收 deep link (ximing://...) 并通过 MethodChannel 转发给 Flutter
 *   3. 应用快捷方式 → 通过 onShortcut 通知 Flutter 跳转
 */
class MainActivity : FlutterActivity() {

    private var deepLinkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 注册系统音量控制
        VolumeChannel(applicationContext).register(flutterEngine)

        // Deep link channel
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ximing.music/deeplink"
        )

        // 处理启动 intent（从应用快捷方式 / 图标进入）
        intent?.let { handleIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val data = intent.data
        if (data != null && data.scheme == "ximing") {
            // ximing://now-playing
            // ximing://ai-scene
            // ximing://history
            val target = data.host ?: return
            deepLinkChannel?.invokeMethod("onShortcut", target)
        }
    }
}