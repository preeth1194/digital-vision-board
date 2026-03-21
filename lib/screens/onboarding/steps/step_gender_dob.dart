import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';

class StepGenderDob extends StatefulWidget {
  final void Function(String? gender, DateTime? dob) onNext;

  const StepGenderDob({super.key, required this.onNext});

  @override
  State<StepGenderDob> createState() => _StepGenderDobState();
}

class _StepGenderDobState extends State<StepGenderDob> {
  String? _selectedGender;
  DateTime? _dob;

  static const _genders = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('non_binary', 'Non-binary'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

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

  Future<void> _onContinue() async {
    if (_selectedGender != null) {
      await DvAuthService.setGender(_selectedGender);
    }
    if (_dob != null) {
      await DvAuthService.setDateOfBirth(_dob!.toIso8601String());
    }
    widget.onNext(_selectedGender, _dob);
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
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Tell us a bit\nmore.',
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
                'Helps tailor your habit recommendations.',
                style: AppTypography.body(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'GENDER',
                style: AppTypography.caption(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.5),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...(_genders.map((g) {
                final (value, label) = g;
                final isSelected = _selectedGender == value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedGender = isSelected ? null : value;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.forestDeep
                            : AppColors.forestDeep.withOpacity(0.06),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusChip),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: AppTypography.bodySmall(context).copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.forestDeep.withOpacity(0.6),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: AppSpacing.sm,
                              height: AppSpacing.sm,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.sproutGreen,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              })),
              const SizedBox(height: AppSpacing.md),
              Text(
                'DATE OF BIRTH',
                style: AppTypography.caption(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.5),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.forestDeep.withOpacity(0.12),
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
                              : 'Select date',
                          style: AppTypography.heading3(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: _dob != null
                                ? AppColors.forestDeep
                                : AppColors.forestDeep.withOpacity(0.3),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.sproutGreen.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
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
