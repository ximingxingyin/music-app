import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database.dart';
import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';
import '../services/music_scanner_service.dart';

/// 全局数据库 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// 扫描服务 Provider
final scannerProvider = Provider<MusicScannerService>((ref) {
  final db = ref.watch(databaseProvider);
  return MusicScannerService(db);
});

/// 全量曲目（异步加载）。
final tracksProvider = FutureProvider<List<Track>>((ref) async {
  final scanner = ref.watch(scannerProvider);
  return scanner.loadAll();
});

/// 专辑列表（聚合自曲目，含封面）。
final albumsProvider = FutureProvider<
    List<({String album, String artist, String? coverPath, int count})>>(
        (ref) async {
  final scanner = ref.watch(scannerProvider);
  return scanner.loadAlbums();
});

/// 艺术家列表（含封面）。
final artistsProvider =
    FutureProvider<List<({String artist, String? coverPath, int count})>>(
        (ref) async {
  final scanner = ref.watch(scannerProvider);
  return scanner.loadArtists();
});

/// 当前选中的专辑名（用于专辑详情页）。
final selectedAlbumProvider = StateProvider<({String album, String artist})?>((ref) => null);

/// 当前选中的艺术家。
final selectedArtistProvider = StateProvider<String?>((ref) => null);

/// 收藏曲目。
final favoritesProvider = FutureProvider<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getFavorites();
  return rows.map(trackFromRow).toList();
});

/// 扫描进度（由扫描动作更新）
final scanProgressProvider = StateProvider<ScanProgress>((ref) {
  return const ScanProgress(total: 0, processed: 0, currentStep: '');
});

/// 播放历史（带曲目信息，按时间倒序）。
class HistoryItem {
  final Track track;
  final DateTime playedAt;
  const HistoryItem({required this.track, required this.playedAt});
}

final historyProvider = FutureProvider<List<HistoryItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.recentHistory(limit: 200);
  if (rows.isEmpty) return const [];
  // join tracks
  final ids = rows.map((r) => r.trackId).toSet().toList();
  final placeholders = List.filled(ids.length, '?').join(',');
  final trackRows = await db.customSelect(
    "SELECT * FROM tracks WHERE id IN ($placeholders)",
    variables: ids.map(Variable.withString).toList(),
    readsFrom: {db.tracks},
  ).get();
  final trackMap = {for (final r in trackRows) r.read<String>('id'): r};
  final result = <HistoryItem>[];
  for (final h in rows) {
    final t = trackMap[h.trackId];
    if (t == null) continue;
    result.add(HistoryItem(
      track: Track(
        id: t.read<String>('id'),
        title: t.read<String>('title'),
        artist: t.read<String>('artist'),
        album: t.read<String>('album'),
        duration: Duration(milliseconds: t.read<int>('duration_ms')),
        uri: t.read<String>('uri'),
        source: TrackSource.local,
        albumArtUrl: t.readNullable<String>('album_art_uri'),
      ),
      playedAt: h.playedAt,
    ));
  }
  return result;
});

/// 搜索关键字。
final searchQueryProvider = StateProvider<String>((_) => '');

/// 搜索结果（按曲名 / 艺术家 / 专辑 任一命中）。
final searchResultsProvider = FutureProvider<List<Track>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final all = await ref.watch(tracksProvider.future);
  if (query.isEmpty) return all;
  return all.where((t) {
    final hay = '${t.title} ${t.artist} ${t.album}'.toLowerCase();
    return hay.contains(query);
  }).toList();
});