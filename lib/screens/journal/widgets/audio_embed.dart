import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../../../services/journal_audio_storage_service.dart';

/// Custom embed builder for rendering voice notes inline in the Quill editor.
/// Audio embeds use the custom type 'audio' and store the file path as data.
class JournalAudioEmbedBuilder extends quill.EmbedBuilder {
  final void Function(String audioPath)? onAudioDeleted;

  JournalAudioEmbedBuilder({this.onAudioDeleted});

  @override
  String get key => 'audio';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final audioPath = embedContext.node.value.data as String;
    final isReadOnly = embedContext.readOnly;

    return _InlineAudioPlayer(
      audioPath: audioPath,
      isReadOnly: isReadOnly,
      onDelete: isReadOnly
          ? null
          : () {
              final offset = embedContext.node.documentOffset;
              embedContext.controller.replaceText(offset, 1, '', null);
              onAudioDeleted?.call(audioPath);
            },
    );
  }
}

/// Compact inline audio player widget with neumorphic styling.
class _InlineAudioPlayer extends StatefulWidget {
  final String audioPath;
  final bool isReadOnly;
  final VoidCallback? onDelete;

  const _InlineAudioPlayer({
    required this.audioPath,
    this.isReadOnly = false,
    this.onDelete,
  });

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    // Pre-load to get duration
    try {
      final file = File(widget.audioPath);
      if (await file.exists()) {
        await _player.setSourceDeviceFile(widget.audioPath);
        _isLoaded = true;
      }
    } catch (_) {
      // File may not exist
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (!_isLoaded) return;
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.play(DeviceFileSource(widget.audioPath));
      }
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: const Offset(-1, -1),
                  blurRadius: 4,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/pause button
              GestureDetector(
                onTap: _togglePlayPause,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? colorScheme.primary
                        : colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isPlaying
                                ? colorScheme.primary
                                : colorScheme.primaryContainer)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: isPlaying
                        ? colorScheme.onPrimary
                        : colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Waveform / progress
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar with waveform visual
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 20,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            progress: progress,
                            activeColor: colorScheme.primary,
                            inactiveColor:
                                colorScheme.outlineVariant.withOpacity(0.4),
                            barCount: 30,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Duration text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Voice note icon
              const SizedBox(width: 8),
              Icon(
                Icons.mic_rounded,
                size: 16,
                color: colorScheme.primary.withOpacity(0.6),
              ),
              // Delete button (edit mode only)
              if (!widget.isReadOnly && widget.onDelete != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a waveform-style progress visualization.
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int barCount;

  _WaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.barCount = 30,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (barCount * 2 - 1);
    final activePaint = Paint()..color = activeColor;
    final inactivePaint = Paint()..color = inactiveColor;
    final rng = math.Random(42); // Fixed seed for consistent waveform

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth * 2;
      // Generate pseudo-random heights for waveform look
      final heightFactor = 0.3 + rng.nextDouble() * 0.7;
      final barHeight = size.height * heightFactor;
      final y = (size.height - barHeight) / 2;

      final isActive = (i / barCount) <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Voice recording bottom sheet with record/stop/save controls.
class VoiceRecorderSheet extends StatefulWidget {
  final String entryId;
  final void Function(String audioPath) onRecordingComplete;

  const VoiceRecorderSheet({
    required this.entryId,
    required this.onRecordingComplete,
  });

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }

      final path = await JournalAudioStorageService.generateRecordingPath(
        widget.entryId,
      );

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _hasRecording = false;
        _recordingPath = path;
        _recordingDuration = Duration.zero;
      });

      _pulseController.repeat(reverse: true);

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      _durationTimer?.cancel();
      _pulseController.stop();
      _pulseController.reset();

      if (path != null) {
        setState(() {
          _isRecording = false;
          _hasRecording = true;
          _recordingPath = path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
    }
  }

  void _cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _durationTimer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
    }
    // Delete the file if it was created
    if (_recordingPath != null) {
      await JournalAudioStorageService.deleteAudio(_recordingPath!);
    }
    if (mounted) Navigator.pop(context);
  }

  void _saveRecording() {
    if (_recordingPath != null && _hasRecording) {
      widget.onRecordingComplete(_recordingPath!);
    }
    Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Text(
                _isRecording
                    ? 'Recording...'
                    : _hasRecording
                        ? 'Recording Complete'
                        : 'Voice Note',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              // Duration display
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? colorScheme.errorContainer.withOpacity(
                              0.3 + _pulseController.value * 0.3)
                          : _hasRecording
                              ? colorScheme.primaryContainer
                              : isDark
                                  ? colorScheme.surfaceContainerHighest
                                  : colorScheme.surfaceContainerLowest,
                      border: Border.all(
                        color: _isRecording
                            ? colorScheme.error.withOpacity(0.5)
                            : colorScheme.outlineVariant.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        if (_isRecording)
                          BoxShadow(
                            color: colorScheme.error.withOpacity(
                                0.1 + _pulseController.value * 0.15),
                            blurRadius: 20 + _pulseController.value * 10,
                            spreadRadius: _pulseController.value * 5,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording
                              ? Icons.mic_rounded
                              : _hasRecording
                                  ? Icons.check_circle_rounded
                                  : Icons.mic_none_rounded,
                          size: 36,
                          color: _isRecording
                              ? colorScheme.error
                              : _hasRecording
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isRecording
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // Action buttons
              if (!_isRecording && !_hasRecording)
                // Initial state - start recording
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(
                        'Start Recording',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_isRecording)
                // Recording state - stop
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _cancelRecording,
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(
                        'Stop',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Has recording - save or re-record
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _cancelRecording,
                      child: Text(
                        'Discard',
                        style: GoogleFonts.inter(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Re-record',
                        style: GoogleFonts.inter(),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _saveRecording,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        'Save',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
