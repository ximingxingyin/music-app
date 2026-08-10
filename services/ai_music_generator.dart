import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

/// AI 生成音乐服务 v0.9 - 算法升级版。
///
/// 改进点（vs v0.8）：
///   1. **减法合成**（oscillator + filter + ADSR envelope）替代纯 sine wave
///   2. **真实鼓组**（noise + tone + 包络，模拟底鼓/小鼓/踩镲/中鼓）
///   3. **混响效果**（多延迟线模拟早期反射 + 后期衰减）
///   4. **真实音乐理论**（大调/小调音阶 + 流行和弦进行 I-V-vi-IV）
///   5. **音乐结构**（前奏/主歌 A/副歌/主歌 B/副歌/尾奏）
///
/// 仍然**零依赖、纯客户端**。
class AiMusicGenerator {
  static const int sampleRate = 22050;

  Future<String> generate({
    required String prompt,
    required AiGenre genre,
    required int durationSeconds,
  }) async {
    final seed = prompt.hashCode ^ genre.index ^ durationSeconds;
    final ctx = _ComposeContext(
      sampleRate: sampleRate,
      seed: seed,
      durationSeconds: durationSeconds,
      prompt: prompt,
    );

    ctx.rootNote = (seed.abs() % 12);
    ctx.bpm = _pickBpm(genre);

    final samples = _compose(ctx, genre);

    // 软压缩 + 限幅
    _softCompress(samples, threshold: 0.7, ratio: 4.0);
    _limit(samples, ceiling: 0.95);

    final wav = _wrapWav(samples);
    final path = await _writeFile(prompt, genre, wav);
    return path;
  }

  // ──────────── 主合成 ────────────

  Float64List _compose(_ComposeContext ctx, AiGenre genre) {
    final totalSamples = ctx.sampleRate * ctx.durationSeconds;
    final mix = Float64List(totalSamples);

    switch (genre) {
      case AiGenre.ambient:
        _composeAmbient(ctx, mix);
        break;
      case AiGenre.electronic:
        _composeElectronic(ctx, mix);
        break;
      case AiGenre.classical:
        _composeClassical(ctx, mix);
        break;
      case AiGenre.lofi:
        _composeLofi(ctx, mix);
        break;
      case AiGenre.percussion:
        _composePercussion(ctx, mix);
        break;
      case AiGenre.drone:
        _composeDrone(ctx, mix);
        break;
    }

    // 全局混响（轻微）
    final reverb = Reverb(ctx.sampleRate, roomSize: 0.3, decay: 0.4);
    for (var i = 0; i < mix.length; i++) {
      mix[i] = reverb.process(mix[i]);
    }

    return mix;
  }

  // ──────────── 风格实现 ────────────

  /// 环境氛围：缓慢 pad + 缓慢滤波演化 + 微颤
  void _composeAmbient(_ComposeContext ctx, Float64List out) {
    final reverb = Reverb(ctx.sampleRate, roomSize: 0.6, decay: 0.7);
    final scale = _scaleFreqs(ctx.rootNote, 'major', base: 'octave2');
    final chordProg = _progressAm(scale);

    final noteDur = (ctx.sampleRate * 4).round();
    final dt = 1 / ctx.sampleRate;

    for (var i = 0; i < out.length; i++) {
      final t = i * dt;
      final chordIdx = (i ~/ noteDur) % chordProg.length;
      final chord = chordProg[chordIdx];

      double s = 0;
      for (final f in chord) {
        final lp = LowPassFilter(
            cutoff: 600 + 200 * math.sin(2 * math.pi * 0.05 * t));
        final amp = 0.08 +
            0.04 * math.sin(2 * math.pi * 0.08 * t + ctx.seed * 0.001);
        final sample = lp.process(math.sin(2 * math.pi * f * t), dt: dt);
        s += amp * sample;
        // 八度叠加
        s += amp *
            0.3 *
            math.sin(2 * math.pi * f * 2 * t) *
            (0.5 + 0.5 * math.sin(2 * math.pi * 0.1 * t));
      }
      // 微颤
      s += 0.03 * math.sin(2 * math.pi * 1320 * t) * math.sin(2 * math.pi * 6 * t);

      out[i] = reverb.process(s);
    }
  }

