import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../widgets/onboarding_bottom_actions.dart';
import '_step_header.dart';

/// Combined onboarding: photo, name, gender, DOB, height, weight, activity.
class StepProfileSetup extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const StepProfileSetup({
    super.key,
    required this.onNext,
    this.onBack,
  });

  @override
  State<StepProfileSetup> createState() => _StepProfileSetupState();
}

class _StepProfileSetupState extends State<StepProfileSetup> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  String? _photoPath;
  bool _picking = false;
  String? _selectedGender;
  DateTime? _dob;

  bool _useMetric = true;
  double _heightCm = 170;
  double _weightKg = 70;
  bool _heightSet = false;
  bool _weightSet = false;
  static const _defaultActivityLevel = 'moderately_active';
  String _activityLevel = _defaultActivityLevel;

  static const _genders = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('non_binary', 'Non-binary'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  static const _activities = [
    ('sedentary', '🪑', 'Sedentary'),
    ('lightly_active', '🚶', 'Lightly Active'),
    ('moderately_active', '🏃', 'Moderately Active'),
    ('very_active', '🏋️', 'Very Active'),
  ];

  String get _displayHeight {
    if (_useMetric) return '${_heightCm.round()} cm';
    final totalIn = _heightCm / 2.54;
    final ft = totalIn ~/ 12;
    final inches = (totalIn % 12).round();
    return '$ft ft $inches in';
  }

  String get _displayWeight {
    if (_useMetric) return '${_weightKg.round()} kg';
    return '${(_weightKg * 2.2046).round()} lbs';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
        await DvAuthService.setProfilePicPath(picked.path);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.sproutGreen,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  void _showHeightPicker() {
    if (_useMetric) {
      _showCmPicker(
        initialValue: _heightCm.round(),
        min: 100,
        max: 250,
        unit: 'cm',
        onSelected: (v) => setState(() {
          _heightCm = v.toDouble();
          _heightSet = true;
        }),
      );
    } else {
      final initFt = (_heightCm / 30.48).floor().clamp(3, 8);
      final initIn = ((_heightCm % 30.48) / 2.54).round().clamp(0, 11);
      _showImperialHeightPicker(initFt, initIn);
    }
  }

  void _showWeightPicker() {
    if (_useMetric) {
      _showCmPicker(
        initialValue: _weightKg.round(),
        min: 30,
        max: 200,
        unit: 'kg',
        onSelected: (v) => setState(() {
          _weightKg = v.toDouble();
          _weightSet = true;
        }),
      );
    } else {
      final initLbs = (_weightKg * 2.2046).round().clamp(66, 440);
      _showCmPicker(
        initialValue: initLbs,
        min: 66,
        max: 440,
        unit: 'lbs',
        onSelected: (v) => setState(() {
          _weightKg = v / 2.2046;
          _weightSet = true;
        }),
      );
    }
  }

  void _showCmPicker({
    required int initialValue,
    required int min,
    required int max,
    required String unit,
    required void Function(int) onSelected,
  }) {
    final items = List.generate(max - min + 1, (i) => min + i);
    int selected = (initialValue - min).clamp(0, items.length - 1);
    final controller = FixedExtentScrollController(initialItem: selected);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusDialog),
        ),
      ),
      builder: (_) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.forestDeep.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelected(items[selected]);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.sproutGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: controller,
                itemExtent: 40,
                onSelectedItemChanged: (i) => selected = i,
                children: items
                    .map(
                      (v) => Center(
                        child: Text(
                          '$v $unit',
                          style: AppTypography.body(context).copyWith(
                            color: AppColors.forestDeep,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showImperialHeightPicker(int initFt, int initIn) {
    int selFt = initFt;
    int selIn = initIn;
    final ftController =
        FixedExtentScrollController(initialItem: (initFt - 3).clamp(0, 5));
    final inController =
        FixedExtentScrollController(initialItem: initIn.clamp(0, 11));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusDialog),
        ),
      ),
      builder: (_) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.forestDeep.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _heightCm = selFt * 30.48 + selIn * 2.54;
                        _heightSet = true;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Done',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.sproutGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: ftController,
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => selFt = i + 3,
                      children: List.generate(
                        6,
                        (i) => Center(
                          child: Text(
                            '${i + 3} ft',
                            style: AppTypography.body(context).copyWith(
                              color: AppColors.forestDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: inController,
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => selIn = i,
                      children: List.generate(
                        12,
                        (i) => Center(
                          child: Text(
                            '$i in',
                            style: AppTypography.body(context).copyWith(
                              color: AppColors.forestDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      ftController.dispose();
      inController.dispose();
    });
  }

  Future<void> _onContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await DvAuthService.setProfileInfo(displayName: name);
    await Future.wait([
      if (_selectedGender != null) DvAuthService.setGender(_selectedGender),
      if (_dob != null)
        DvAuthService.setDateOfBirth(_dob!.toIso8601String()),
    ]);
    if (_heightSet) await DvAuthService.setHeightCm(_heightCm);
    if (_weightSet) await DvAuthService.setWeightKg(_weightKg);
    await DvAuthService.setActivityLevel(_activityLevel);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mistBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    const StepHeader(
                      title: "Let's get to\nknow you.",
                      subtitle:
                          'Photo, name, a few personal details, and how you move — all in one calm step.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Semantics(
                        label: 'Profile photo',
                        button: true,
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            onTap: _pickPhoto,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _photoPath != null
                                      ? Colors.transparent
                                      : AppColors.sproutGreen
                                          .withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: _photoPath != null
                                        ? AppColors.sproutGreen
                                        : AppColors.sproutGreen
                                            .withValues(alpha: 0.4),
                                    width: 2,
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _photoPath != null
                                      ? Image.file(
                                          File(_photoPath!),
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        )
                                      : _picking
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.sproutGreen,
                                              ),
                                            )
                                          : Center(
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.sproutGreen,
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Text(
                        _photoPath != null
                            ? 'Tap to change photo'
                            : 'Optional — tap to add a photo',
                        style: AppTypography.caption(context).copyWith(
                          color: AppColors.sproutGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      style: AppTypography.heading2(context).copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forestDeep,
                      ),
                      decoration: InputDecoration(
                        // This step uses a fixed light canvas; override app-wide filled inputs so
                        // dark-mode theme does not paint a near-black fill behind the name field.
                        filled: true,
                        fillColor: AppColors.mistBackground,
                        hintText: 'Your name',
                        hintStyle: AppTypography.heading2(context).copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forestDeep.withValues(alpha: 0.35),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.sproutGreen.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.sproutGreen,
                            width: 2,
                          ),
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _onContinue(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _nameController,
                      builder: (context, value, _) {
                        final name = value.text.trim();
                        final hasName = name.isNotEmpty;
                        return AnimatedOpacity(
                          opacity: hasName ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.sproutGreen,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusCard),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR WELCOME',
                                  style: AppTypography.caption(context).copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Hey ${hasName ? name : ''}  👋',
                                  style: AppTypography.heading2(context).copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Welcome to Habit Seeding',
                                  style: AppTypography.body(context).copyWith(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'GENDER',
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.forestDeep.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final g in _genders)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: _GenderRowChip(
                                label: g.$2,
                                selected: _selectedGender == g.$1,
                                onTap: () => setState(() {
                                  _selectedGender =
                                      _selectedGender == g.$1 ? null : g.$1;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'DATE OF BIRTH',
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.forestDeep.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickDob,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.forestDeep
                                    .withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dob != null
                                      ? DateFormat('dd MMMM yyyy').format(_dob!)
                                      : 'Optional — select date',
                                  style: AppTypography.heading3(context).copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _dob != null
                                        ? AppColors.forestDeep
                                        : AppColors.forestDeep
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.sproutGreen.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'HEIGHT & WEIGHT',
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.forestDeep.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStatBox(
                            label: 'HEIGHT',
                            value: _heightSet ? _displayHeight : '—',
                            onTap: _showHeightPicker,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ProfileStatBox(
                            label: 'WEIGHT',
                            value: _weightSet ? _displayWeight : '—',
                            onTap: _showWeightPicker,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _ProfileUnitToggle(
                          label: 'cm / kg',
                          selected: _useMetric,
                          onTap: () => setState(() => _useMetric = true),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _ProfileUnitToggle(
                          label: 'ft / lbs',
                          selected: !_useMetric,
                          onTap: () => setState(() => _useMetric = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'ACTIVITY LEVEL',
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.forestDeep.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._activities.map((a) {
                      final (value, icon, label) = a;
                      final isSelected = _activityLevel == value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusChip),
                            onTap: () => setState(() => _activityLevel = value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.sproutGreen
                                    : AppColors.forestDeep.withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusChip),
                              ),
                              child: Row(
                                children: [
                                  Text(icon, style: AppTypography.body(context)),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.forestDeep
                                                .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, value, _) {
                  final hasName = value.text.trim().isNotEmpty;
                  return OnboardingBottomActions(
                    onBack: widget.onBack,
                    primary: FilledButton(
                      onPressed: hasName ? _onContinue : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sproutGreen,
                        disabledBackgroundColor:
                            AppColors.sproutGreen.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: AppTypography.button(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderRowChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderRowChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.forestDeep
                  : AppColors.forestDeep.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.bodySmall(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : AppColors.forestDeep.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ProfileStatBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.sproutGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: AppTypography.heading2(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestDeep,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.caption(context).copyWith(
                  color: AppColors.sproutGreen,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileUnitToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileUnitToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.forestDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          ),
          child: Text(
            label,
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : AppColors.forestDeep.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
