package com.ximing.music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper

/**
 * 接收 Widget / 通知栏按钮的广播，写入 SharedPreferences，
 * Flutter 端定期检查并执行对应动作。
 *
 * 通过 SharedPreferences 通信而不是 MethodChannel，因为：
 *   - 启动速度更快（不用初始化 Flutter Engine）
 *   - 即使 App 未启动也能接收（Widget 点击 / 通知按钮）
 *   - Flutter 端只需 1 秒一次的轻量轮询
 */
class MediaControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("action") ?: return
        val prefs: SharedPreferences = context.getSharedPreferences(
            "ximing_media_control",
            Context.MODE_PRIVATE
        )
        prefs.edit().putString("pending_action", action).apply()

        // 通知 Flutter 立即检查（可选，避免 1 秒延迟）
        // 这里我们让 Flutter 端轮询即可
        Handler(Looper.getMainLooper()).post {
            // 可选：通过 MethodChannel 推送（未实现，因为接收时可能 Dart 未运行）
        }
    }
}