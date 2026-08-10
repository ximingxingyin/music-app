import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/models/track.dart';

/// 网络电台信息（Radio Browser API 条目）。
class RadioStation {
  final String uuid;
  final String name;
  final String url; // 解析后的直播流地址
  final String? favicon;
  final String country;
  final String language;
  final String tags;
  final int votes;
  final int clickCount;
  final String? codec;
  final int? bitrate;

  const RadioStation({
    required this.uuid,
    required this.name,
    required this.url,
    this.favicon,
    this.country = '',
    this.language = '',
    this.tags = '',
    this.votes = 0,
    this.clickCount = 0,
    this.codec,
    this.bitrate,
  });

  /// 流格式标签（列表展示用）。
  String get streamLabel {
    final u = url.toLowerCase();
    if (u.endsWith('.m3u8') || u.contains('.m3u8?')) return 'HLS';
    if (u.endsWith('.mp3') || u.contains('.mp3?')) return 'MP3';
    if (u.endsWith('.aac') || u.contains('.aac?')) return 'AAC';
    if (u.endsWith('.ogg') || u.contains('.ogg?')) return 'OGG';
    if (u.endsWith('.m4a') || u.contains('.m4a?')) return 'M4A';
    final c = (codec ?? '').toUpperCase();
    if (c.startsWith('MP3')) return 'MP3';
    if (c.startsWith('AAC')) return 'AAC';
    if (c.startsWith('OGG')) return 'OGG';
    return '流';
  }

  /// 稳定性分数：越小越稳。
  /// 渐进式流（mp3/aac/ogg 等）国内网络下最稳；HLS 分片流次之。
  int get stabilityRank {
    final u = url.toLowerCase();
    if (u.endsWith('.m3u8') || u.contains('.m3u8?')) return 2;
    if (u.endsWith('.mp3') || u.endsWith('.aac') || u.endsWith('.ogg') ||
        u.endsWith('.m4a') || u.endsWith('.opus')) {
      return 0;
    }
    final c = (codec ?? '').toUpperCase();
    if (c.startsWith('MP3') || c.startsWith('AAC') || c.startsWith('OGG')) {
      return 0;
    }
    return 1;
  }

  /// 转成统一的 Track（直播流，duration 为 0）。
  Track toTrack() {
    final tagPart = tags.isNotEmpty ? ' · $tags' : '';
    final info = [
      if (country.isNotEmpty) country,
      if (language.isNotEmpty) language,
      if (codec != null && codec!.isNotEmpty) codec!,
    ].join(' · ');
    return Track(
      id: 'radio:$uuid',
      title: name,
      artist: info.isEmpty ? '网络电台' : info,
      album: '网络电台',
      duration: Duration.zero,
      uri: url,
      source: TrackSource.radio,
      albumArtUrl: (favicon != null && favicon!.isNotEmpty) ? favicon : null,
      genre: tagPart.isEmpty ? null : tagPart.trim(),
    );
  }
}

/// Radio Browser 客户端（https://www.radio-browser.info）。
/// 开放 API、无需 key：中文台列表 / 按名称搜索。
/// 官方文档：https://api.radio-browser.info/
class RadioBrowserService {
  RadioBrowserService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const List<String> _hosts = [
    'https://de1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
  ];

  String? _workingHost;

  /// 探测可用主机（带 3s 超时，逐个尝试）。
  Future<String> _host() async {
    if (_workingHost != null) return _workingHost!;
    for (final h in _hosts) {
      try {
        final res = await _client
            .get(Uri.parse('$h/json/servers'))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          _workingHost = h;
          return h;
        }
      } catch (_) {
        // try next
      }
    }
    throw Exception('Radio Browser 无可用节点');
  }

  /// 中文网络电台列表（按收听热度排序）。
  Future<List<RadioStation>> chineseStations({int limit = 100}) async {
    final host = await _host();
    final uri = Uri.parse(
      '$host/json/stations/search'
      '?language=chinese&order=clickcount&reverse=true&limit=$limit'
      '&hidebroken=true',
    );
    return _fetchStations(uri);
  }

  /// 按名称搜索电台。
  Future<List<RadioStation>> search(String query, {int limit = 100}) async {
    final host = await _host();
    final q = Uri.encodeQueryComponent(query);
    final uri = Uri.parse(
      '$host/json/stations/search'
      '?name=$q&order=clickcount&reverse=true&limit=$limit'
      '&hidebroken=true',
    );
    return _fetchStations(uri);
  }

  Future<List<RadioStation>> _fetchStations(Uri uri) async {
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Radio Browser ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List? ?? const [];
    final stations = <RadioStation>[];
    for (final m in list) {
      final map = m as Map<String, dynamic>;
      // 优先使用解析后的流地址，缺失则退回原地址
      final resolved = (map['url_resolved'] as String?)?.trim();
      final raw = (map['url'] as String?)?.trim();
      final url = (resolved != null && resolved.isNotEmpty)
          ? resolved
          : (raw ?? '');
      if (url.isEmpty) continue;
      stations.add(RadioStation(
        uuid: (map['stationuuid'] as String?) ?? url,
        name: (map['name'] as String?) ?? 'Unknown',
        url: url,
        favicon: (map['favicon'] as String?)?.trim(),
        country: (map['country'] as String?) ?? '',
        language: (map['language'] as String?) ?? '',
        tags: (map['tags'] as String?) ?? '',
        votes: (map['votes'] as num?)?.toInt() ?? 0,
        clickCount: (map['clickcount'] as num?)?.toInt() ?? 0,
        codec: (map['codec'] as String?) ?? '',
        bitrate: (map['bitrate'] as num?)?.toInt(),
      ));
    }
    return stations
      // 稳定性优先（渐进式流在前），同档按收听热度排序
      ..sort((a, b) {
        final byRank = a.stabilityRank.compareTo(b.stabilityRank);
        if (byRank != 0) return byRank;
        return b.clickCount.compareTo(a.clickCount);
      });
  }
}
