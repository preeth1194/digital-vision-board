import 'package:flutter/material.dart';
import '../utils/app_typography.dart';

class WidgetGuideScreen extends StatelessWidget {
  const WidgetGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Guide'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Text('Home Screen Widgets', style: AppTypography.heading1(context)),
          const SizedBox(height: 6),
          Text(
            'Add widgets to your home screen for quick access to habits and puzzles.',
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 28),

          _WidgetSection(
            icon: Icons.check_circle_outline,
            title: 'Habit Progress',
            subtitle: 'Track and toggle habits without opening the app.',
            androidSteps: const [
              'Long-press home screen → Widgets.',
              'Find "Digital Vision Board".',
              'Add the "Habit Progress" widget.',
            ],
            iosSteps: const [
              'Long-press home screen → tap +.',
              'Search "Digital Vision Board".',
              'Add the "Habit Progress" widget.',
            ],
          ),
          const SizedBox(height: 24),

          _WidgetSection(
            icon: Icons.extension,
            title: 'Puzzle Challenge',
            subtitle: 'Solve goal-image puzzles from your home screen.',
            androidSteps: const [
              'Long-press home screen → Widgets.',
              'Find "Digital Vision Board".',
              'Add the "Puzzle Challenge" widget.',
            ],
            iosSteps: const [
              'Long-press home screen → tap +.',
              'Search "Digital Vision Board".',
              'Add the "Puzzle Challenge" widget.',
            ],
          ),
          const SizedBox(height: 24),

          Card(
            color: scheme.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If a widget doesn\'t update right away, open the app once to refresh.',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> androidSteps;
  final List<String> iosSteps;

  const _WidgetSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.androidSteps,
    required this.iosSteps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.heading3(context)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypography.bodySmall(context)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PlatformSteps(
                label: 'Android', icon: Icons.android, steps: androidSteps),
            const SizedBox(height: 12),
            _PlatformSteps(
                label: 'iOS', icon: Icons.phone_iphone, steps: iosSteps),
          ],
        ),
      ),
    );
  }
}

class _PlatformSteps extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> steps;

  const _PlatformSteps({
    required this.label,
    required this.icon,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.body(context)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Text('${i + 1}. ${steps[i]}',
                style: AppTypography.bodySmall(context)),
          ),
      ],
    );
  }
}
