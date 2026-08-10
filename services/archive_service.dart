import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/models/track.dart';

/// Internet Archive 馆藏条目（搜索结果的抽象）。
class ArchiveItem {
  final String identifier;
  final String title;
  final String creator;
  final int? year;
  final int downloads;

  const ArchiveItem({
    required this.identifier,
    required this.title,
    required this.creator,
    this.year,
    this.downloads = 0,
  });

  /// 条目缩略图（archive.org 自动生成）。
  String get thumbUrl =>
      'https://archive.org/download/$identifier/__ia_thumb.jpg';
}

/// Internet Archive 客户端（https://archive.org）。
/// 非营利数字图书馆，公版/授权内容开放公开读取，无需 API key。
/// 文档：https://archive.org/developers/
class ArchiveService {
  ArchiveService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const String _searchBase = 'https://archive.org/advancedsearch.php';
  static const String _metaBase = 'https://archive.org/metadata';

  static const Set<String> _audioFormats = {
    'MP3',
    'VBR MP3',
    'OGG VORBIS',
    'Ogg Vorbis',
    'FLAC',
    'MPEG-4 Audio',
  };

  /// 搜索音频馆藏（默认按下载量排序）。
  Future<List<ArchiveItem>> search(String query, {int rows = 60}) async {
    final q = Uri.encodeQueryComponent('$query AND mediatype:audio');
    final uri = Uri.parse(
      '$_searchBase?q=$q'
      '&fl[]=identifier&fl[]=title&fl[]=creator&fl[]=year&fl[]=downloads'
      '&rows=$rows&page=1&output=json&sort[]=downloads+desc',
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Archive ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['response']?['docs'] as List?) ?? const [];
    return docs.map((m) {
      final map = m as Map<String, dynamic>;
      final identifier = (map['identifier'] as String?) ?? '';
      final title = (map['title'] as String?)?.trim();
      return ArchiveItem(
        identifier: identifier,
        title: (title == null || title.isEmpty) ? identifier : title,
        creator: (map['creator'] as String?) ?? 'Unknown',
        year: (map['year'] as num?)?.toInt(),
        downloads: (map['downloads'] as num?)?.toInt() ?? 0,
      );
    }).where((i) => i.identifier.isNotEmpty).toList();
  }

  /// 拉取条目元数据，把可播放的音频文件转成 Track 列表。
  /// [itemTitle] 用于专辑名展示，为空时从 metadata 读取。
  Future<List<Track>> tracksOf(ArchiveItem item) async {
    final uri = Uri.parse('$_metaBase/${item.identifier}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Archive metadata ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final meta = (body['metadata'] as Map<String, dynamic>?) ?? {};
    final files = (body['files'] as List?) ?? const [];

    final albumTitle = item.title.isNotEmpty
        ? item.title
        : ((meta['title'] as String?) ?? item.identifier);
    final creator = item.creator.isNotEmpty
        ? item.creator
        : ((meta['creator'] as String?) ?? 'Unknown');

    final tracks = <Track>[];
    for (final f in files) {
      final map = f as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? '';
      final format = (map['format'] as String?) ?? '';
      // 跳过目录、隐藏文件（_ 开头）、非音频格式
      if (name.isEmpty || name.startsWith('_') || name.endsWith('/')) continue;
      if (!_audioFormats.contains(format.toUpperCase())) continue;
      final encodedName = Uri.encodeComponent(name);
      tracks.add(Track(
        id: 'archive:${item.identifier}:$name',
        // 去掉扩展名做标题，带标题字段则优先
        title: (map['title'] as String?)?.trim().isNotEmpty == true
            ? (map['title'] as String).trim()
            : _stripExt(name),
        artist: creator,
        album: albumTitle,
        duration: Duration(seconds: _toSeconds(map['length'])),
        uri: 'https://archive.org/download/${item.identifier}/$encodedName',
        source: TrackSource.archive,
        albumArtUrl: item.thumbUrl,
        year: (map['year'] as num?)?.toInt() ?? item.year,
      ));
    }
    return tracks;
  }

  /// 兼容 IA 的 length 字段格式：数字秒 / 数字字符串 / mm:ss / hh:mm:ss。
  int _toSeconds(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    if (RegExp(r'^\d+$').hasMatch(s)) return int.parse(s);
    final parts = s.split(':');
    if (parts.length >= 2) {
      var sec = 0;
      for (final p in parts) {
        final n = int.tryParse(p.trim());
        if (n == null) return 0;
        sec = sec * 60 + n;
      }
      return sec;
    }
    return 0;
  }

  String _stripExt(String name) {
    final idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(0, idx) : name;
  }
}
