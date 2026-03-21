import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';

class StepBodyActivity extends StatefulWidget {
  final void Function(double? heightCm, double? weightKg, String activityLevel)
      onNext;

  const StepBodyActivity({super.key, required this.onNext});

  @override
  State<StepBodyActivity> createState() => _StepBodyActivityState();
}

class _StepBodyActivityState extends State<StepBodyActivity> {
  bool _useMetric = true;

  // Stored internally always as cm/kg
  double _heightCm = 170;
  double _weightKg = 70;
  bool _heightSet = false;
  bool _weightSet = false;

  String _activityLevel = 'moderately_active';

  static const _activities = [
    ('sedentary', '🪑', 'Sedentary'),
    ('lightly_active', '🚶', 'Lightly Active'),
    ('moderately_active', '🏃', 'Moderately Active'),
    ('very_active', '🏋️', 'Very Active'),
  ];

  // Imperial conversion helpers
  String get _displayHeight {
    if (_useMetric) return '${_heightCm.round()} cm';
    final totalIn = _heightCm / 2.54;
    final ft = totalIn ~/ 12;
    final inches = (totalIn % 12).round();
    return "$ft ft $inches in";
  }

  String get _displayWeight {
    if (_useMetric) return '${_weightKg.round()} kg';
    return '${(_weightKg * 2.2046).round()} lbs';
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
      // Feet picker: 3–8
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
                    child: Text('Cancel',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.forestDeep.withOpacity(0.5),
                        )),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelected(items[selected]);
                      Navigator.pop(context);
                    },
                    child: Text('Done',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.sproutGreen,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                    initialItem: (initialValue - min).clamp(0, items.length - 1)),
                itemExtent: 40,
                onSelectedItemChanged: (i) => selected = i,
                children: items
                    .map((v) => Center(
                          child: Text(
                            '$v $unit',
                            style: AppTypography.body(context).copyWith(
                              color: AppColors.forestDeep,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImperialHeightPicker(int initFt, int initIn) {
    int selFt = initFt;
    int selIn = initIn;

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
                    child: Text('Cancel',
                        style: AppTypography.bodySmall(context).copyWith(
                            color: AppColors.forestDeep.withOpacity(0.5))),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _heightCm = selFt * 30.48 + selIn * 2.54;
                        _heightSet = true;
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Done',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.sproutGreen,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: (initFt - 3).clamp(0, 5)),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => selFt = i + 3,
                      children: List.generate(
                        6,
                        (i) => Center(
                          child: Text('${i + 3} ft',
                              style: AppTypography.body(context)
                                  .copyWith(color: AppColors.forestDeep)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: initIn.clamp(0, 11)),
                      itemExtent: 40,
                      onSelectedItemChanged: (i) => selIn = i,
                      children: List.generate(
                        12,
                        (i) => Center(
                          child: Text('$i in',
                              style: AppTypography.body(context)
                                  .copyWith(color: AppColors.forestDeep)),
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
    );
  }

  Future<void> _onSkip() async {
    widget.onNext(null, null, _activityLevel);
  }

  Future<void> _onContinue() async {
    if (_heightSet) await DvAuthService.setHeightCm(_heightCm);
    if (_weightSet) await DvAuthService.setWeightKg(_weightKg);
    await DvAuthService.setActivityLevel(_activityLevel);
    widget.onNext(
      _heightSet ? _heightCm : null,
      _weightSet ? _weightKg : null,
      _activityLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mistBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Body &\nActivity.',
                style: AppTypography.heading1(context).copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestDeep,
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Helps personalise activity suggestions.',
                style: AppTypography.body(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Stat boxes
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'HEIGHT',
                      value: _heightSet ? _displayHeight : '—',
                      onTap: _showHeightPicker,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatBox(
                      label: 'WEIGHT',
                      value: _weightSet ? _displayWeight : '—',
                      onTap: _showWeightPicker,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Unit toggle
              Row(
                children: [
                  _UnitToggle(
                    label: 'cm / kg',
                    selected: _useMetric,
                    onTap: () => setState(() => _useMetric = true),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _UnitToggle(
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
                  color: AppColors.forestDeep.withOpacity(0.5),
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
                  child: GestureDetector(
                    onTap: () => setState(() => _activityLevel = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.sproutGreen
                            : AppColors.forestDeep.withOpacity(0.05),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusChip),
                      ),
                      child: Row(
                        children: [
                          Text(icon, style: AppTypography.body(context)),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            label,
                            style:
                                AppTypography.bodySmall(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.forestDeep.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _onSkip,
                  child: Text(
                    'Skip',
                    style: AppTypography.bodySmall(context).copyWith(
                      color: AppColors.sproutGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sproutGreen,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _StatBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.sproutGreen.withOpacity(0.08),
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
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                : AppColors.forestDeep.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
