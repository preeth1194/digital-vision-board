import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Generates and plays short preview tones for notification sound presets.
class SoundPreviewService {
  SoundPreviewService._();

  static AudioPlayer? _player;
  static File? _tempFile;

  static AudioPlayer get _audioPlayer => _player ??= AudioPlayer();

  /// Plays a preview tone for the given sound preset id.
  /// For custom file paths, plays the file directly.
  static Future<void> playPreview(String soundId) async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (soundId == 'none') return;

    // Custom file path (contains '/')
    if (soundId.contains('/')) {
      await _audioPlayer.play(DeviceFileSource(soundId));
      return;
    }

    final params = _paramsForPreset(soundId);
    final bytes = _generateWav(
      frequency: params.frequency,
      durationMs: params.durationMs,
      sampleRate: 44100,
      envelope: params.envelope,
      harmonics: params.harmonics,
    );

    // Write to a temp .wav file so AVPlayer on iOS can handle it
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sound_preview_$soundId.wav');
    await file.writeAsBytes(bytes, flush: true);
    _tempFile = file;

    await _audioPlayer.play(DeviceFileSource(file.path));
  }

  static Future<void> dispose() async {
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    try {
      await _tempFile?.delete();
    } catch (_) {}
    _tempFile = null;
  }

  static _ToneParams _paramsForPreset(String id) {
    switch (id) {
      case 'chime':
        return _ToneParams(
          frequency: 1046.5, // C6
          durationMs: 400,
          envelope: _Envelope.bellCurve,
          harmonics: const [1.0, 0.4, 0.15],
        );
      case 'bell':
        return _ToneParams(
          frequency: 880.0, // A5
          durationMs: 600,
          envelope: _Envelope.decayLong,
          harmonics: const [1.0, 0.6, 0.3, 0.1],
        );
      case 'gentle':
        return _ToneParams(
          frequency: 523.25, // C5
          durationMs: 500,
          envelope: _Envelope.fadeInOut,
          harmonics: const [1.0, 0.2],
        );
      case 'alert':
        return _ToneParams(
          frequency: 1318.5, // E6
          durationMs: 300,
          envelope: _Envelope.sharp,
          harmonics: const [1.0, 0.5, 0.3],
        );
      case 'default':
      default:
        return _ToneParams(
          frequency: 784.0, // G5
          durationMs: 350,
          envelope: _Envelope.decayShort,
          harmonics: const [1.0, 0.3],
        );
    }
  }

  static Uint8List _generateWav({
    required double frequency,
    required int durationMs,
    required int sampleRate,
    required _Envelope envelope,
    required List<double> harmonics,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Float64List(numSamples);
    final twoPi = 2.0 * pi;

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = i / numSamples;
      double sample = 0;

      for (int h = 0; h < harmonics.length; h++) {
        final harmFreq = frequency * (h + 1);
        sample += harmonics[h] * sin(twoPi * harmFreq * t);
      }

      sample *= _envelopeValue(envelope, progress);
      samples[i] = sample.clamp(-1.0, 1.0);
    }

    return _encodeWav(samples, sampleRate);
  }

  static double _envelopeValue(_Envelope env, double progress) {
    switch (env) {
      case _Envelope.decayShort:
        return pow(1.0 - progress, 2.0).toDouble() * 0.7;
      case _Envelope.decayLong:
        return pow(1.0 - progress, 1.2).toDouble() * 0.6;
      case _Envelope.bellCurve:
        final attack = progress < 0.05 ? progress / 0.05 : 1.0;
        final decay = pow(1.0 - progress, 1.5).toDouble();
        return attack * decay * 0.7;
      case _Envelope.fadeInOut:
        if (progress < 0.15) return (progress / 0.15) * 0.5;
        if (progress > 0.7) return ((1.0 - progress) / 0.3) * 0.5;
        return 0.5;
      case _Envelope.sharp:
        final attack = progress < 0.02 ? progress / 0.02 : 1.0;
        final decay = pow(1.0 - progress, 3.0).toDouble();
        return attack * decay * 0.8;
    }
  }

  /// Encodes PCM float64 samples as a 16-bit mono WAV.
  static Uint8List _encodeWav(Float64List samples, int sampleRate) {
    const bitsPerSample = 16;
    const numChannels = 1;
    final bytesPerSample = bitsPerSample ~/ 8;
    final dataSize = samples.length * bytesPerSample;
    final fileSize = 44 + dataSize;

    final buffer = ByteData(fileSize);
    int offset = 0;

    void writeStr(String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset++, s.codeUnitAt(i));
      }
    }

    void writeU32(int v) {
      buffer.setUint32(offset, v, Endian.little);
      offset += 4;
    }

    void writeU16(int v) {
      buffer.setUint16(offset, v, Endian.little);
      offset += 2;
    }

    // RIFF header
    writeStr('RIFF');
    writeU32(fileSize - 8);
    writeStr('WAVE');

    // fmt sub-chunk
    writeStr('fmt ');
    writeU32(16); // sub-chunk size
    writeU16(1); // PCM
    writeU16(numChannels);
    writeU32(sampleRate);
    writeU32(sampleRate * numChannels * bytesPerSample); // byte rate
    writeU16(numChannels * bytesPerSample); // block align
    writeU16(bitsPerSample);

    // data sub-chunk
    writeStr('data');
    writeU32(dataSize);

    for (int i = 0; i < samples.length; i++) {
      final clamped = (samples[i] * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, clamped, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}

class _ToneParams {
  final double frequency;
  final int durationMs;
  final _Envelope envelope;
  final List<double> harmonics;

  const _ToneParams({
    required this.frequency,
    required this.durationMs,
    required this.envelope,
    required this.harmonics,
  });
}

enum _Envelope {
  decayShort,
  decayLong,
  bellCurve,
  fadeInOut,
  sharp,
}
