import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史 + 热门搜索。
class SearchHistoryService {
  static const _keyHistory = 'search.history';
  static const _keyHot = 'search.hot';
  static const maxHistory = 20;
  static const maxHot = 10;

  /// 获取最近搜索关键词（按时间倒序）
  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyHistory) ?? const [];
    return list;
  }

  /// 添加到搜索历史
  Future<void> addHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_keyHistory) ?? const []).toList();
    list.remove(q); // 移到最前
    list.insert(0, q);
    if (list.length > maxHistory) {
      list.removeRange(maxHistory, list.length);
    }
    await prefs.setStringList(_keyHistory, list);

    // 更新热门计数
    final hotMap = await getHotMap();
    hotMap[q] = (hotMap[q] ?? 0) + 1;
    await prefs.setString(_keyHot, jsonEncode(hotMap));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  /// 热门关键词（按搜索次数排序）
  Future<List<String>> getHot() async {
    final map = await getHotMap();
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxHot).map((e) => e.key).toList();
  }

  Future<Map<String, int>> getHotMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyHot);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v as int));
      }
    } catch (_) {}
    return {};
  }
}

final searchHistoryProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return SearchHistoryService().getHistory();
});

final searchHotProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return SearchHistoryService().getHot();
});