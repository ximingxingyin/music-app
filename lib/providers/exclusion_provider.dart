import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library_provider.dart';

/// 扫描排除设置（持久化）。
/// 黑名单：扫描时跳过这些路径下的文件。
class ExclusionService {
  ExclusionService(this.ref);
  final Ref ref;

  static const _keyPrefix = 'exclusion.';

  Future<Set<String>> getExcludedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    return keys.map((k) => k.substring(_keyPrefix.length)).toSet();
  }

  Future<void> addExclusion(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$folderPath', true);
  }

  Future<void> removeExclusion(String folderPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$folderPath');
  }
}

final exclusionServiceProvider = Provider<ExclusionService>((ref) {
  return ExclusionService(ref);
});

/// 异步加载排除列表
final excludedFoldersProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  return ref.watch(exclusionServiceProvider).getExcludedFolders();
});

/// 脏数据清理（删除 tracks 表里文件已不存在的记录）
class CleanupService {
  CleanupService(this.ref);
  final Ref ref;

  /// 检查并清理脏数据，返回删除数量。
  Future<int> cleanupMissingFiles() async {
    final db = ref.read(databaseProvider);
    final rows = await db.customSelect(
      "SELECT id, uri FROM tracks WHERE id NOT LIKE 'ai:%' AND id NOT LIKE 'jamendo:%' AND id NOT LIKE 'audius:%'",
      readsFrom: {tracks},
    ).get();

    var removed = 0;
    for (final r in rows) {
      final uri = r.read<String>('uri');
      if (uri.isEmpty) continue;
      // 检查文件是否存在
      try {
        if (!File(uri).existsSync()) {
          await db.deleteTrack(r.read<String>('id'));
          removed++;
        }
      } catch (_) {
        // 异常路径，删掉
        await db.deleteTrack(r.read<String>('id'));
        removed++;
      }
    }

    // 清理对应的播放历史 + 歌单关联
    if (removed > 0) {
      await db.customStatement(
        "DELETE FROM play_history WHERE track_id NOT IN (SELECT id FROM tracks)",
      );
      await db.customStatement(
        "DELETE FROM playlist_tracks WHERE track_id NOT IN (SELECT id FROM tracks)",
      );
    }

    return removed;
  }

  /// 获取外部存储目录列表（让用户选择要排除的路径）
  Future<List<String>> listCandidateFolders() async {
    final results = <String>[];
    final dirs = <Directory>[];

    try {
      final docs = await getApplicationDocumentsDirectory();
      dirs.add(docs);
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) dirs.add(ext);
    } catch (_) {}

    for (final d in dirs) {
      results.add(d.path);
      // 一级子目录
      try {
        final entries = d.listSync().whereType<Directory>();
        for (final e in entries) {
          results.add(e.path);
        }
      } catch (_) {}
    }

    return results;
  }
}

final cleanupServiceProvider = Provider<CleanupService>((ref) {
  return CleanupService(ref);
});