  /// 电子：Lead（saw）+ Bass（square）+ 鼓组 + 混响
  void _composeElectronic(_ComposeContext ctx, Float64List out) {
    final rand = math.Random(ctx.seed);
    final scale = _scaleFreqs(ctx.rootNote, 'minor', base: 'octave3');
    final drum = DrumSynth(sampleRate: ctx.sampleRate);
    final reverb = Reverb(ctx.sampleRate, roomSize: 0.2, decay: 0.3);
    final dt = 1 / ctx.sampleRate;

    final beatSamples = (60 / ctx.bpm * ctx.sampleRate).round();
    final leadPattern = [
      scale[0], scale[2], scale[4], scale[2],
      scale[5], scale[4], scale[2], scale[0],
      scale[3], scale[5], scale[7], scale[5],
      scale[4], scale[2], scale[0], scale[2],
    ];
    final bassNotes = [scale[0] / 4, scale[0] / 4, scale[3] / 4, scale[3] / 4];

    final sections = _splitSections(ctx.durationSeconds);

    for (var i = 0; i < out.length; i++) {
      final t = i * dt;
      final section = _sectionAt(t, sections);
      final beatIdx = (i ~/ beatSamples) % leadPattern.length;
      final notePos = ((i % beatSamples) / beatSamples).clamp(0.0, 1.0);

      double s = 0;

      // Lead（仅主歌/副歌）
      if (section.name != 'intro' && section.name != 'outro') {
        final noteFreq = leadPattern[beatIdx];
        final env = Envelope(
            attack: 0.005, decay: 0.05, sustain: 0.6, release: 0.1);
        final amp = env.ampAt(notePos * 0.5, 0.5);
        final cutoff = 800 + 1500 * (1 - notePos);
        final lp = LowPassFilter(cutoff: cutoff);
        final saw = 2 * ((t * noteFreq) % 1) - 1;
        s += lp.process(saw, dt: dt) * amp * 0.15;
      }

      // Bass（始终）
      final bassFreq = bassNotes[beatIdx % bassNotes.length];
      final bassEnv =
          Envelope(attack: 0.001, decay: 0.05, sustain: 0.7, release: 0.1);
      final bAmp = bassEnv.ampAt(notePos * 0.25, 0.25);
      final bLp = LowPassFilter(cutoff: 300);
      final square = math.sin(2 * math.pi * bassFreq * t) > 0 ? 1.0 : -1.0;
      s += bLp.process(square, dt: dt) * bAmp * 0.18;

      // 鼓组（除前奏）
      if (section.name != 'intro') {
        s += drum.kick(t, beatSamples, beatIdx);
        s += drum.snare(t, beatSamples, beatIdx);
        s += drum.hihat(t, beatSamples, beatIdx);
      }

      out[i] = reverb.process(s);
      rand; // 防止警告
    }
  }

