import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// The bell on the meditation timer.
///
/// A silent timer has one real flaw: you have to keep looking at it. Someone
/// sitting with their eyes closed cannot tell whether the session started, and
/// certainly cannot tell when it ended — which is the entire reason they set a
/// timer rather than a mental note. A tone at each edge is what makes the clock
/// usable without watching it.
///
/// The tones are synthesised rather than shipped as audio files. A bundled mp3
/// would add weight to the APK, need a licence, and be one more asset that can
/// go missing from a release build; a sine wave with a soft envelope is a few
/// lines of arithmetic and always sounds the same. Each tone is rendered once,
/// written to the cache directory as a WAV, and replayed from there.
///
/// Nothing here is ever allowed to throw into the caller. A device with no
/// audio route, a denied file write, or a busy player must not be able to stop
/// a meditation session from starting — so every failure falls back to haptics
/// and a system click, which is still a perceptible cue.
class ChimeService {
  ChimeService._();
  static final ChimeService instance = ChimeService._();

  static const int _sampleRate = 44100;

  final _players = <String, AudioPlayer>{};
  final _paths = <String, String>{};

  /// Session start: a single clear note, struck and left to ring.
  Future<void> start() => _play('start', const [_Note(660, 0.55)]);

  /// Session end: three descending notes, the way a bowl is used to close a
  /// sitting. Unmistakably different from the opening note, because the whole
  /// point is knowing which one you just heard.
  Future<void> end() => _play('end', const [
        _Note(660, 0.45),
        _Note(550, 0.45, delay: 0.38),
        _Note(440, 0.9, delay: 0.76),
      ]);

  /// Paused, or stopped early: one low, short tone. Quieter than the others —
  /// it is an acknowledgement, not an announcement.
  Future<void> pause() => _play('pause', const [_Note(392, 0.28, gain: 0.55)]);

  /// Warms the cache so the first tone of a session is not delayed by having
  /// to render and write a file. Safe to call more than once.
  Future<void> prepare() async {
    await Future.wait([
      _file('start', const [_Note(660, 0.55)]),
      _file('end', const [
        _Note(660, 0.45),
        _Note(550, 0.45, delay: 0.38),
        _Note(440, 0.9, delay: 0.76),
      ]),
    ]).catchError((_) => <String>[]);
  }

  Future<void> _play(String key, List<_Note> notes) async {
    // The cue people actually feel first, and the one that survives a silent
    // switch or a dead speaker.
    unawaited(HapticFeedback.mediumImpact());

    try {
      final path = await _file(key, notes);
      final player = _players.putIfAbsent(key, AudioPlayer.new);
      if (player.audioSource == null) {
        await player.setFilePath(path);
      }
      await player.seek(Duration.zero);
      // Deliberately not awaited: the tone rings for up to two seconds and the
      // timer must start on the same frame the button was pressed.
      unawaited(player.play());
    } catch (e) {
      debugPrint('⚠️ Chime unavailable, falling back to system sound: $e');
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  Future<String> _file(String key, List<_Note> notes) async {
    final cached = _paths[key];
    if (cached != null && File(cached).existsSync()) return cached;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/brahma_chime_$key.wav');
    if (!file.existsSync()) {
      await file.writeAsBytes(_wav(_render(notes)), flush: true);
    }
    _paths[key] = file.path;
    return file.path;
  }

  /// Sums the notes into one buffer of 16-bit samples.
  ///
  /// Each note carries a short attack and a long exponential decay. Without the
  /// attack the waveform starts at full amplitude and the speaker produces an
  /// audible click before the tone; without the decay it ends in one, which is
  /// the opposite of calming.
  Int16List _render(List<_Note> notes) {
    final totalSeconds = notes
        .map((n) => n.delay + n.seconds)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final samples = Int16List((totalSeconds * _sampleRate).ceil());

    for (final note in notes) {
      final offset = (note.delay * _sampleRate).round();
      final length = (note.seconds * _sampleRate).round();
      const attack = 0.012; // seconds

      for (var i = 0; i < length; i++) {
        final index = offset + i;
        if (index >= samples.length) break;

        final t = i / _sampleRate;
        final rise = t < attack ? t / attack : 1.0;
        final fall = exp(-3.2 * t / note.seconds);

        // A quiet octave above the fundamental: a pure sine reads as a test
        // tone, while a touch of the harmonic reads as a struck bell.
        final wave = sin(2 * pi * note.hz * t) +
            0.22 * sin(4 * pi * note.hz * t);

        final value = wave * 0.42 * note.gain * rise * fall;
        final mixed = samples[index] + (value * 32767).round();
        samples[index] = mixed.clamp(-32768, 32767).toInt();
      }
    }
    return samples;
  }

  /// Wraps PCM samples in a 44-byte canonical WAV header: mono, 16-bit,
  /// 44.1 kHz.
  Uint8List _wav(Int16List samples) {
    final dataBytes = samples.lengthInBytes;
    final out = BytesBuilder();
    final header = ByteData(44);

    void ascii(int offset, String tag) {
      for (var i = 0; i < tag.length; i++) {
        header.setUint8(offset + i, tag.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // PCM header size
    header.setUint16(20, 1, Endian.little); // format: PCM
    header.setUint16(22, 1, Endian.little); // channels: mono
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    header.setUint32(40, dataBytes, Endian.little);

    out.add(header.buffer.asUint8List());
    out.add(samples.buffer.asUint8List(0, dataBytes));
    return out.toBytes();
  }

  Future<void> disposeAll() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}

class _Note {
  final double hz;
  final double seconds;

  /// Seconds after the start of the sound before this note is struck.
  final double delay;

  final double gain;

  const _Note(this.hz, this.seconds, {this.delay = 0, this.gain = 1});
}
