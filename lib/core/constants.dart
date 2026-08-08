/// 全局常量
class AppConstants {
  AppConstants._();

  /// App 名
  static const String appName = '袭明音乐';

  /// 数据库名
  static const String dbName = 'music_app.db';

  /// SharedPreferences key
  static const String prefFirstLaunch = 'first_launch';

  /// Jamendo 在线电台 client_id（演示用，需在 https://developer.jamendo.com/ 申请替换）
  static const String jamendoClientId = 'YOUR_JAMENDO_CLIENT_ID';

  /// Audius 公共节点（无需 key）
  static const List<String> audiusHosts = [
    'https://audius.co',
    'https://audius.host',
  ];

  /// 默认专辑占位图
  static const String placeholderAlbum =
      'https://via.placeholder.com/300x300/1a1a2e/eeeeee?text=Music';
}

/// 播放循环模式
enum RepeatMode { off, all, one }

/// 资源来源
enum TrackSource { local, jamendo, audius, ai, radio, archive }

/// AI 生成音乐的风格
enum AiGenre {
  ambient('环境氛围', '柔和长音、空灵氛围'),
  electronic('电子', '合成器、节奏循环'),
  classical('古典', '钢琴和弦序列'),
  lofi('Lo-Fi', '温暖的怀旧感'),
  percussion('打击', '节拍+旋律'),
  drone('持续音', '缓慢变化的音墙');

  final String label;
  final String desc;
  const AiGenre(this.label, this.desc);
}