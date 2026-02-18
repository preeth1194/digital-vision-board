import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/habit_item.dart';
import '../../services/coins_service.dart';
import '../../utils/app_colors.dart';
import '../../screens/journal/widgets/audio_embed.dart';
import '../../services/journal_audio_storage_service.dart';
import '../grid/image_source_sheet.dart';

/// Result from the habit completion sheet.
class HabitCompletionResult {
  final int coinsEarned;
  final int? mood;
  final String? note;
  final List<String> completedStepIds;
  final String? audioPath;
  final List<String> imagePaths;

  const HabitCompletionResult({
    required this.coinsEarned,
    this.mood,
    this.note,
    this.completedStepIds = const [],
    this.audioPath,
    this.imagePaths = const [],
  });
}

/// Shows a bottom sheet for completing a habit with optional mood and log.
Future<HabitCompletionResult?> showHabitCompletionSheet(
  BuildContext context, {
  required HabitItem habit,
  required int baseCoins,
  bool isFullHabit = true,
}) {
  return showModalBottomSheet<HabitCompletionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HabitCompletionSheet(
      habit: habit,
      baseCoins: baseCoins,
      isFullHabit: isFullHabit,
    ),
  );
}

/// Mood option data.
class _MoodOption {
  final int value;
  final IconData icon;
  final String label;
  final Color color;

  const _MoodOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.color,
  });
}

const _moods = <_MoodOption>[
  _MoodOption(
    value: 1,
    icon: Icons.sentiment_very_dissatisfied_rounded,
    label: 'Awful',
    color: AppColors.moodAwful,
  ),
  _MoodOption(
    value: 2,
    icon: Icons.sentiment_dissatisfied_rounded,
    label: 'Bad',
    color: AppColors.moodBad,
  ),
  _MoodOption(
    value: 3,
    icon: Icons.sentiment_neutral_rounded,
    label: 'Neutral',
    color: AppColors.moodNeutral,
  ),
  _MoodOption(
    value: 4,
    icon: Icons.sentiment_satisfied_rounded,
    label: 'Good',
    color: AppColors.moodGood,
  ),
  _MoodOption(
    value: 5,
    icon: Icons.sentiment_very_satisfied_rounded,
    label: 'Great',
    color: AppColors.moodGreat,
  ),
];

class _HabitCompletionSheet extends StatefulWidget {
  final HabitItem habit;
  final int baseCoins;
  final bool isFullHabit;

  const _HabitCompletionSheet({
    required this.habit,
    required this.baseCoins,
    required this.isFullHabit,
  });

  @override
  State<_HabitCompletionSheet> createState() => _HabitCompletionSheetState();
}

