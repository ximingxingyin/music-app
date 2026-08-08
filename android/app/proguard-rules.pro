# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Drift
-keep class com.ximing.music.data.database.** { *; }
-keep class **$Drift* { *; }

# just_audio / audio_service
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }

# Kotlin
-keepclassmembers class **$WhenMappings { <fields>; }
-keepclassmembers class kotlin.Metadata { *; }

# AndroidX
-keep class androidx.core.app.NotificationCompat { *; }

# 我们的原生代码
-keep class com.ximing.music.MainActivity { *; }
-keep class com.ximing.music.MusicWidgetProvider { *; }
-keep class com.ximing.music.MediaControlReceiver { *; }
-keep class com.ximing.music.VolumeChannel { *; }

# 去除日志（release）
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Flutter embedding
-keep class io.flutter.embedding.** { *; }