import 'package:flutter/material.dart';

import 'onboarding/onboarding_carousel_screen.dart';

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('View onboarding'),
            subtitle: const Text('Replay the intro carousel anytime'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingCarouselScreen(
                    onFinished: (ctx) => Navigator.of(ctx).pop(),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 0),
        ],
      ),
    );
  }
}