  /// 古典：钢琴音色 + 弦乐 pad + 真实和弦进行
  void _composeClassical(_ComposeContext ctx, Float64List out) {
    final reverb = Reverb(ctx.sampleRate, roomSize: 0.7, decay: 0.8);
    final scale = _scaleFreqs(ctx.rootNote, 'major', base: 'octave3');
    final progression = [
      [scale[0], scale[2], scale[4]],
      [scale[3], scale[5], scale[0] * 2],
      [scale[4], scale[6], scale[1] * 2],
      [scale[0], scale[2], scale[4]],
    ];

    final chordSamples = (ctx.sampleRate * 4).round();
    final dt = 1 / ctx.sampleRate;

    for (var i = 0; i < out.length; i++) {
      final t = i * dt;
      final chordIdx = (i ~/ chordSamples) % progression.length;
      final chord = progression[chordIdx];
      final phase = (i % chordSamples) / chordSamples;

      double s = 0;
      final pianoEnv =
          Envelope(attack: 0.005, decay: 0.5, sustain: 0.0, release: 0.5);
      final pAmp = pianoEnv.ampAt(phase, 1.0);

      for (final f in chord) {
        final lp = LowPassFilter(cutoff: 2500);
        final fundamental = math.sin(2 * math.pi * f * t);
        final harmonic = 0.3 * math.sin(2 * math.pi * f * 2 * t);
        final harmonic2 = 0.1 * math.sin(2 * math.pi * f * 3 * t);
        // 噪声起音（琴锤敲击瞬间）
        final click = (math.Random().nextDouble() * 2 - 1) *
            math.exp(-50 * phase) *
            (phase < 0.05 ? 1 : 0);
        final tone = lp.process(
          fundamental + harmonic + harmonic2 + click * 0.5,
          dt: dt,
        );
        s += tone * pAmp * 0.2;
      }

      // 弦乐 pad
      for (final f in chord) {
        final padEnv = 0.12 * (0.7 + 0.3 * math.sin(math.pi * phase));
        s += padEnv * math.sin(2 * math.pi * f * t) * 0.4;
      }

      out[i] = reverb.process(s);
    }
  }

  /// Lo-Fi：温暖钢琴 + 简单鼓组 + 噪声纹理
  void _composeLofi(_ComposeContext ctx, Float64List out) {
    final rand = math.Random(ctx.seed);
    final drum = DrumSynth(sampleRate: ctx.sampleRate);
    final reverb = Reverb(ctx.sampleRate, roomSize: 0.3, decay: 0.4);
    final scale = _scaleFreqs(ctx.rootNote, 'major', base: 'octave3');

    final melody = [
      scale[0], scale[2], scale[4], scale[5],
      scale[4], scale[2], scale[0], scale[2],
    ];
    final noteSamples = (ctx.sampleRate * 0.5).round();
    final beatSamples = (60 / ctx.bpm * ctx.sampleRate).round();
    final dt = 1 / ctx.sampleRate;

    for (var i = 0; i < out.length; i++) {
      final t = i * dt;
      final noteIdx = (i ~/ noteSamples) % melody.length;
      final noteFreq = melody[noteIdx];

      double s = 0;

      // 钢琴旋律（温暖）
      final pos = (i % noteSamples) / noteSamples;
      final env = Envelope(attack: 0.005, decay: 0.3, sustain: 0.1, release: 0.2);
      final amp = env.ampAt(pos, 1.0);
      final lp = LowPassFilter(cutoff: 1800);
      // 三角波 + 噪声 → 温暖钢琴音色
      final tri = (2 / math.pi) * math.asin(math.sin(2 * math.pi * noteFreq * t));
      final noise = (rand.nextDouble() * 2 - 1) * 0.05 * math.exp(-20 * pos);
      final tone = lp.process(tri + noise, dt: dt);
      s += tone * amp * 0.25;

      // 鼓组（轻）
      final beatIdx = (i ~/ beatSamples);
      s += drum.kick(t, beatSamples, beatIdx) * 0.6;
      s += drum.snare(t, beatSamples, beatIdx) * 0.4;
      s += drum.hihat(t, beatSamples * 2, beatIdx) * 0.3;

      // 噪声纹理（Lo-Fi 标志"嘶嘶"）
      s += (rand.nextDouble() * 2 - 1) * 0.015;

      out[i] = reverb.process(s);
    }
  }