class _HabitCompletionSheetState extends State<_HabitCompletionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int? _selectedMood;
  final TextEditingController _noteController = TextEditingController();
  final Set<String> _completedStepIds = {};
  String? _audioPath;
  final List<String> _imagePaths = [];

  bool get _showSteps =>
      widget.isFullHabit && widget.habit.actionSteps.isNotEmpty;

  int get _totalCoins {
    final stepBonus = CoinsService.calculateStepBonus(
      _completedStepIds.length,
      widget.habit.actionSteps.length,
    );
    final hasMedia = _audioPath != null || _imagePaths.isNotEmpty;
    final mediaBonus = CoinsService.calculateMediaBonus(hasMedia);
    return widget.baseCoins + stepBonus + mediaBonus;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectMood(int mood) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMood = _selectedMood == mood ? null : mood;
    });
  }

  void _toggleStep(String stepId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_completedStepIds.contains(stepId)) {
        _completedStepIds.remove(stepId);
      } else {
        _completedStepIds.add(stepId);
      }
    });
  }

  Future<void> _openVoiceRecorder() async {
    final entryId = 'habit_${widget.habit.id}_${DateTime.now().millisecondsSinceEpoch}';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceRecorderSheet(
        entryId: entryId,
        onRecordingComplete: (path) {
          if (mounted) setState(() => _audioPath = path);
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _imagePaths.add(picked.path));
  }

  void _removeImage(int index) {
    HapticFeedback.selectionClick();
    setState(() => _imagePaths.removeAt(index));
  }

  void _removeAudio() {
    HapticFeedback.selectionClick();
    if (_audioPath != null) {
      JournalAudioStorageService.deleteAudio(_audioPath!);
    }
    setState(() => _audioPath = null);
  }

  void _confirm() {
    HapticFeedback.mediumImpact();

    final noteText = _noteController.text.trim();
    Navigator.of(context).pop(HabitCompletionResult(
      coinsEarned: _totalCoins,
      mood: _selectedMood,
      note: noteText.isEmpty ? null : noteText,
      completedStepIds: _completedStepIds.toList(),
      audioPath: _audioPath,
      imagePaths: List.unmodifiable(_imagePaths),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final keyboardInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_scaleAnimation.value.clamp(0.0, 1.0) * 0.2),
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: _scaleAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInsets),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.only(bottom: bottomPadding),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    'How did it feel?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.habit.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Action steps checklist (full habit only)
                  if (_showSteps) ...[
                    const SizedBox(height: 20),
                    _ActionStepsChecklist(
                      steps: widget.habit.actionSteps,
                      completedIds: _completedStepIds,
                      onToggle: _toggleStep,
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Mood row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _moods.map((mood) {
                      final isSelected = _selectedMood == mood.value;
                      return _MoodButton(
                        mood: mood,
                        isSelected: isSelected,
                        onTap: () => _selectMood(mood.value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Note text field with embedded media icons
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write about how you feel...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.only(
                        left: 4,
                        right: 4,
                        top: 14,
                        bottom: 14,
                      ),
                      prefixIcon: GestureDetector(
                        onTap: _pickImage,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, right: 4),
                          child: Icon(
                            _imagePaths.isNotEmpty
                                ? Icons.image
                                : Icons.image_outlined,
                            size: 22,
                            color: _imagePaths.isNotEmpty
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: _openVoiceRecorder,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, left: 4),
                          child: Icon(
                            _audioPath != null
                                ? Icons.mic
                                : Icons.mic_none_rounded,
                            size: 22,
                            color: _audioPath != null
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),

                  // Media attachment previews
                  _MediaPreviews(
                    audioPath: _audioPath,
                    imagePaths: _imagePaths,
                    onRemoveAudio: _removeAudio,
                    onRemoveImage: _removeImage,
                  ),

                  const SizedBox(height: 24),
                  // Complete button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Complete',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  size: 16,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+$_totalCoins',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Action steps checklist
// =============================================================================

class _ActionStepsChecklist extends StatelessWidget {
  final List steps;
  final Set<String> completedIds;
  final ValueChanged<String> onToggle;

  const _ActionStepsChecklist({
    required this.steps,
    required this.completedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sorted = List.of(steps)..sort((a, b) => a.order.compareTo(b.order));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final step = sorted[index];
            final isChecked = completedIds.contains(step.id);
            return _StepTile(
              step: step,
              isChecked: isChecked,
              onTap: () => onToggle(step.id),
            );
          },
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final dynamic step;
  final bool isChecked;
  final VoidCallback onTap;

  const _StepTile({
    required this.step,
    required this.isChecked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked
                    ? colorScheme.primary
                    : Colors.transparent,
                border: Border.all(
                  color: isChecked
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isChecked
                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                      : colorScheme.onSurface,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Media attachment previews (shown below text field when media is attached)
// =============================================================================

class _MediaPreviews extends StatelessWidget {
  final String? audioPath;
  final List<String> imagePaths;
  final VoidCallback onRemoveAudio;
  final ValueChanged<int> onRemoveImage;

  const _MediaPreviews({
    required this.audioPath,
    required this.imagePaths,
    required this.onRemoveAudio,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent = audioPath != null || imagePaths.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Audio chip
        if (audioPath != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.audiotrack_rounded, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Voice note attached',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onRemoveAudio,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

        // Image thumbnails
        if (imagePaths.isNotEmpty) ...[
          if (audioPath != null) const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(imagePaths[index]),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 24,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: () => onRemoveImage(index),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// A single mood emoji button with bounce animation on selection.
class _MoodButton extends StatefulWidget {
  final _MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodButton({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MoodButton> createState() => _MoodButtonState();
}

class _MoodButtonState extends State<_MoodButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(_MoodButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final bounce =
              Curves.elasticOut.transform(_bounceController.value);
          return Transform.scale(
            scale: widget.isSelected ? 0.9 + (bounce * 0.1) : 1.0,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.mood.color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.mood.icon,
                  size: widget.isSelected ? 40 : 34,
                  color: widget.isSelected
                      ? widget.mood.color
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mood.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isSelected
                      ? widget.mood.color
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
