import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/track.dart';
import '../services/archive_service.dart';
import '../services/jamendo_service.dart';
import '../services/radio_browser_service.dart';

/// 在线服务 Provider
final jamendoServiceProvider = Provider<JamendoService>((_) => JamendoService());
final audiusServiceProvider = Provider<AudiusService>((_) => AudiusService());
final radioBrowserServiceProvider =
    Provider<RadioBrowserService>((_) => RadioBrowserService());
final archiveServiceProvider = Provider<ArchiveService>((_) => ArchiveService());

/// Jamendo 热门曲目。
final jamendoTrendingProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final svc = ref.watch(jamendoServiceProvider);
  return svc.tracks();
});

/// Jamendo 搜索结果（关键词）。
final jamendoSearchQueryProvider = StateProvider<String>((_) => '');

final jamendoSearchResultsProvider =
    FutureProvider.autoDispose<List<Track>>((ref) async {
  final q = ref.watch(jamendoSearchQueryProvider).trim();
  if (q.isEmpty) return const [];
  final svc = ref.watch(jamendoServiceProvider);
  return svc.tracks(search: q);
});

/// Audius 热门。
final audiusTrendingProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final svc = ref.watch(audiusServiceProvider);
  return svc.trending();
});

/// Audius 搜索关键字。
final audiusSearchQueryProvider = StateProvider<String>((_) => '');

/// Audius 搜索结果。
final audiusSearchResultsProvider =
    FutureProvider.autoDispose<List<Track>>((ref) async {
  final q = ref.watch(audiusSearchQueryProvider).trim();
  if (q.isEmpty) return const [];
  final svc = ref.watch(audiusServiceProvider);
  return svc.search(query: q);
});

/// Radio Browser：中文电台列表。
final radioStationsProvider =
    FutureProvider.autoDispose<List<RadioStation>>((ref) async {
  final svc = ref.watch(radioBrowserServiceProvider);
  return svc.chineseStations();
});

/// Radio Browser：搜索关键字。
final radioSearchQueryProvider = StateProvider<String>((_) => '');

/// Radio Browser：搜索结果。
final radioSearchResultsProvider =
    FutureProvider.autoDispose<List<RadioStation>>((ref) async {
  final q = ref.watch(radioSearchQueryProvider).trim();
  if (q.isEmpty) return const [];
  final svc = ref.watch(radioBrowserServiceProvider);
  return svc.search(q);
});

/// Internet Archive：搜索关键字。
final archiveSearchQueryProvider = StateProvider<String>((_) => '');

/// Internet Archive：馆藏条目搜索结果。
final archiveSearchResultsProvider =
    FutureProvider.autoDispose<List<ArchiveItem>>((ref) async {
  final q = ref.watch(archiveSearchQueryProvider).trim();
  if (q.isEmpty) return const [];
  final svc = ref.watch(archiveServiceProvider);
  return svc.search(q);
});

/// Internet Archive：条目内的可播放音频文件。
final archiveTracksProvider =
    FutureProvider.autoDispose.family<List<Track>, ArchiveItem>((ref, item) {
  final svc = ref.watch(archiveServiceProvider);
  return svc.tracksOf(item);
});