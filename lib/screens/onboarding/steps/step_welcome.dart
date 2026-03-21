import 'package:flutter/material.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '_step_header.dart';

class StepWelcome extends StatefulWidget {
  final void Function(String name) onNext;

  const StepWelcome({super.key, required this.onNext});

  @override
  State<StepWelcome> createState() => _StepWelcomeState();
}

class _StepWelcomeState extends State<StepWelcome> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await DvAuthService.setProfileInfo(displayName: name);
    widget.onNext(name);
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
              const StepHeader(
                title: 'What should\nwe call you?',
                subtitle: 'Your name makes the journey personal.',
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.words,
                style: AppTypography.heading2(context).copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestDeep,
                ),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: AppTypography.heading2(context).copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestDeep.withValues(alpha: 0.25),
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
              // Live preview — rebuilt only when text changes, not the full screen
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
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
              const Spacer(),
              // Button rebuilt only when hasName changes
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final hasName = value.text.trim().isNotEmpty;
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: hasName ? _onContinue : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sproutGreen,
                        disabledBackgroundColor:
                            AppColors.sproutGreen.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
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
            ],
          ),
        ),
      ),
    );
  }
}