  /// 打击：鼓组为主 + 简单旋律
  void _composePercussion(_ComposeContext ctx, Float64List out) {
    final drum = DrumSynth(sampleRate: ctx.sampleRate);
    final scale = _scaleFreqs(ctx.rootNote, 'minor', base: 'octave3');
    final melody = [
      scale[0], scale[2], scale[4], scale[5], scale[4], scale[2]
    ];
    final beatSamples = (60 / ctx.bpm * ctx.sampleRate).round();
    final noteSamples = beatSamples * 2;
    final dt = 1 / ctx.sampleRate;

    for (var i = 0; i < out.length; i++) {
      final t = i * dt;
      final beatIdx = (i ~/ beatSamples) % 4;

      double s = 0;

      // 鼓组
      s += drum.kick(t, beatSamples, beatIdx) * 0.9;
      s += drum.snare(t, beatSamples, beatIdx) * 0.7;
      s += drum.hihat(t, beatSamples ~/ 2, beatIdx);
      s += drum.openHat(t, beatSamples, beatIdx) * 0.3;

      // 旋律（弱）
      final noteIdx = (i ~/ noteSamples) % melody.length;
      final noteFreq = melody[noteIdx];
      final pos = (i % noteSamples) / noteSamples;
      final env = Envelope(attack: 0.005, decay: 0.1, sustain: 0.3, release: 0.2);
      final amp = env.ampAt(pos, 1.0);
      final lp = LowPassFilter(cutoff: 1500);
      final tone =
          lp.process(math.sin(2 * math.pi * noteFreq * t), dt: dt);
      s += tone * amp * 0.1;

      out[i] = s * 0.7;
    }
  }

  /// Drone：长持续音 + 缓慢滤波调制
  void _composeDrone(_ComposeContext ctx, Float64List out) {
    final reverb = Reverb(ctx.sampleRate, roomSize: 0.8, decay: 0.9);
    final scale = _scaleFreqs(ctx.rootNote, 'minor', base: 'octave1');
    final dt = 1 / ctx.sampleRate;

    for (var i = 0; i < out.length; i++) {
      final t = i * dt;

      double s = 0;
      for (var n = 0; n < 4; n++) {
        final f = scale[n];
        final amp = 0.08 +
            0.06 *
                math.sin(
                    2 * math.pi * (0.05 + n * 0.02) * t + n.toDouble());
        final cutoff = 400 + 300 * math.sin(2 * math.pi * 0.03 * t + n.toDouble());
        final lp = LowPassFilter(cutoff: cutoff);
        final sample = lp.process(math.sin(2 * math.pi * f * t), dt: dt);
        s += amp * sample;
      }

      // 微颤
      s += 0.04 *
          math.sin(2 * math.pi * 330 * t) *
          math.sin(2 * math.pi * 0.3 * t);

      out[i] = reverb.process(s);
    }
  }

  // ──────────── 音乐理论 ────────────

  /// 大调 / 小调音阶频率（基于 root note 0-11）
  /// base: octave1/2/3 决定音域
  List<double> _scaleFreqs(int root, String mode, {String base = 'octave3'}) {
    // 大调音阶半音：[0, 2, 4, 5, 7, 9, 11]
    // 小调音阶半音：[0, 2, 3, 5, 7, 8, 10]
    final intervals = mode == 'minor'
        ? [0, 2, 3, 5, 7, 8, 10]
        : [0, 2, 4, 5, 7, 9, 11];

    final baseFreq = base == 'octave1'
        ? 65.41
        : base == 'octave2'
            ? 130.81
            : 261.63;
    // root 0 = C4 = 261.63Hz
    final rootFreq = baseFreq * math.pow(2, root / 12);

    return intervals.map((i) {
      final f = rootFreq * math.pow(2, i / 12);
      return f.toDouble();
    }).toList();
  }

  /// I-V-vi-IV 进行（流行/电子常用）
  List<List<double>> _progressAm(List<double> scale) {
    return [
      [scale[0], scale[2], scale[4]],
      [scale[4], scale[6] * 2 / 1.5, scale[1] * 2],
      [scale[5], scale[0] * 2, scale[2] * 2],
      [scale[3], scale[5], scale[0] * 2],
    ];
  }

  int _pickBpm(AiGenre genre) {
    switch (genre) {
      case AiGenre.ambient:
        return 60;
      case AiGenre.electronic:
        return 128;
      case AiGenre.classical:
        return 80;
      case AiGenre.lofi:
        return 88;
      case AiGenre.percussion:
        return 100;
      case AiGenre.drone:
        return 50;
    }
  }

