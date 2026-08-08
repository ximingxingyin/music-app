package com.ximing.music

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 系统音量控制 MethodChannel 处理器。
 *
 * Flutter 端通过 com.ximing.music/volume 调用：
 *   - setVolume(v: 0.0~1.0)
 *   - getVolume() → double
 *
 * 实现：AudioManager.adjustStreamVolume + getStreamVolume
 */
class VolumeChannel(private val context: Context) {
    private val audioManager: AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolume" -> {
                        val v = (call.arguments as? Double)?.toFloat() ?: 0.5f
                        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val target = (v.coerceIn(0.0, 1.0) * max).toInt()
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                        result.success(null)
                    }
                    "getVolume" -> {
                        val cur = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val ratio = if (max == 0) 0.0 else cur.toDouble() / max
                        result.success(ratio)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val CHANNEL = "com.ximing.music/volume"
    }
}