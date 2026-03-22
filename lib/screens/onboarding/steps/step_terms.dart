import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/terms_consent_layout.dart';

class StepTerms extends StatelessWidget {
  final VoidCallback onNext;

  const StepTerms({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sproutGreen,
      child: TermsConsentLayout(onAcceptComplete: onNext),
    );
  }
}
