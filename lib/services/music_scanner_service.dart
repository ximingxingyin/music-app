import 'dart:io';
import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../data/database/database.dart';
import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';

/// 扫描进度状态
class ScanProgress {
  final int total;
  final int processed;
  final String currentStep;
  const ScanProgress({
    required this.total,
    required this.processed,
    required this.currentStep,
  });
  double get ratio => total == 0 ? 0 : processed / total;
}

/// 扫描设备本地音乐 + 写入数据库。
/// 依赖 on_audio_query（封装 Android MediaStore）。
class MusicScannerService {
  MusicScannerService(this._db);
  final AppDatabase _db;
  final OnAudioQuery _query = OnAudioQuery();

  // 缓存：albumId -> 本地文件路径（避免重复提取）
  final Map<int, String> _albumArtCache = {};

  // 扫描进度回调
  void Function(ScanProgress)? onProgress;

  // 加载排除列表回调
  Future<Set<String>> Function()? onExclusionsLoaded;

  /// 请求运行时权限（Android 13+ 用 READ_MEDIA_AUDIO，旧版用 READ_EXTERNAL_STORAGE）。
  Future<bool> requestPermission() async {
    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }
    final status = await Permission.audio.request();
    if (status.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted || storage.isLimited;
  }

  /// 全量扫描并入库（增量：已存在的 id 跳过非业务字段）。
  /// 同时提取每个专辑的封面，缓存到 app 内部目录。
  Future<int> scanAll() async {
    final hasPerm = await requestPermission();
    if (!hasPerm) {
      throw Exception('未授予音频读取权限');
    }
    // 第一步：扫描歌曲
    onProgress?.call(ScanProgress(
      total: 0,
      processed: 0,
      currentStep: '扫描设备音乐文件',
    ));
    final rawSongs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // 应用黑名单过滤
    final excludedFolders = await onExclusionsLoaded?.call() ?? <String>{};
    final songs = rawSongs.where((s) {
      final path = s.data.isNotEmpty ? s.data : (s.uri ?? '');
      if (path.isEmpty) return false;
      for (final ex in excludedFolders) {
        if (path.startsWith(ex)) return false;
      }
      return true;
    }).toList();

    if (excludedFolders.isNotEmpty) {
      onProgress?.call(ScanProgress(
        total: 0,
        processed: 0,
        currentStep:
            '扫描设备音乐文件（已排除 ${excludedFolders.length} 个文件夹，剩余 ${songs.length}/${rawSongs.length}）',
      ));
    }

    // 第二步：去重 albumId，提取封面
    final albumIds = <int>{};
    for (final s in songs) {
      if (s.albumId != null && s.albumId! > 0) {
        albumIds.add(s.albumId!);
      }
    }
    var processedAlbums = 0;
    for (final aid in albumIds) {
      try {
        final bytes = await _query.queryArtwork(
          aid,
          ArtworkType.ALBUM,
          size: 300,
          quality: 80,
        );
        if (bytes != null && bytes.isNotEmpty) {
          final path = await _saveArtwork(aid, bytes);
          _albumArtCache[aid] = path;
        }
      } catch (_) {
        // 单个专辑失败不影响整体扫描
      }
      processedAlbums++;
      onProgress?.call(ScanProgress(
        total: albumIds.length,
        processed: processedAlbums,
        currentStep: '提取专辑封面',
      ));
    }

    // 第三步：写入曲目
    var inserted = 0;
    for (final s in songs) {
      final albumArtPath = (s.albumId != null)
          ? _albumArtCache[s.albumId!]
          : null;
      await _db.upsertTrack(
        TracksCompanion(
          id: Value(s.id.toString()),
          title: Value(s.title),
          artist: Value(s.artist ?? '未知艺术家'),
          album: Value(s.album ?? '未知专辑'),
          durationMs: Value(s.duration ?? 0),
          // 优先用 data（绝对文件路径），fallback 到 uri（content://）
          uri: Value(s.data.isNotEmpty ? s.data : (s.uri ?? '')),
          albumArtUri: Value(albumArtPath),
        ),
      );
      inserted++;
      onProgress?.call(ScanProgress(
        total: songs.length,
        processed: inserted,
        currentStep: '写入曲目元数据',
      ));
    }
    return inserted;
  }

  /// 保存封面字节到本地。
  Future<String> _saveArtwork(int albumId, Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final artworkDir = Directory(p.join(docs.path, 'artwork'));
    if (!await artworkDir.exists()) {
      await artworkDir.create(recursive: true);
    }
    final file = File(p.join(artworkDir.path, '$albumId.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 从数据库读取本地曲目列表（按标题排序）。
  Future<List<Track>> loadAll() async {
    final rows = await _db.getAllTracks();
    return rows.map(trackFromRow).toList();
  }

  /// 按专辑聚合。
  Future<List<({String album, String artist, String? coverPath, int count})>>
      loadAlbums() async {
    final rows = await _db.getAllTracks();
    final map = <String,
        ({String artist, String? coverPath, int count})>{};
    for (final r in rows) {
      final key = '${r.album}|${r.artist}';
      map.update(
        key,
        (v) => (artist: v.artist, coverPath: v.coverPath, count: v.count + 1),
        ifAbsent: () => (artist: r.artist, coverPath: r.albumArtUri, count: 1),
      );
    }
    return map.entries
        .map((e) => (
              album: e.key.split('|').first,
              artist: e.value.artist,
              coverPath: e.value.coverPath,
              count: e.value.count,
            ))
        .toList();
  }

  /// 按艺术家聚合（封面取该艺术家第一个有封面的专辑）。
  Future<List<({String artist, String? coverPath, int count})>> loadArtists() async {
    final rows = await _db.getAllTracks();
    final map = <String, ({String? coverPath, int count})>{};
    for (final r in rows) {
      map.update(
        r.artist,
        (v) => (coverPath: v.coverPath ?? r.albumArtUri, count: v.count + 1),
        ifAbsent: () => (coverPath: r.albumArtUri, count: 1),
      );
    }
    return map.entries
        .map((e) =>
            (artist: e.key, coverPath: e.value.coverPath, count: e.value.count))
        .toList();
  }

  /// 根据专辑查询专辑曲目。
  Future<List<Track>> loadAlbumTracks(String album, String artist) async {
    final all = await loadAll();
    return all.where((t) => t.album == album && t.artist == artist).toList();
  }

  /// 根据艺术家查询曲目。
  Future<List<Track>> loadArtistTracks(String artist) async {
    final all = await loadAll();
    return all.where((t) => t.artist == artist).toList();
  }
}