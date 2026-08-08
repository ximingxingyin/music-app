import 'package:audio_session/audio_session.dart';

/// 音频会话配置（Android）。
///
/// 关键设置：
///   - setActive 标记音乐 App 持有音频焦点
///   - AndroidAudioFocusGainType.gain 永久获得焦点
///   - AndroidAudioAttributesUsage.media 用于媒体播放
///   - AndroidAudioAttributesContentType.music 标记内容类型
class AudioSessionConfig {
  AudioSessionConfig._();

  static Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
  }
}