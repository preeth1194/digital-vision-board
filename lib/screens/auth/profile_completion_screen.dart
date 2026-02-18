import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/app_settings_service.dart';
import '../../services/dv_auth_service.dart';
import '../../utils/app_typography.dart';
import '../../utils/measurement_utils.dart';
import '../../widgets/rituals/habit_form_constants.dart';

/// Shown after phone sign-in when profile is incomplete. User must fill name and other details.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();

  String _gender = 'prefer_not_to_say';
  DateTime? _dob;
  String? _nameError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final name = await DvAuthService.getDisplayName();
    final weightKg = await DvAuthService.getWeightKg();
    final heightCm = await DvAuthService.getHeightCm();
    final gender = await DvAuthService.getGender();
    final dobStr = await DvAuthService.getDateOfBirth();
    final unit = AppSettingsService.getMeasurementUnit();
    if (!mounted) return;
    setState(() {
      _nameController.text = name ?? '';
      if (unit == MeasurementUnit.metric) {
        _weightController.text = weightKg != null ? weightKg.toStringAsFixed(1) : '';
        _heightController.text = heightCm != null ? heightCm.toStringAsFixed(0) : '';
        _heightFeetController.text = '';
        _heightInchesController.text = '';
      } else {
        _weightController.text = weightKg != null
            ? MeasurementUtils.kgToLb(weightKg).toStringAsFixed(1)
            : '';
        _heightController.text = '';
        if (heightCm != null) {
          final (ft, inVal) = MeasurementUtils.cmToFtIn(heightCm);
          _heightFeetController.text = ft.toString();
          _heightInchesController.text = inVal.toString();
        } else {
          _heightFeetController.text = '';
          _heightInchesController.text = '';
        }
      }
      _gender = gender;
      _dob = dobStr != null ? DateTime.tryParse(dobStr) : null;
    });
  }

  Future<void> _onUnitChanged(MeasurementUnit newUnit) async {
    final oldUnit = AppSettingsService.getMeasurementUnit();
    if (oldUnit == newUnit) return;

    double? weightKg;
    double? heightCm;

    if (oldUnit == MeasurementUnit.metric) {
      weightKg = double.tryParse(_weightController.text.trim());
      heightCm = double.tryParse(_heightController.text.trim());
    } else {
      final lb = double.tryParse(_weightController.text.trim());
      weightKg = lb != null ? MeasurementUtils.lbToKg(lb) : null;
      final ft = int.tryParse(_heightFeetController.text.trim()) ?? 0;
      final inVal = int.tryParse(_heightInchesController.text.trim()) ?? 0;
      heightCm = (ft > 0 || inVal > 0) ? MeasurementUtils.ftInToCm(ft, inVal) : null;
    }

    await AppSettingsService.setMeasurementUnit(newUnit);
    if (!mounted) return;
    setState(() {
      if (newUnit == MeasurementUnit.metric) {
        _weightController.text = weightKg != null ? weightKg.toStringAsFixed(1) : '';
        _heightController.text = heightCm != null ? heightCm.toStringAsFixed(0) : '';
        _heightFeetController.text = '';
        _heightInchesController.text = '';
      } else {
        _weightController.text = weightKg != null
            ? MeasurementUtils.kgToLb(weightKg).toStringAsFixed(1)
            : '';
        _heightController.text = '';
        if (heightCm != null) {
          final (ft, inVal) = MeasurementUtils.cmToFtIn(heightCm);
          _heightFeetController.text = ft.toString();
          _heightInchesController.text = inVal.toString();
        } else {
          _heightFeetController.text = '';
          _heightInchesController.text = '';
        }
      }
    });
  }

  String _genderLabel(String v) {
    switch (v) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'non_binary':
        return 'Non-binary';
      default:
        return 'Prefer not to say';
    }
  }

  Future<void> _pickGender() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Gender', style: AppTypography.heading3(context)),
            const SizedBox(height: 8),
            for (final v in const ['prefer_not_to_say', 'male', 'female', 'non_binary'])
              RadioListTile<String>(
                value: v,
                groupValue: _gender,
                title: Text(_genderLabel(v)),
                onChanged: (x) => Navigator.of(ctx).pop(x),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _gender = selected);
  }

  Future<void> _pickDob() async {
    final initial = _dob ?? DateTime(1990, 1, 1);
    DateTime selected = initial;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() => _dob = selected);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (v) => selected = v,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    setState(() {
      _nameError = null;
      _loading = true;
    });
    try {
      final unit = AppSettingsService.getMeasurementUnit();
      double? weightKg;
      double? heightCm;

      if (unit == MeasurementUnit.metric) {
        weightKg = double.tryParse(_weightController.text.trim());
        heightCm = double.tryParse(_heightController.text.trim());
      } else {
        final lb = double.tryParse(_weightController.text.trim());
        weightKg = lb != null ? MeasurementUtils.lbToKg(lb) : null;
        final ft = int.tryParse(_heightFeetController.text.trim()) ?? 0;
        final inVal = int.tryParse(_heightInchesController.text.trim()) ?? 0;
        heightCm = (ft > 0 || inVal > 0) ? MeasurementUtils.ftInToCm(ft, inVal) : null;
      }

      final dobStr = _dob != null
          ? '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
          : null;
      await DvAuthService.setProfileInfo(
        displayName: name,
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: dobStr,
      );
      await DvAuthService.setGender(_gender);
      await DvAuthService.putUserSettings(
        gender: _gender,
        displayName: name,
        weightKg: weightKg,
        heightCm: heightCm,
        dateOfBirth: dobStr,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Add your details to personalize your experience.',
            style: AppTypography.bodySmall(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<MeasurementUnit>(
            valueListenable: AppSettingsService.measurementUnit,
            builder: (context, unit, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          'Units',
                          style: AppTypography.caption(context).copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SegmentedButton<MeasurementUnit>(
                          segments: const [
                            ButtonSegment(
                              value: MeasurementUnit.metric,
                              label: Text('Metric'),
                            ),
                            ButtonSegment(
                              value: MeasurementUnit.imperial,
                              label: Text('Imperial'),
                            ),
                          ],
                          selected: {unit},
                          onSelectionChanged: (selected) {
                            _onUnitChanged(selected.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<MeasurementUnit>(
            valueListenable: AppSettingsService.measurementUnit,
            builder: (context, unit, _) {
              return CupertinoListSection.insetGrouped(
                header: Text(
                  'Profile',
                  style: AppTypography.caption(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                margin: EdgeInsets.zero,
                backgroundColor: colorScheme.surface,
                decoration: habitSectionDecoration(colorScheme),
                separatorColor: habitSectionSeparatorColor(colorScheme),
                children: [
                  Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.zero,
                ),
                child: TextField(
                  controller: _nameController,
                  style: AppTypography.body(context),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Your name',
                    hintStyle: AppTypography.body(context).copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    errorText: _nameError,
                    errorStyle: AppTypography.caption(context).copyWith(color: colorScheme.error),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                  ),
                  onChanged: (_) => setState(() => _nameError = null),
                ),
              ),
              CupertinoListTile.notched(
                leading: Icon(Icons.monitor_weight_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                title: Text(
                  unit == MeasurementUnit.metric
                      ? (_weightController.text.isEmpty ? 'Weight (kg)' : '${_weightController.text} kg')
                      : (_weightController.text.isEmpty ? 'Weight (lb)' : '${_weightController.text} lb'),
                  style: AppTypography.body(context),
                ),
                trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final c = TextEditingController(text: _weightController.text);
                      return AlertDialog(
                        title: Text(unit == MeasurementUnit.metric ? 'Weight (kg)' : 'Weight (lb)'),
                        content: TextField(
                          controller: c,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: unit == MeasurementUnit.metric ? 'e.g. 70' : 'e.g. 154',
                          ),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
                            child: const Text('Done'),
                          ),
                        ],
                      );
                    },
                  );
                  if (result != null && mounted) {
                    setState(() => _weightController.text = result);
                  }
                },
              ),
              if (unit == MeasurementUnit.metric)
                CupertinoListTile.notched(
                  leading: Icon(Icons.height_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                  title: Text(
                    _heightController.text.isEmpty ? 'Height (cm)' : '${_heightController.text} cm',
                    style: AppTypography.body(context),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final c = TextEditingController(text: _heightController.text);
                        return AlertDialog(
                          title: const Text('Height (cm)'),
                          content: TextField(
                            controller: c,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: 'e.g. 170'),
                            autofocus: true,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
                              child: const Text('Done'),
                            ),
                          ],
                        );
                      },
                    );
                    if (result != null && mounted) {
                      setState(() => _heightController.text = result);
                    }
                  },
                ),
              if (unit == MeasurementUnit.imperial)
                CupertinoListTile.notched(
                  leading: Icon(Icons.height_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                  title: Text(
                    _heightFeetController.text.isEmpty && _heightInchesController.text.isEmpty
                        ? 'Height (ft & in)'
                        : '${_heightFeetController.text} ft ${_heightInchesController.text} in',
                    style: AppTypography.body(context),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                  onTap: () async {
                    final result = await showDialog<(String, String)>(
                      context: context,
                      builder: (ctx) {
                        final feetC = TextEditingController(text: _heightFeetController.text);
                        final inchesC = TextEditingController(text: _heightInchesController.text);
                        return AlertDialog(
                          title: const Text('Height (ft & in)'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: feetC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Feet',
                                  hintText: 'e.g. 5',
                                ),
                                autofocus: true,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: inchesC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Inches',
                                  hintText: 'e.g. 10',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop((feetC.text.trim(), inchesC.text.trim())),
                              child: const Text('Done'),
                            ),
                          ],
                        );
                      },
                    );
                    if (result != null && mounted) {
                      setState(() {
                        _heightFeetController.text = result.$1;
                        _heightInchesController.text = result.$2;
                      });
                    }
                  },
                ),
              CupertinoListTile.notched(
                leading: Icon(Icons.wc_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                title: Text(_genderLabel(_gender), style: AppTypography.body(context)),
                trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                onTap: _pickGender,
              ),
              CupertinoListTile.notched(
                leading: Icon(Icons.cake_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                title: Text(
                  _dob != null
                      ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
                      : 'Date of birth',
                  style: AppTypography.body(context),
                ),
                trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                onTap: _pickDob,
              ),
            ],
          );
        },
      ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save & continue'),
          ),
        ],
      ),
    );
  }
}
