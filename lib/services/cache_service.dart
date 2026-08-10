import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, Value;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../data/database/database.dart';
import '../data/models/track.dart';

/// 在线曲目下载服务。
///
/// 把 Jamendo / Audius 的在线曲目下载到本地 `app_docs/cache/{source}/{trackId}.mp3`，
/// 并把元信息写入 `cached_tracks` 表。
///
/// 真实使用场景：用户在线电台页面点击"下载"按钮 → 文件落到本地 → 下次可离线播放。
class CacheService {
  CacheService(this._db);
  final AppDatabase _db;
  final http.Client _client = http.Client();

  /// 默认缓存总大小上限（500MB），可在设置里调整。
  int maxBytes = 500 * 1024 * 1024;

  /// 下载状态
  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  Future<String> _cacheDir(TrackSource source) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'cache', source.name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 把 online Track 的 id 转成可作为本地文件名的安全字符串。
  /// Track.id 形如 "jamendo:12345" → "jamendo_12345"
  String _safeFileName(Track t) {
    return t.id.replaceAll(':', '_');
  }

  /// 该曲目是否已缓存。
  Future<bool> isCached(Track t) async {
    final row = await (_db.select(_db.cachedTracks)
          ..where((c) => c.id.equals(t.id)))
        .getSingleOrNull();
    return row != null && await File(row.localPath).exists();
  }

  /// 获取缓存文件的本地路径（如果存在）。
  Future<String?> getCachedPath(Track t) async {
    final row = await (_db.select(_db.cachedTracks)
          ..where((c) => c.id.equals(t.id)))
        .getSingleOrNull();
    if (row == null) return null;
    final file = File(row.localPath);
    return file.existsSync() ? file.path : null;
  }

  /// 下载曲目到本地缓存。
  /// 返回本地文件路径。
  Future<String> download(Track t, {void Function(double)? onProgress}) async {
    if (t.isLocal) {
      throw Exception('本地曲目不需要缓存');
    }
    final dir = await _cacheDir(t.source);
    final ext = _extFromUrl(t.uri);
    final localPath = p.join(dir, '${_safeFileName(t)}.$ext');

    // 已经在下载
    if (await File(localPath).exists()) {
      await _db.upsertCache(CachedTracksCompanion(
        id: Value(t.id),
        source: Value(t.source.name),
        localPath: Value(localPath),
        sizeBytes: Value(await File(localPath).length()),
      ));
      return localPath;
    }

    // 触发下载
    final req = http.Request('GET', Uri.parse(t.uri));
    final res = await _client.send(req);
    if (res.statusCode != 200) {
      throw Exception('下载失败: HTTP ${res.statusCode}');
    }

    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = File(localPath).openWrite();
    await for (final chunk in res.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call(received / total);
      }
    }
    await sink.flush();
    await sink.close();

    final size = await File(localPath).length();
    await _db.upsertCache(CachedTracksCompanion(
      id: Value(t.id),
      source: Value(t.source.name),
      localPath: Value(localPath),
      sizeBytes: Value(size),
      cachedAt: Value(DateTime.now()),
    ));

    _progressController.add(DownloadProgress(
      trackId: t.id,
      total: size,
      done: true,
    ));

    // 触发 LRU 清理
    await enforceLimit();
    return localPath;
  }

  String _extFromUrl(String url) {
    final clean = url.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0) return 'mp3';
    final ext = clean.substring(dot + 1).toLowerCase();
    if (ext.length > 4) return 'mp3';
    return ext;
  }

  /// 标记已播放（用于 LRU 排序）。
  Future<void> markPlayed(String trackId) async {
    await _db.customStatement(
      'UPDATE cached_tracks SET last_played_at = ? WHERE id = ?',
      [
        Variable.withDateTime(DateTime.now()),
        Variable.withString(trackId),
      ],
    );
  }

  /// 删除单个缓存（公开 API）
  Future<void> deleteCacheEntry(String id) async {
    final row = await (_db.select(_db.cachedTracks)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    try {
      final f = File(row.localPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    await _db.deleteCache(id);
  }

  /// 强制 LRU：超出 maxBytes 时，按 lastPlayedAt 升序删除最早未播放的。
  Future<int> enforceLimit() async {
    final all = await _db.getAllCaches();
    final total = all.fold<int>(0, (s, r) => s + r.sizeBytes);
    if (total <= maxBytes) return 0;

    // 按 lastPlayedAt asc（NULL 视为最旧）
    final sorted = [...all]..sort((a, b) {
        final aT = a.lastPlayedAt?.millisecondsSinceEpoch ?? 0;
        final bT = b.lastPlayedAt?.millisecondsSinceEpoch ?? 0;
        return aT.compareTo(bT);
      });

    var freed = 0;
    var deleted = 0;
    for (final r in sorted) {
      if (total - freed <= maxBytes) break;
      try {
        final f = File(r.localPath);
        if (await f.exists()) {
          await f.delete();
          freed += r.sizeBytes;
        }
        await _db.deleteCache(r.id);
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  /// 清空所有缓存。
  Future<void> clearAll() async {
    final all = await _db.getAllCaches();
    for (final r in all) {
      try {
        final f = File(r.localPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _db.customStatement('DELETE FROM cached_tracks');
  }

  /// 缓存统计信息。
  Future<({int count, int totalBytes})> stats() async {
    final all = await _db.getAllCaches();
    final total = all.fold<int>(0, (s, r) => s + r.sizeBytes);
    return (count: all.length, totalBytes: total);
  }

  void dispose() {
    _progressController.close();
    _client.close();
  }
}

class DownloadProgress {
  final String trackId;
  final int total;
  final bool done;
  const DownloadProgress({
    required this.trackId,
    required this.total,
    required this.done,
  });
}