  /// 音乐结构（前奏 / 主歌 / 副歌 / 主歌 / 副歌 / 尾奏）
  List<_Section> _splitSections(int duration) {
    final intro = (duration * 0.1).round();
    final outro = (duration * 0.1).round();
    final middle = duration - intro - outro;
    final verseA = (middle * 0.3).round();
    final chorus = (middle * 0.2).round();
    final verseB = (middle * 0.3).round();
    final chorus2 = middle - verseA - chorus - verseB;

    return [
      _Section('intro', intro),
      _Section('verseA', verseA),
      _Section('chorus', chorus),
      _Section('verseB', verseB),
      _Section('chorus', chorus2),
      _Section('outro', outro),
    ];
  }

  _Section _sectionAt(double t, List<_Section> sections) {
    var cur = 0.0;
    for (final s in sections) {
      if (t < cur + s.seconds) return s;
      cur += s.seconds;
    }
    return sections.last;
  }

  // ──────────── 音频效果 ────────────

  void _softCompress(Float64List samples,
      {double threshold = 0.7, double ratio = 4.0}) {
    for (var i = 0; i < samples.length; i++) {
      final x = samples[i].abs();
      if (x > threshold) {
        final over = x - threshold;
        final compressed = threshold + over / ratio;
        samples[i] = samples[i].sign * compressed;
      }
    }
  }

  void _limit(Float64List samples, {double ceiling = 0.95}) {
    for (var i = 0; i < samples.length; i++) {
      samples[i] = samples[i].clamp(-ceiling, ceiling);
    }
  }

  // ──────────── WAV 编码 ────────────

  Uint8List _wrapWav(Float64List samples) {
    final pcm = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      pcm[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
    }

    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final dataSize = pcm.lengthInBytes;
    final fileSize = 36 + dataSize;

    final builder = BytesBuilder();
    builder.add(_ascii('RIFF'));
    builder.add(_uint32LE(fileSize));
    builder.add(_ascii('WAVE'));
    builder.add(_ascii('fmt '));
    builder.add(_uint32LE(16));
    builder.add(_uint16LE(1));
    builder.add(_uint16LE(numChannels));
    builder.add(_uint32LE(sampleRate));
    builder.add(_uint32LE(byteRate));
    builder.add(_uint16LE(numChannels * (bitsPerSample ~/ 8)));
    builder.add(_uint16LE(bitsPerSample));
    builder.add(_ascii('data'));
    builder.add(_uint32LE(dataSize));
    final pcmBytes = Uint8List(dataSize);
    final view = ByteData.view(pcmBytes.buffer);
    for (var i = 0; i < pcm.length; i++) {
      view.setInt16(i * 2, pcm[i], Endian.little);
    }
    builder.add(pcmBytes);
    return builder.toBytes();
  }

  List<int> _ascii(String s) => s.codeUnits;

