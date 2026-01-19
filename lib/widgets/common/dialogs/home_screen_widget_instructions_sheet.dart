import 'package:flutter/material.dart';

Future<void> showHomeScreenWidgetInstructionsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.75,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
            children: const [
              Text(
                'Add home-screen widget',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'This widget shows up to 3 of today’s pending habits from your default board (time-target habits are excluded). Tap to mark complete.',
              ),
              SizedBox(height: 16),
              _SectionTitle('Android'),
              SizedBox(height: 8),
              _Step('1', 'Long-press your home screen.'),
              _Step('2', 'Tap Widgets.'),
              _Step('3', 'Find “Digital Vision Board”.'),
              _Step('4', 'Add “Habit Progress”.'),
              _Step('5', 'Optional: Tap a habit in the widget to toggle it (may briefly open the app).'),
              SizedBox(height: 16),
              _SectionTitle('iPhone / iPad'),
              SizedBox(height: 8),
              _Step('1', 'Long-press your home screen.'),
              _Step('2', 'Tap the + button (top-left).'),
              _Step('3', 'Search for “Digital Vision Board”.'),
              _Step('4', 'Add “Habit Progress”.'),
              _Step('5', 'iOS 17+: the toggle can be interactive. iOS < 17: toggles open the app to apply.'),
              SizedBox(height: 16),
              Text('Tip: If the widget doesn’t update immediately, open the app once to refresh today’s snapshot.'),
            ],
          ),
        ),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step(this.n, this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(n, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

