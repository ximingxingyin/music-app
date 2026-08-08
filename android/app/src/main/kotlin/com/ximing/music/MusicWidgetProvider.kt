package com.ximing.music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.ximing.music.R

/**
 * 桌面 Widget 2x2 小组件。
 *
 * 通过 SharedPreferences（FileProvider/MediaButtonReceiver 同名 key）与 Flutter 通信：
 *   - Flutter 在 audio_service 启动时写入 "current_track" JSON
 *   - Widget 定时拉取最新状态并刷新
 *
 * 控制按钮（上一首/播放暂停/下一首）通过广播到 MediaButtonReceiver 走 audio_service 通道。
 */
class MusicWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int
    ) {
        val prefs = context.getSharedPreferences("ximing_widget", Context.MODE_PRIVATE)
        val title = prefs.getString("title", "未在播放") ?: "未在播放"
        val artist = prefs.getString("artist", "袭明音乐") ?: "袭明音乐"
        val playing = prefs.getBoolean("playing", false)

        val views = RemoteViews(context.packageName, R.layout.widget_music)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)
        views.setImageViewResource(
            R.id.widget_play_pause,
            if (playing) R.drawable.ic_pause else R.drawable.ic_play
        )

        // 点击事件：打开 App
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPending = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, openPending)

        // 上一首 / 播放暂停 / 下一首
        views.setOnClickPendingIntent(
            R.id.widget_prev,
            mediaPending(context, "ACTION_PREV")
        )
        views.setOnClickPendingIntent(
            R.id.widget_play_pause,
            mediaPending(context, if (playing) "ACTION_PAUSE" else "ACTION_PLAY")
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            mediaPending(context, "ACTION_NEXT")
        )

        manager.updateAppWidget(widgetId, views)
    }

    private fun mediaPending(context: Context, action: String): PendingIntent {
        val intent = Intent("com.ximing.music.MEDIA_CONTROL").apply {
            putExtra("action", action)
            setPackage(context.packageName)
        }
        return PendingIntent.getBroadcast(
            context, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * 收到 Flutter 主动推送的状态更新。
     * Flutter 端通过 SharedPreferences 写入，我们在这里刷新。
     */
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MusicWidgetProvider::class.java))
            mgr.notifyAppWidgetViewDataChanged(ids, android.R.id.list)
            for (id in ids) {
                updateWidget(context, mgr, id)
            }
        }
    }
}