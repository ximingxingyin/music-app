import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
    tables: [Tracks, PlayHistory, Playlists, PlaylistTracks, CachedTracks],
  )
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tracks, tracks.lrcPath);
          }
          if (from < 3) {
            await m.createTable(cachedTracks);
          }
        },
      );

  // ───────── Tracks ─────────

  Stream<List<TrackRow>> watchAllTracks() =>
      (select(tracks)..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();

  Future<List<TrackRow>> getAllTracks() =>
      (select(tracks)..orderBy([(t) => OrderingTerm.asc(t.title)])).get();

  Future<List<TrackRow>> getFavorites() =>
      (select(tracks)..where((t) => t.isFavorite.equals(true))).get();

  Future<void> upsertTrack(TracksCompanion row) =>
      into(tracks).insertOnConflictUpdate(row);

  Future<void> incrementPlayCount(String id) async {
    await customStatement(
      'UPDATE tracks SET play_count = play_count + 1 WHERE id = ?',
      [Variable.withString(id)],
    );
  }

  Future<void> toggleFavorite(String id, bool value) async {
    await (update(tracks)..where((t) => t.id.equals(id)))
        .write(TracksCompanion(isFavorite: Value(value)));
  }

  Future<void> setLrcPath(String id, String? path) async {
    await (update(tracks)..where((t) => t.id.equals(id)))
        .write(TracksCompanion(lrcPath: Value(path)));
  }

  Future<String?> getLrcPath(String id) async {
    final row = await (select(tracks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.lrcPath;
  }

  // ───────── CachedTracks（在线曲目本地缓存） ─────────

  Future<void> upsertCache(CachedTracksCompanion row) =>
      into(cachedTracks).insertOnConflictUpdate(row);

  Future<void> deleteCache(String id) =>
      (delete(cachedTracks)..where((c) => c.id.equals(id))).go();

  Future<List<CachedTrackRow>> getAllCaches() =>
      (select(cachedTracks)
            ..orderBy([
              (c) => OrderingTerm.desc(c.lastPlayedAt),
              (c) => OrderingTerm.desc(c.cachedAt),
            ]))
          .get();

  Future<int> totalCacheSize() async {
    final rows = await getAllCaches();
    return rows.fold<int>(0, (sum, r) => sum + r.sizeBytes);
  }

  // ───────── 写操作（数据管理） ─────────

  Future<void> deleteTrack(String id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  Future<void> clearHistory() =>
      delete(playHistory).go();

  Future<void> deletePlaylist(String id) async {
    await customStatement(
      'DELETE FROM playlist_tracks WHERE playlist_id = ?',
      [Variable.withString(id)],
    );
    await (delete(playlists)..where((p) => p.id.equals(id))).go();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await (update(playlists)..where((p) => p.id.equals(id)))
        .write(PlaylistsCompanion(name: Value(newName)));
  }

  Future<int> totalTrackCount() async {
    final row = await customSelect(
      "SELECT COUNT(*) AS cnt FROM tracks",
      readsFrom: {tracks},
    ).getSingle();
    return row.read<int>('cnt');
  }

  Future<int> totalDurationMs() async {
    final row = await customSelect(
      "SELECT COALESCE(SUM(duration_ms), 0) AS sum FROM tracks",
      readsFrom: {tracks},
    ).getSingle();
    return row.read<int>('sum');
  }

  Future<int> aiTrackCount() async {
    final row = await customSelect(
      "SELECT COUNT(*) AS cnt FROM tracks WHERE id LIKE 'ai:%'",
      readsFrom: {tracks},
    ).getSingle();
    return row.read<int>('cnt');
  }

  // ───────── History ─────────

  Future<void> addHistory(String trackId) =>
      into(playHistory).insert(PlayHistoryCompanion(trackId: Value(trackId)));

  Future<List<HistoryRow>> recentHistory({int limit = 50}) =>
      (select(playHistory)
            ..orderBy([(h) => OrderingTerm.desc(h.playedAt)])
            ..limit(limit))
          .get();

  // ───────── Playlists ─────────

  Future<void> upsertPlaylist(PlaylistsCompanion p) =>
      into(playlists).insertOnConflictUpdate(p);

  Future<List<PlaylistRow>> getPlaylists() =>
      (select(playlists)..orderBy([(p) => OrderingTerm.asc(p.createdAt)])).get();

  Future<void> addTrackToPlaylist(String playlistId, String trackId,
          {required int position}) =>
      into(playlistTracks).insertOnConflictUpdate(
        PlaylistTracksCompanion(
          playlistId: Value(playlistId),
          trackId: Value(trackId),
          position: Value(position),
        ),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'music_app.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}