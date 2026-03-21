import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';

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
      // On iOS/Android the OS sheet handles Camera vs Gallery selection
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

  Future<void> _onSkip() async {
    await DvAuthService.setProfilePicPath(null);
    widget.onNext(null);
  }

  Future<void> _onContinue() async {
    if (_photoPath != null) {
      await DvAuthService.setProfilePicPath(_photoPath);
    }
    widget.onNext(_photoPath);
  }

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
              Text(
                'Add a photo,\n$displayName.',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestDeep,
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap to choose from camera or gallery.',
                style: AppTypography.body(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Avatar ring
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
                          : AppColors.sproutGreen.withOpacity(0.08),
                      border: Border.all(
                        color: _photoPath != null
                            ? AppColors.sproutGreen
                            : AppColors.sproutGreen.withOpacity(0.4),
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
              // Skip
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _onSkip,
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sproutGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Continue
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sproutGreen,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
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
