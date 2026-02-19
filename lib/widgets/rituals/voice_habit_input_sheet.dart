import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/voice_habit_parser_service.dart';
import '../../utils/app_typography.dart';

/// Shows a modal bottom sheet that records voice, transcribes it, then sends
/// it to the parser service. Returns [ParsedHabitData] or null on cancel.
Future<ParsedHabitData?> showVoiceHabitInputSheet(BuildContext context) {
  return showModalBottomSheet<ParsedHabitData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceHabitInputSheet(),
  );
}

// =============================================================================
// Sheet widget
// =============================================================================

class _VoiceHabitInputSheet extends StatefulWidget {
  const _VoiceHabitInputSheet();

  @override
  State<_VoiceHabitInputSheet> createState() => _VoiceHabitInputSheetState();
}

enum _SheetPhase { idle, listening, processing, done, error }

class _VoiceHabitInputSheetState extends State<_VoiceHabitInputSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  _SheetPhase _phase = _SheetPhase.idle;
  String _transcribedText = '';
  String _liveWords = '';
  String? _errorMessage;
  ParsedHabitData? _result;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        if (error.errorMsg == 'error_no_match' && _transcribedText.isNotEmpty) {
          _onDone();
          return;
        }
        setState(() {
          _phase = _SheetPhase.error;
          _errorMessage = _friendlyError(error.errorMsg);
        });
        _pulseController.stop();
      },
      onStatus: (status) {
        if (status == 'notListening' &&
            _phase == _SheetPhase.listening &&
            _transcribedText.isNotEmpty) {
          _onDone();
        }
      },
    );
    if (mounted) setState(() {});
  }

  String _friendlyError(String raw) {
    if (raw.contains('permission') || raw.contains('not_allowed')) {
      return 'Microphone permission is required. Please allow it in Settings.';
    }
    if (raw.contains('no_match') || raw.contains('speech_timeout')) {
      return 'Could not understand. Please try again.';
    }
    if (raw.contains('network')) {
      return 'Network error. Check your connection and retry.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _startListening() {
    if (!_speechAvailable) {
      setState(() {
        _phase = _SheetPhase.error;
        _errorMessage = 'Speech recognition is not available on this device.';
      });
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _SheetPhase.listening;
      _transcribedText = '';
      _liveWords = '';
      _errorMessage = null;
    });
    _pulseController.repeat(reverse: true);
    _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _liveWords = result.recognizedWords;
          if (result.finalResult) {
            _transcribedText = result.recognizedWords;
          }
        });
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    _pulseController.stop();
    if (_liveWords.isNotEmpty) {
      _transcribedText = _liveWords;
    }
    if (_transcribedText.isNotEmpty) {
      _onDone();
    } else {
      setState(() => _phase = _SheetPhase.idle);
    }
  }

  Future<void> _onDone() async {
    if (_phase == _SheetPhase.processing || _phase == _SheetPhase.done) return;
    _pulseController.stop();
    setState(() => _phase = _SheetPhase.processing);
    try {
      final parsed = await VoiceHabitParserService.parse(_transcribedText);
      if (!mounted) return;
      if (parsed.isEmpty) {
        setState(() {
          _phase = _SheetPhase.error;
          _errorMessage =
              'Could not extract habit details. Try being more specific.';
        });
      } else {
        setState(() {
          _result = parsed;
          _phase = _SheetPhase.done;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _SheetPhase.error;
        _errorMessage = 'Failed to parse your input. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, math.max(bottomPad, 24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Create Habit by Voice',
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Try saying: "Create a habit of walking daily '
            'for 10 mins at 6am after brushing my teeth. '
            'If too tired I\'ll walk 2 mins."',
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Transcription area
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildTranscriptionContent(colorScheme),
            ),
          ),
          const SizedBox(height: 24),

          // Mic button
          _buildMicButton(colorScheme),
          const SizedBox(height: 20),

          // Action buttons
          _buildActionButtons(colorScheme),
        ],
      ),
    );
  }

  Widget _buildTranscriptionContent(ColorScheme colorScheme) {
    switch (_phase) {
      case _SheetPhase.idle:
        return Text(
          'Tap the mic to start speaking',
          textAlign: TextAlign.center,
          style: AppTypography.body(context).copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        );
      case _SheetPhase.listening:
        return Column(
          children: [
            if (_liveWords.isNotEmpty)
              Text(
                _liveWords,
                style: AppTypography.body(context),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'Listening...',
                style: AppTypography.body(context).copyWith(
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        );
      case _SheetPhase.processing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Parsing your habit...',
                style: AppTypography.body(context).copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      case _SheetPhase.done:
        return Column(
          children: [
            Icon(Icons.check_circle_rounded,
                color: colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              _transcribedText,
              style: AppTypography.body(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Habit details extracted! Tap "Apply" to fill the form.',
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case _SheetPhase.error:
        return Column(
          children: [
            Icon(Icons.error_outline_rounded,
                color: colorScheme.error, size: 28),
            const SizedBox(height: 8),
            if (_transcribedText.isNotEmpty) ...[
              Text(
                _transcribedText,
                style: AppTypography.body(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              _errorMessage ?? 'Something went wrong.',
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  Widget _buildMicButton(ColorScheme colorScheme) {
    final isListening = _phase == _SheetPhase.listening;
    final isProcessing = _phase == _SheetPhase.processing;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : isListening
              ? _stopListening
              : _startListening,
      child: _PulseMicButton(
        animation: _pulseAnimation,
        isListening: isListening,
        isProcessing: isProcessing,
        colorScheme: colorScheme,
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ),
        if (_phase == _SheetPhase.done && _result != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop(_result);
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                'Apply',
                style: AppTypography.button(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        if (_phase == _SheetPhase.error) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _phase = _SheetPhase.idle;
                  _transcribedText = '';
                  _liveWords = '';
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PulseMicButton extends AnimatedWidget {
  final bool isListening;
  final bool isProcessing;
  final ColorScheme colorScheme;

  const _PulseMicButton({
    required Animation<double> animation,
    required this.isListening,
    required this.isProcessing,
    required this.colorScheme,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final anim = listenable as Animation<double>;
    final scale = isListening ? anim.value : 1.0;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? colorScheme.error.withValues(alpha: 0.15)
              : colorScheme.primary.withValues(alpha: 0.12),
          border: Border.all(
            color: isListening ? colorScheme.error : colorScheme.primary,
            width: 2.5,
          ),
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          size: 34,
          color: isListening
              ? colorScheme.error
              : isProcessing
                  ? colorScheme.onSurface.withValues(alpha: 0.3)
                  : colorScheme.primary,
        ),
      ),
    );
  }
}
