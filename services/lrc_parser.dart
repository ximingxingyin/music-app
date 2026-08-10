/// LRC 歌词解析器（支持双语 / 翻译行）。
///
/// 支持格式：
/// ```
/// [00:01.23]这是歌词
/// [00:05.67]另一句
/// ```
///
/// 双语（网易云 / QQ 风格）：
/// ```
/// [00:01.23]第一句中文
/// [00:01.23]First line English
/// [00:05.67]第二句中文
/// [00:05.67]Second line English
/// ```
///
/// 元数据行（[ar:xxx] [ti:xxx] [al:xxx]）会被忽略。

class LrcLine {
  final Duration time;
  final String text;

  /// 翻译行（如果有）。通常对应同一时间戳的第二行。
  final String? translation;

  const LrcLine(this.time, this.text, {this.translation});
}

class Lrc {
  final List<LrcLine> lines;
  const Lrc(this.lines);

  bool get isEmpty => lines.isEmpty;
  bool get hasTranslation =>
      lines.any((l) => l.translation != null && l.translation!.isNotEmpty);

  /// 根据当前播放进度返回当前应高亮的歌词索引。
  /// 找不到（位置早于第一句）返回 -1。
  int indexAt(Duration position) {
    if (lines.isEmpty) return -1;
    int lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (lines[mid].time <= position) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  static final _empty = Lrc(const []);
  static Lrc get empty => _empty;

  /// 解析 LRC 文本。
  static Lrc parse(String text) {
    if (text.trim().isEmpty) return _empty;

    // 第一遍：解析出所有 (time, text) 对
    final rawLines = <LrcLine>[];
    final regex = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]');

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (!regex.hasMatch(line)) continue;

      final timestamps = <Duration>[];
      for (final m in regex.allMatches(line)) {
        final min = int.tryParse(m.group(1) ?? '') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '') ?? 0;
        final msPart = m.group(3) ?? '';
        final ms = int.tryParse(msPart) ?? 0;
        final msValue = msPart.length == 3
            ? ms
            : msPart.length == 2
                ? ms * 10
                : ms * 100;
        timestamps.add(Duration(
          minutes: min,
          seconds: sec,
          milliseconds: msValue,
        ));
      }
      final lyricText = line.replaceAll(regex, '').trim();
      if (lyricText.isEmpty && timestamps.isEmpty) continue;
      for (final ts in timestamps) {
        rawLines.add(LrcLine(ts, lyricText));
      }
    }
    rawLines.sort((a, b) => a.time.compareTo(b.time));

    // 第二遍：合并同时间戳的相邻行（双语格式）
    final merged = <LrcLine>[];
    for (final line in rawLines) {
      if (merged.isNotEmpty &&
          merged.last.time == line.time &&
          merged.last.translation == null &&
          line.text.isNotEmpty) {
        // 把上一行的 text 当主歌词，本行作为翻译
        final prev = merged.removeLast();
        merged.add(LrcLine(
          prev.time,
          prev.text,
          translation: line.text,
        ));
      } else {
        merged.add(line);
      }
    }

    return Lrc(merged);
  }

  /// 从音乐文件路径推断同名 LRC 路径。
  static String? inferLrcPath(String audioPath) {
    final dot = audioPath.lastIndexOf('.');
    if (dot <= 0) return null;
    final base = audioPath.substring(0, dot);
    return '$base.lrc';
  }
}