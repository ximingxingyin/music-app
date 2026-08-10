import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database/database.dart';
import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';
import 'library_provider.dart';

/// 写操作集合 —— 收藏 / 歌单增删 / 历史。
class LibraryActions {
  LibraryActions(this.ref);
  final Ref ref;

  AppDatabase get _db => ref.read(databaseProvider);
  final _uuid = const Uuid();

  Future<void> toggleFavorite(Track t) async {
    final current = await _db.getFavorites();
    final isFav = current.any((row) => row.id == t.id);
    await _db.toggleFavorite(t.id, !isFav);
    ref.invalidate(favoritesProvider);
  }

  Future<bool> isFavorite(String trackId) async {
    final favs = await _db.getFavorites();
    return favs.any((r) => r.id == trackId);
  }

  Future<String> createPlaylist(String name) async {
    final id = _uuid.v4();
    await _db.upsertPlaylist(
      PlaylistsCompanion(id: Value(id), name: Value(name)),
    );
    ref.invalidate(playlistsProvider);
    return id;
  }

  Future<void> deletePlaylist(String id) async {
    await _db.customStatement(
      'DELETE FROM playlist_tracks WHERE playlist_id = ?',
      variables: [Variable.withString(id)],
    );
    await _db.customStatement(
      'DELETE FROM playlists WHERE id = ?',
      variables: [Variable.withString(id)],
    );
    ref.invalidate(playlistsProvider);
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    final existing = await _db.customSelect(
      "SELECT COUNT(*) AS cnt FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
      variables: [
        Variable.withString(playlistId),
        Variable.withString(track.id),
      ],
      readsFrom: {_db.playlistTracks},
    ).getSingle();
    final count = existing.read<int>('cnt');
    await _db.addTrackToPlaylist(
      playlistId,
      track.id,
      position: count,
    );
    ref.invalidate(playlistsProvider);
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _db.customStatement(
      'DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?',
      variables: [Variable.withString(playlistId), Variable.withString(trackId)],
    );
    ref.invalidate(playlistsProvider);
    ref.invalidate(playlistTracksProvider(playlistId));
  }

  Future<void> recordPlay(String trackId) async {
    await _db.addHistory(trackId);
    await _db.incrementPlayCount(trackId);
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await _db.renamePlaylist(id, newName);
    ref.invalidate(playlistsProvider);
  }

  /// 删除曲目（本地 + AI 都可用）
  Future<void> deleteTrack(Track t) async {
    await _db.deleteTrack(t.id);
    // 失效所有依赖 tracks 的 Provider
    ref.invalidate(tracksProvider);
    ref.invalidate(albumsProvider);
    ref.invalidate(artistsProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(aiGeneratedTracksProvider);
    ref.invalidate(historyProvider);
  }

  Future<void> clearHistory() async {
    await _db.clearHistory();
    ref.invalidate(historyProvider);
  }
}

/// Library actions Provider
final libraryActionsProvider = Provider<LibraryActions>((ref) {
  return LibraryActions(ref);
});

/// 歌单列表（带曲目计数）。
class PlaylistSummary {
  final String id;
  final String name;
  final int trackCount;
  const PlaylistSummary({
    required this.id,
    required this.name,
    required this.trackCount,
  });
}

/// 歌单列表（实时观察）。
final playlistsProvider = FutureProvider<List<PlaylistSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final list = await db.getPlaylists();
  final summaries = <PlaylistSummary>[];
  for (final p in list) {
    final row = await db.customSelect(
      "SELECT COUNT(*) AS cnt FROM playlist_tracks WHERE playlist_id = ?",
      variables: [Variable.withString(p.id)],
      readsFrom: {db.playlistTracks},
    ).getSingle();
    summaries.add(PlaylistSummary(
      id: p.id,
      name: p.name,
      trackCount: row.read<int>('cnt'),
    ));
  }
  return summaries;
});

/// 单个歌单的曲目。
final playlistTracksProvider =
    FutureProvider.family<List<Track>, String>((ref, playlistId) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.customSelect(
    "SELECT t.* FROM tracks t "
    "INNER JOIN playlist_tracks pt ON pt.track_id = t.id "
    "WHERE pt.playlist_id = ? "
    "ORDER BY pt.position ASC",
    variables: [Variable.withString(playlistId)],
    readsFrom: {db.tracks, db.playlistTracks},
  ).get();
  return rows.map((r) {
    return Track(
      id: r.read<String>('id'),
      title: r.read<String>('title'),
      artist: r.read<String>('artist'),
      album: r.read<String>('album'),
      duration: Duration(milliseconds: r.read<int>('duration_ms')),
      uri: r.read<String>('uri'),
      source: TrackSource.local,
      albumArtUrl: r.readNullableString('album_art_uri'),
    );
  }).toList();
});