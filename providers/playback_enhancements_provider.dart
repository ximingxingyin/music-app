import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';

/// 睡眠定时器 —— 到时间自动暂停播放。
class SleepTimerController {
  SleepTimerController(this.ref);
  final Ref ref;

  Timer? _timer;
  Duration? _remaining;

  Duration? get remaining => _remaining;
  bool get isActive => _remaining != null;

  /// 启动 [minutes] 分钟定时器。传 0 表示取消。
  void start(int minutes) {
    _timer?.cancel();
    if (minutes <= 0) {
      _remaining = null;
    } else {
      _remaining = Duration(minutes: minutes);
      _timer = Timer(Duration(minutes: minutes), () {
        ref.read(audioHandlerProvider).pause();
        _remaining = null;
        ref.read(sleepTimerTickProvider.notifier).state++;
      });
    }
    ref.read(sleepTimerTickProvider.notifier).state++;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _remaining = null;
    ref.read(sleepTimerTickProvider.notifier).state++;
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// 用于触发 UI 刷新的状态。
final sleepTimerTickProvider = StateProvider<int>((_) => 0);

final sleepTimerProvider = Provider<SleepTimerController>((ref) {
  final c = SleepTimerController(ref);
  ref.onDispose(c.dispose);
  return c;
});

/// 均衡器 Provider（占位：just_audio 均衡器 API 复杂，本期先做 UI 框架 + 预设展示，
/// 真实启用留给 v0.5 接入 `android_audio_effects`）。
///
/// 返回 true 表示均衡器 API 可用，UI 据此启用开关。
final equalizerAvailableProvider = Provider<bool>((ref) => false);

/// 当前选中的 EQ 预设名。
final equalizerPresetProvider = StateProvider<String>((_) => '默认');

/// EQ 预设定义。
class EqualizerPreset {
  final String name;
  final String description;
  final List<int> gains; // dB, 5 段
  const EqualizerPreset(this.name, this.description, this.gains);
}

const List<EqualizerPreset> kEqualizerPresets = [
  EqualizerPreset('默认', '平直响应', [0, 0, 0, 0, 0]),
  EqualizerPreset('流行', '人声突出，低音增强', [3, 1, 0, 2, 3]),
  EqualizerPreset('摇滚', '高低音均强，中频略减', [5, 3, -1, 2, 5]),
  EqualizerPreset('爵士', '中频饱满', [4, 2, -1, 2, 4]),
  EqualizerPreset('古典', '高频通透', [4, 3, 0, 2, 3]),
  EqualizerPreset('电子', '低音厚实，高音锐利', [4, 1, 0, 1, 4]),
  EqualizerPreset('低音增强', '强化低频', [6, 4, 2, 0, 0]),
  EqualizerPreset('人声', '突出中频', [-2, -1, 3, 4, 2]),
];