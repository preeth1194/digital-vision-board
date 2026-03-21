import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '_step_header.dart';

class StepPhoto extends StatefulWidget {
  final String name;
  final void Function(String? path) onNext;

  const StepPhoto({super.key, required this.name, required this.onNext});

  @override
  State<StepPhoto> createState() => _StepPhotoState();
}

class _StepPhotoState extends State<StepPhoto> {
  String? _photoPath;
  bool _picking = false;

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
        // Save immediately on selection — no redundant save needed on Continue
        await DvAuthService.setProfilePicPath(picked.path);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _onSkip() async {
    await DvAuthService.setProfilePicPath(null);
    widget.onNext(null);
  }

  // Photo was already saved in _pickPhoto; just advance.
  void _onContinue() => widget.onNext(_photoPath);

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.isNotEmpty ? widget.name : 'you';

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
              StepHeader(
                title: 'Add a photo,\n$displayName.',
                subtitle: 'Tap to choose from camera or gallery.',
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _photoPath != null
                          ? Colors.transparent
                          : AppColors.sproutGreen.withValues(alpha: 0.08),
                      border: Border.all(
                        color: _photoPath != null
                            ? AppColors.sproutGreen
                            : AppColors.sproutGreen.withValues(alpha: 0.4),
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
                              ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.sproutGreen,
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
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  _photoPath != null ? 'Tap to change' : 'Tap to add photo',
                  style: AppTypography.caption(context).copyWith(
                    color: AppColors.sproutGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _onSkip,
                  child: Text(
                    'Skip for now',
                    style: AppTypography.bodySmall(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.sproutGreen,
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
