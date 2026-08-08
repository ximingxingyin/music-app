import 'package:drift/drift.dart';

/// 本地音乐元数据表（用于收藏 / 播放计数 / 用户编辑）
@DataClassName('TrackRow')
class Tracks extends Table {
  TextColumn get id => text()(); // 与 on_audio_query 的 id 一致
  TextColumn get title => text()();
  TextColumn get artist => text().withDefault(const Constant(''))();
  TextColumn get album => text().withDefault(const Constant(''))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get uri => text()();
  TextColumn get albumArtUri => text().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// 用户手动指定的 LRC 文件路径（v0.3 新增）
  TextColumn get lrcPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 播放历史
@DataClassName('HistoryRow')
class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 用户自定义歌单
@DataClassName('PlaylistRow')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 歌单曲目关联
@DataClassName('PlaylistTrackRow')
class PlaylistTracks extends Table {
  TextColumn get playlistId => text()();
  TextColumn get trackId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

/// 在线曲目缓存记录（v0.6）
@DataClassName('CachedTrackRow')
class CachedTracks extends Table {
  TextColumn get id => text()(); // 与 Track.id 一致
  TextColumn get source => text()(); // jamendo / audius
  TextColumn get localPath => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}