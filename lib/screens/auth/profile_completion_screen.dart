import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_settings_service.dart';
import '../../services/dv_auth_service.dart';
import '../../services/image_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../utils/measurement_utils.dart';
import '../../widgets/grid/image_source_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/rituals/habit_form_constants.dart';

/// Profile editing screen. User can fill/update name and other details.
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
  String? _profilePicPath;

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
    final profilePicPath = await DvAuthService.getProfilePicPath();
    final unit = AppSettingsService.getMeasurementUnit();
    if (!mounted) return;
    setState(() {
      _profilePicPath = profilePicPath;
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

  Future<void> _changeProfilePhoto() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final path = await ImageService.pickAndCropProfileImage(context, source: source);
    if (path != null && mounted) {
      await DvAuthService.setProfilePicPath(path);
      if (mounted) setState(() => _profilePicPath = path);
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.skyGradient(isDark: isDark),
      ),
      child: Scaffold(
      backgroundColor: Colors.transparent,
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
                backgroundColor: Colors.transparent,
                decoration: const BoxDecoration(),
                separatorColor: habitSectionSeparatorColor(colorScheme),
                children: [
                  // Profile icon centered (reference layout)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ProfileAvatar(
                          initial: _nameController.text.isNotEmpty
                              ? _nameController.text[0].toUpperCase()
                              : '?',
                          imagePath: _profilePicPath,
                          radius: 48,
                          onTap: _changeProfilePhoto,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _changeProfilePhoto,
                          child: Text(
                            'Change photo',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: TextField(
                      controller: _nameController,
                      style: AppTypography.body(context),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Name',
                        hintText: 'Your name',
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        errorText: _nameError,
                        errorStyle: AppTypography.caption(context).copyWith(color: colorScheme.error),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                  ),
                  ExpansionTile(
                    leading: Icon(Icons.monitor_weight_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                    title: Text(
                      unit == MeasurementUnit.metric
                          ? (_weightController.text.isEmpty ? 'Weight' : '${_weightController.text} kg')
                          : (_weightController.text.isEmpty ? 'Weight' : '${_weightController.text} lb'),
                      style: AppTypography.body(context),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _weightController,
                              style: AppTypography.body(context),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                hintText: unit == MeasurementUnit.metric ? 'e.g. 70' : 'e.g. 154',
                                hintStyle: AppTypography.body(context).copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.primary.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: unit == MeasurementUnit.metric ? 'kg' : 'lb',
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'kg', child: Text('kg')),
                                DropdownMenuItem(value: 'lb', child: Text('lb')),
                              ],
                              onChanged: (v) {
                                if (v == 'kg') {
                                  _onUnitChanged(MeasurementUnit.metric);
                                } else if (v == 'lb') {
                                  _onUnitChanged(MeasurementUnit.imperial);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(Icons.height_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                    title: Text(
                      unit == MeasurementUnit.metric
                          ? (_heightController.text.isEmpty ? 'Height' : '${_heightController.text} cm')
                          : (_heightFeetController.text.isEmpty && _heightInchesController.text.isEmpty
                              ? 'Height'
                              : '${_heightFeetController.text} ft ${_heightInchesController.text} in'),
                      style: AppTypography.body(context),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (unit == MeasurementUnit.metric)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _heightController,
                                style: AppTypography.body(context),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'e.g. 170',
                                  hintStyle: AppTypography.body(context).copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('cm', style: AppTypography.body(context)),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _heightFeetController,
                                style: AppTypography.body(context),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Feet',
                                  hintText: 'e.g. 5',
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('ft', style: AppTypography.body(context)),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _heightInchesController,
                                style: AppTypography.body(context),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Inches',
                                  hintText: 'e.g. 10',
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text('in', style: AppTypography.body(context)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(Icons.wc_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                    title: Text(_genderLabel(_gender), style: AppTypography.body(context)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final v in const ['prefer_not_to_say', 'male', 'female', 'non_binary'])
                        RadioListTile<String>(
                          value: v,
                          groupValue: _gender,
                          title: Text(_genderLabel(v), style: AppTypography.body(context)),
                          onChanged: (x) {
                            if (x != null) setState(() => _gender = x);
                          },
                        ),
                    ],
                  ),
                  ExpansionTile(
                    leading: Icon(Icons.cake_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                    title: Text(
                      _dob != null
                          ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
                          : 'Date of birth',
                      style: AppTypography.body(context),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    children: [
                      SizedBox(
                        height: 200,
                        child: CupertinoTheme(
                          data: CupertinoThemeData(
                            brightness: isDark ? Brightness.dark : Brightness.light,
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: _dob ?? DateTime(1990, 1, 1),
                            maximumDate: DateTime.now(),
                            onDateTimeChanged: (v) => setState(() => _dob = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
    ),
    );
  }
}
