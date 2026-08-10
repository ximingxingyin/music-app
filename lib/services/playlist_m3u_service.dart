import 'dart:io';

import 'package:drift/drift.dart' show Variable, Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/database/database.dart';

/// M3U 格式歌单导入导出。
///
/// 标准 M3U：
/// ```
/// #EXTM3U
/// #EXTINF:duration,artist - title
/// /path/to/song.mp3
/// ```
class PlaylistM3uService {
  PlaylistM3uService(this._db);
  final AppDatabase _db;

  /// 导出指定歌单到 Downloads/袭明音乐/{name}.m3u
  Future<String> exportPlaylist({
    required String playlistId,
    required String playlistName,
  }) async {
    final rows = await _db.customSelect(
      "SELECT t.title, t.artist, t.album, t.duration_ms, t.uri, pt.position "
      "FROM tracks t INNER JOIN playlist_tracks pt ON pt.track_id = t.id "
      "WHERE pt.playlist_id = ? ORDER BY pt.position ASC",
      variables: [Variable.withString(playlistId)],
      readsFrom: {_db.tracks, _db.playlistTracks},
    ).get();

    if (rows.isEmpty) {
      throw Exception('歌单为空，无法导出');
    }

    final buffer = StringBuffer()..writeln('#EXTM3U');
    for (final r in rows) {
      final title = r.read<String>('title');
      final artist = r.read<String>('artist');
      final album = r.read<String>('album');
      final dur = r.read<int>('duration_ms') ~/ 1000;
      final uri = r.read<String>('uri');
      buffer.writeln('#EXTINF:$dur,$artist - $title ($album)');
      buffer.writeln(uri);
    }

    final dir = Directory('/storage/emulated/0/Download/袭明音乐');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safeName = playlistName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(dir.path, '$safeName.m3u'));
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  /// 从 M3U 文件导入。返回新建的歌单 ID。
  Future<String> importFromFile({
    required File file,
    String? playlistName,
  }) async {
    final text = await file.readAsString();
    return importFromText(text: text, name: playlistName ?? p.basenameWithoutExtension(file.path));
  }

  /// 从文本导入。
  Future<String> importFromText({
    required String text,
    String? name,
  }) async {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    if (lines.isEmpty || !lines.first.startsWith('#EXTM3U')) {
      throw Exception('无效的 M3U 文件');
    }

    // 创建新歌单
    final playlistName = name ?? '导入的歌单 ${DateTime.now().millisecondsSinceEpoch}';
    final playlistId = const Uuid().v4();
    await _db.upsertPlaylist(
      PlaylistsCompanion(id: Value(playlistId), name: Value(playlistName)),
    );

    var importedCount = 0;
    var skipped = 0;
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty || line.startsWith('#')) continue;
      // line 是文件 URI / path
      // 在 tracks 表里查匹配
      final trackId = await _findTrackByUri(line);
      if (trackId != null) {
        await _db.addTrackToPlaylist(
          playlistId,
          trackId,
          position: importedCount,
        );
        importedCount++;
      } else {
        skipped++;
      }
    }

    if (importedCount == 0) {
      // 没匹配到任何曲目，删掉空歌单
      await _db.deletePlaylist(playlistId);
      throw Exception('没有匹配的本地曲目，跳过 $skipped 条');
    }

    return playlistId;
  }

  /// 在 tracks 表里找匹配 uri 的曲目。
  Future<String?> _findTrackByUri(String uriOrPath) async {
    // 去掉可能的前缀（content:// 等）
    final candidates = <String>{uriOrPath};
    // 路径中可能的文件名
    final basename = p.basename(uriOrPath);
    if (basename.isNotEmpty) candidates.add(basename);

    for (final c in candidates) {
      final row = await _db.customSelect(
        "SELECT id FROM tracks WHERE uri = ? OR uri LIKE ? LIMIT 1",
        variables: [Variable.withString(c), Variable.withString('%${p.basename(c)}')],
        readsFrom: {_db.tracks},
      ).getSingleOrNull();
      if (row != null) {
        return row.read<String>('id');
      }
    }
    return null;
  }
}
