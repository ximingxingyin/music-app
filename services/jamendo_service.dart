import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/models/track.dart';

/// Jamendo 在线电台客户端。
/// 文档：https://developer.jamendo.com/v3.0
/// 注意：Jamendo 没有中文主流音乐，主要做"独立/外文发现"。
class JamendoService {
  JamendoService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  String get _base => 'https://api.jamendo.com/v3.0';

  /// 获取曲目列表。商用时记得：必须显示 Jamendo 归属 + 跳转链接。
  Future<List<Track>> tracks({int limit = 50, String? search}) async {
    final params = {
      'client_id': AppConstants.jamendoClientId,
      'format': 'json',
      'limit': '$limit',
      'include': 'musicinfo',
      'audioformat': 'mp32',
    };
    final endpoint = (search != null && search.isNotEmpty)
        ? 'tracks/?search=$search'
        : 'tracks/?order=popularity_total';
    final uri = Uri.parse('$_base/$endpoint&${Uri(queryParameters: params).query}');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Jamendo ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['results'] as List?) ?? const [];
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return Track(
        id: 'jamendo:${map['id']}',
        title: map['name'] as String? ?? 'Unknown',
        artist: map['artist_name'] as String? ?? 'Unknown',
        album: map['album_name'] as String? ?? '',
        duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
        uri: map['audio'] as String? ?? '',
        source: TrackSource.jamendo,
        albumArtUrl: map['album_image'] as String?,
        genre: map['musicinfo']?['tags']?.toString(),
      );
    }).toList();
  }

  /// 按专辑获取。
  Future<List<({String id, String name, String artist, String? cover})>>
      albums({int limit = 30}) async {
    final uri = Uri.parse(
      '$_base/albums/?limit=$limit&order=popularity_total'
      '&client_id=${AppConstants.jamendoClientId}&format=json'
      '&imagesize=300',
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Jamendo ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['results'] as List?) ?? const [];
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return (
        id: 'jamendo-album:${map['id']}',
        name: map['name'] as String? ?? 'Unknown',
        artist: map['artist_name'] as String? ?? 'Unknown',
        cover: map['image'] as String?,
      );
    }).toList();
  }
}

/// Audius 公共 API 客户端（无需 key 的部分）。
class AudiusService {
  AudiusService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// 找可用的公共 host。
  Future<String?> resolveHost() async {
    for (final h in AppConstants.audiusHosts) {
      try {
        final res = await _client
            .get(Uri.parse('$h/v1/users/root'))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) return h;
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  /// 热门曲目。
  Future<List<Track>> trending({int limit = 30}) async {
    final host = await resolveHost();
    if (host == null) throw Exception('无可用 Audius 节点');
    final uri = Uri.parse(
      '$host/v1/tracks/trending?limit=$limit&app_name=ximing-music',
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Audius ${res.statusCode}');
    }
    return _parseTracks(jsonDecode(res.body) as List, host);
  }

  /// 全文搜索。
  /// 文档：https://docs.audius.org/api/tracks/
  Future<List<Track>> search({required String query, int limit = 30}) async {
    final host = await resolveHost();
    if (host == null) throw Exception('无可用 Audius 节点');
    final q = Uri.encodeQueryComponent(query);
    final uri = Uri.parse(
      '$host/v1/tracks/search?query=$q&limit=$limit&app_name=ximing-music',
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Audius 搜索 ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    // 搜索结果结构：{"data": [...]}
    final list = (body is Map ? body['data'] : body) as List? ?? const [];
    return _parseTracks(list, host);
  }

  List<Track> _parseTracks(List list, String host) {
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return Track(
        id: 'audius:${map['id']}',
        title: map['title'] as String? ?? 'Unknown',
        artist: map['user']?['name'] as String? ?? 'Unknown',
        album: '',
        duration: Duration(seconds: (map['duration'] as num?)?.toInt() ?? 0),
        uri: '$host/v1/tracks/${map['id']}/stream',
        source: TrackSource.audius,
        albumArtUrl: map['artwork']?['480x480'] as String?,
        genre: map['genre'] as String?,
      );
    }).toList();
  }
}