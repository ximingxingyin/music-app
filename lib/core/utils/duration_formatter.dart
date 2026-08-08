/// 时长格式化工具
String formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// 大致时长显示（用于列表行尾）
String formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h:$m';
  return '$m:${s.toString().padLeft(2, '0')}';
}