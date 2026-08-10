import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database.dart';
import 'library_provider.dart';
import '../services/cache_service.dart';

/// 缓存服务 Provider
final cacheServiceProvider = Provider<CacheService>((ref) {
  final svc = CacheService(ref.watch(databaseProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

/// 缓存统计（自动失效）
final cacheStatsProvider = FutureProvider<({int count, int totalBytes})>((ref) async {
  return ref.watch(cacheServiceProvider).stats();
});

/// 缓存上限（持久化，v0.6 写死默认）
final cacheMaxBytesProvider = StateProvider<int>((_) => 500 * 1024 * 1024);