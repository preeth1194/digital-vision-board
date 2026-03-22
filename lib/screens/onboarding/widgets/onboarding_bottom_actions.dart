import 'package:flutter/material.dart';

import '../../../utils/app_spacing.dart';

/// Leading back control plus expanded primary CTA (onboarding steps).
class OnboardingBottomActions extends StatelessWidget {
  const OnboardingBottomActions({
    super.key,
    this.onBack,
    this.backIconColor,
    required this.primary,
  });

  final VoidCallback? onBack;
  final Color? backIconColor;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = backIconColor ?? cs.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          Semantics(
            label: 'Back',
            button: true,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new),
              tooltip: 'Back',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                fixedSize: const Size(48, 48),
                foregroundColor: iconColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: primary),
      ],
    );
  }
}
