import 'package:flutter/material.dart';

import '../utils/app_typography.dart';
import '../widgets/layout/minimal_section_header.dart';
import '../widgets/layout/morning_garden_scaffold.dart';
import '../utils/faq_items.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dcs = Theme.of(context).colorScheme;
    return MorningGardenScaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          MinimalSectionHeader(
            title: 'Frequently Asked\nQuestions',
            subtitle:
                'Quick answers about accounts, sync, subscriptions, and support.',
          ),
          const SizedBox(height: 20),
          ...kFaqItems.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: dcs.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    item.question,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: dcs.onSurface,
                    ),
                  ),
                  iconColor: dcs.onSurface,
                  collapsedIconColor: dcs.onSurfaceVariant,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.answer,
                        style: AppTypography.bodySmall(
                          context,
                        ).copyWith(color: dcs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
