import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/dv_auth_service.dart';
import '../../../services/image_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/grid/image_source_sheet.dart';
import '../../../widgets/profile_avatar.dart';

/// Minimal profile capture during onboarding: name (required), optional photo,
/// gender, and date of birth. Persists via [DvAuthService] on continue.
class OnboardingProfileStep extends StatefulWidget {
  const OnboardingProfileStep({
    super.key,
    required this.replayMode,
    required this.onSaved,
    required this.onSkipWithoutSaving,
  });

  final bool replayMode;
  final VoidCallback onSaved;
  final VoidCallback onSkipWithoutSaving;

  @override
  State<OnboardingProfileStep> createState() => OnboardingProfileStepState();
}

class OnboardingProfileStepState extends State<OnboardingProfileStep> {
  final _nameController = TextEditingController();
  String _gender = 'prefer_not_to_say';
  DateTime? _dob;
  String? _nameError;
  String? _profilePicPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final name = await DvAuthService.getDisplayName();
    final gender = await DvAuthService.getGender();
    final dobStr = await DvAuthService.getDateOfBirth();
    final profilePicPath = await DvAuthService.getProfilePicPath();
    if (!mounted) return;
    setState(() {
      _nameController.text = name ?? '';
      _gender = gender;
      _dob = dobStr != null ? DateTime.tryParse(dobStr) : null;
      _profilePicPath = profilePicPath;
    });
  }

  Future<void> _changeProfilePhoto() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final path = await ImageService.pickAndCropProfileImage(context, source: source);
    if (path != null && mounted) {
      await DvAuthService.setProfilePicPath(path);
      setState(() => _profilePicPath = path);
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

  String _dobLabel() {
    if (_dob == null) return 'Add date (optional)';
    final y = _dob!.year.toString().padLeft(4, '0');
    final m = _dob!.month.toString().padLeft(2, '0');
    final d = _dob!.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  /// Validates, writes prefs, then calls [onSaved].
  Future<void> submitAndAdvance() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Add a name to continue.');
      return;
    }
    setState(() => _nameError = null);
    final dobStr = _dob != null
        ? '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
        : null;
    await DvAuthService.setProfileInfo(
      displayName: name,
      dateOfBirth: dobStr,
    );
    await DvAuthService.setGender(_gender);
    if (!mounted) return;
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Semantics(
      label: 'Onboarding profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your corner of the garden',
              textAlign: TextAlign.center,
              style: AppTypography.heading2(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A display name helps your space feel like yours. Everything else is optional.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(context).copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: AppColors.cloudDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: 'Profile photo',
                    button: true,
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
                        const SizedBox(height: AppSpacing.xs),
                        TextButton(
                          onPressed: _changeProfilePhoto,
                          child: Text(
                            'Add or change photo',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _nameController,
                    style: AppTypography.body(context),
                    textCapitalization: TextCapitalization.words,
                    maxLength: 100,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'Display name',
                      hintText: 'What should we call you?',
                      hintStyle: AppTypography.secondary(context).copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      errorText: _nameError,
                      errorStyle: AppTypography.error(context),
                      filled: true,
                      fillColor: scheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                        borderSide: BorderSide(color: scheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // `value` still required for controlled updates after async [_load].
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _gender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      filled: true,
                      fillColor: scheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                    ),
                    items: ['prefer_not_to_say', 'male', 'female', 'non_binary']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              _genderLabel(v),
                              style: AppTypography.body(context),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _gender = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label: 'Date of birth, optional',
                    button: true,
                    child: InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of birth',
                          filled: true,
                          fillColor: scheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                            borderSide: BorderSide(color: scheme.outline),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          _dobLabel(),
                          style: AppTypography.body(context).copyWith(
                            color: _dob == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.replayMode) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: widget.onSkipWithoutSaving,
                  child: Text(
                    'Skip this step',
                    style: AppTypography.button(context).copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