  List<int> _uint16LE(int v) {
    final b = ByteData(2)..setUint16(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  List<int> _uint32LE(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  Future<String> _writeFile(
      String prompt, AiGenre genre, Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ai_generated'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final safePrompt = prompt.isEmpty
        ? 'no_prompt'
        : prompt
            .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5]'), '')
            .substring(0, prompt.length.clamp(0, 8));
    final file =
        File(p.join(dir.path, '${genre.name}_${safePrompt}_$ts.wav'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

// ════════════════════════════════════════════════════════════
// 合成器原语（独立类）
// ════════════════════════════════════════════════════════════

class _ComposeContext {
  final int sampleRate;
  final int seed;
  final int durationSeconds;
  final String prompt;
  int rootNote = 0;
  int bpm = 120;
  _ComposeContext({
    required this.sampleRate,
    required this.seed,
    required this.durationSeconds,
    required this.prompt,
  });
}

class _Section {
  final String name;
  final int seconds;
  const _Section(this.name, this.seconds);
}

/// ADSR 包络（攻击-衰减-延音-释放）
class Envelope {
  final double attack;
  final double decay;
  final double sustain;
  final double release;
  Envelope({
    this.attack = 0.01,
    this.decay = 0.1,
    this.sustain = 0.7,
    this.release = 0.3,
  });

  double ampAt(double t, double noteDur) {
    if (t < 0) return 0;
    if (t < attack) return t / attack;
    if (t < attack + decay) {
      final d = (t - attack) / decay;
      return 1 - (1 - sustain) * d;
    }
    if (t < noteDur) return sustain;
    final r = (t - noteDur) / release;
    return sustain * (1 - r.clamp(0.0, 1.0));
  }
}

/// 一阶低通滤波器（模拟乐器音色截止频率）
class LowPassFilter {
  double cutoff;
  double _prev = 0;
  LowPassFilter({required this.cutoff});
  double process(double x, {required double dt}) {
    final rc = 1.0 / (2 * math.pi * cutoff);
    final alpha = dt / (rc + dt);
    _prev = _prev + alpha * (x - _prev);
    return _prev;
  }
}

/// 简易混响（基于 Schroeder 延迟线）
class Reverb {
  final List<List<double>> _buffers;
  final List<int> _indices;
  final List<double> _gains;

  Reverb(int sampleRate, {double roomSize = 0.5, double decay = 0.5})
      : _buffers = [],
        _indices = [],
        _gains = [] {
    final delaysMs = [
      29 * (0.5 + roomSize),
      41 * (0.5 + roomSize),
      73 * (0.5 + roomSize),
      97 * (0.5 + roomSize),
    ];
    for (final ms in delaysMs) {
      _buffers.add(List.filled((ms * sampleRate / 1000).round(), 0));
      _indices.add(0);
      _gains.add(decay * 0.3);
    }
  }

  double process(double x) {
    var out = x;
    for (var i = 0; i < _buffers.length; i++) {
      final idx = _indices[i];
      _buffers[i][idx] = x;
      _indices[i] = (idx + 1) % _buffers[i].length;
      out += _buffers[i][idx] * _gains[i];
    }
    return out * 0.4;
  }
}

/// 鼓组合成器（Kick / Snare / HiHat / Open Hat）
class DrumSynth {
  final int sampleRate;
  final math.Random _rand;
  DrumSynth({required this.sampleRate, int seed = 42})
      : _rand = math.Random(seed);

  /// 大鼓：低频 sine sweep + 包络
  double kick(double t, int beatSamples, int beatIdx) {
    if (beatIdx % 4 != 0) return 0;
    final beatPos = (t * sampleRate) % beatSamples;
    final phase = beatPos / beatSamples;
    if (phase > 0.15) return 0;
    final freq = 150 * math.exp(-15 * phase) + 50;
    final env = math.exp(-12 * phase);
    final click = (phase < 0.005) ? math.sin(2 * math.pi * 1500 * t) * 0.5 : 0;
    return math.sin(2 * math.pi * freq * t) * env * 0.6 + click * math.exp(-100 * phase);
  }

  /// 小鼓：噪声 + 低频 tone
  double snare(double t, int beatSamples, int beatIdx) {
    if (beatIdx % 4 != 2) return 0;
    final beatPos = (t * sampleRate) % beatSamples;
    final phase = beatPos / beatSamples;
    if (phase > 0.2) return 0;
    final noise = (_rand.nextDouble() * 2 - 1) * 0.8;
    final tone = math.sin(2 * math.pi * 200 * t) * 0.3;
    final env = math.exp(-15 * phase);
    return (noise + tone) * env * 0.4;
  }

  /// 踩镲（闭）
  double hihat(double t, int beatSamples, int beatIdx) {
    final beatPos = (t * sampleRate) % beatSamples;
    final phase = beatPos / beatSamples;
    if (phase > 0.05) return 0;
    final noise = (_rand.nextDouble() * 2 - 1);
    final env = math.exp(-50 * phase);
    return noise * env * 0.15;
  }

  /// 开镲
  double openHat(double t, int beatSamples, int beatIdx) {
    if (beatIdx % 4 != 3) return 0;
    final beatPos = (t * sampleRate) % beatSamples;
    final phase = beatPos / beatSamples;
    if (phase > 0.3) return 0;
    final noise = (_rand.nextDouble() * 2 - 1);
    final env = math.exp(-8 * phase);
    return noise * env * 0.12;
  }
}