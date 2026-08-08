import '../database/database.dart';
import '../models/track.dart';

/// 把数据库行映射成统一的 Track 模型。
Track trackFromRow(TrackRow r) {
  return Track(
    id: r.id,
    title: r.title,
    artist: r.artist,
    album: r.album,
    duration: Duration(milliseconds: r.durationMs),
    uri: r.uri,
    source: TrackSource.local,
    albumArtUrl: r.albumArtUri,
  );
}