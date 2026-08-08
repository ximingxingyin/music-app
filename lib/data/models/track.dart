import '../../core/constants.dart';

/// 统一的"歌曲"抽象。
/// 本地与在线电台共用同一结构，差异在 [source] 与 [uri]。
class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? albumArtUrl;
  final String uri; // 本地为 file:// 路径，在线为 https URL
  final TrackSource source;
  final int? year;
  final String? genre;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.uri,
    required this.source,
    this.albumArtUrl,
    this.year,
    this.genre,
  });

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? albumArtUrl,
    String? uri,
    TrackSource? source,
    int? year,
    String? genre,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      source: source ?? this.source,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      year: year ?? this.year,
      genre: genre ?? this.genre,
    );
  }

  /// 播放器需要的源（本地用 content://，在线用 https://）
  String get playableUri => source == TrackSource.local
      ? uri
      : uri;

  bool get isLocal => source == TrackSource.local;
  bool get isOnline => !isLocal;

  /// 是否可缓存到本地。
  /// 直播流（radio）不可缓存；其余在线源可缓存。
  bool get cacheable => source != TrackSource.radio;
}