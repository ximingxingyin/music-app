import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database.dart';
import '../data/models/track.dart';
import '../services/lrc_parser.dart';
import 'library_provider.dart';
import 'player_provider.dart';

/// 当前曲目的歌词。
///
/// 加载优先级：
/// 1. 数据库中用户手动指定的 lrc_path（最高）
/// 2. 推断的同名 .lrc 文件（自动识别）
/// 3. 空 Lrc（无歌词）
final currentLrcProvider = FutureProvider<Lrc>((ref) async {
  final trackAsync = ref.watch(currentTrackFullProvider);
  final track = trackAsync.value;
  if (track == null || track.uri.isEmpty || !track.isLocal) {
    return Lrc.empty;
  }

  // 1) 查数据库手动指定路径
  final db = ref.read(databaseProvider);
  final custom = await db.getLrcPath(track.id);
  if (custom != null && custom.isNotEmpty) {
    final lrc = await _readLrc(custom);
    if (!lrc.isEmpty) return lrc;
  }

  // 2) 自动推断同名 .lrc
  final lrcPath = Lrc.inferLrcPath(track.uri);
  if (lrcPath == null) return Lrc.empty;
  return _readLrc(lrcPath);
});

/// 实际读取 + 解析
Future<Lrc> _readLrc(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return Lrc.empty;
    return Lrc.parse(await file.readAsString());
  } catch (_) {
    return Lrc.empty;
  }
}

/// 辅助：根据 Track 直接加载 LRC（用于离线使用）
Future<Lrc> loadLrcForTrack(Track track) async {
  if (track.uri.isEmpty || !track.isLocal) return Lrc.empty;
  final lrcPath = Lrc.inferLrcPath(track.uri);
  if (lrcPath == null) return Lrc.empty;
  return _readLrc(lrcPath);
}