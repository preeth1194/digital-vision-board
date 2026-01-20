import 'package:flutter/material.dart';
import '../utils/app_typography.dart';

class WidgetGuideScreen extends StatefulWidget {
  const WidgetGuideScreen({super.key});

  @override
  State<WidgetGuideScreen> createState() => _WidgetGuideScreenState();
}

class _WidgetGuideScreenState extends State<WidgetGuideScreen> {
  int _mockupState = 0; // 0: with habits, 1: all done, 2: no habits

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Guide'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Home Screen Widget',
              style: AppTypography.heading1(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your habits directly from your home screen',
              style: AppTypography.secondary(context),
            ),
            const SizedBox(height: 32),

            // Mockup Section
            _buildMockupSection(context),
            const SizedBox(height: 32),

            // Features Section
            _buildFeaturesSection(context),
            const SizedBox(height: 32),

            // Setup Instructions Section
            _buildSetupInstructionsSection(context),
            const SizedBox(height: 32),

            // Puzzle Widget Section
            _buildPuzzleWidgetSection(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMockupSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Stack vertically on small screens
                if (constraints.maxWidth < 400) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Widget Preview',
                        style: AppTypography.heading3(context),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Habits')),
                          ButtonSegment(value: 1, label: Text('Done')),
                          ButtonSegment(value: 2, label: Text('Empty')),
                        ],
                        selected: {_mockupState},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() {
                            _mockupState = newSelection.first;
                          });
                        },
                      ),
                    ],
                  );
                }
                // Horizontal layout on larger screens
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Widget Preview',
                        style: AppTypography.heading3(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Habits')),
                        ButtonSegment(value: 1, label: Text('Done')),
                        ButtonSegment(value: 2, label: Text('Empty')),
                      ],
                      selected: {_mockupState},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() {
                          _mockupState = newSelection.first;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Widget Mockup
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: _buildWidgetMockup(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetMockup(BuildContext context) {
    switch (_mockupState) {
      case 0: // With habits
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Vision Board',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            _buildHabitRow('Morning meditation', false),
            _buildHabitRow('Exercise for 30 min', false),
            _buildHabitRow('Read for 20 minutes', false),
          ],
        );
      case 1: // All done
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Vision Board',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'All done 🔥',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      case 2: // No habits
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Vision Board',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No habits today',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHabitRow(String habitName, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            onChanged: null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              habitName,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          context,
          icon: Icons.check_circle_outline,
          title: 'Quick Habit Tracking',
          description: 'Mark habits as complete directly from your home screen without opening the app.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.touch_app_outlined,
          title: 'Interactive Toggles',
          description: 'On iOS 17+, you can toggle habits directly on the widget. On earlier versions and Android, tapping opens the app to complete the action.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.list_outlined,
          title: 'Smart Habit Display',
          description: 'Shows up to 3 of your most important pending habits for today. Time-target habits are excluded for quick access.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.refresh_outlined,
          title: 'Auto-Updates',
          description: 'The widget automatically refreshes to show your latest habits. Open the app once to trigger an immediate update.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.music_note_outlined,
          title: 'Song-Based Habits',
          description: 'For habits with rhythmic timers, the widget displays song progress (e.g., "3/5 songs - Current Song Title").',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.celebration_outlined,
          title: 'Completion Celebration',
          description: 'When all habits are done, the widget shows "All done 🔥" to celebrate your achievement.',
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.heading3(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTypography.bodySmall(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupInstructionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Add the Widget',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 16),
        // Android Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.android,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Android',
                      style: AppTypography.heading3(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStep(context, '1', 'Long-press your home screen.'),
                _buildStep(context, '2', 'Tap Widgets.'),
                _buildStep(context, '3', 'Find "Digital Vision Board".'),
                _buildStep(context, '4', 'Add "Habit Progress" widget.'),
                _buildStep(context, '5', 'Optional: Tap a habit in the widget to toggle it (may briefly open the app).'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // iOS Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_iphone,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'iPhone / iPad',
                      style: AppTypography.heading3(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStep(context, '1', 'Long-press your home screen.'),
                _buildStep(context, '2', 'Tap the + button (top-left).'),
                _buildStep(context, '3', 'Search for "Digital Vision Board".'),
                _buildStep(context, '4', 'Add "Habit Progress" widget.'),
                _buildStep(context, '5', 'iOS 17+: the toggle can be interactive. iOS < 17: toggles open the app to apply.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tip Card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: If the widget doesn\'t update immediately, open the app once to refresh today\'s snapshot.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: AppTypography.body(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleWidgetSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Puzzle Widget',
          style: AppTypography.heading1(context),
        ),
        const SizedBox(height: 8),
        Text(
          'Solve puzzles from your goal images directly from your home screen',
          style: AppTypography.secondary(context),
        ),
        const SizedBox(height: 32),

        // Puzzle Widget Preview
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Widget Preview',
                  style: AppTypography.heading3(context),
                ),
                const SizedBox(height: 20),
                // Widget Mockup
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puzzle Challenge',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 4x4 grid preview
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: 16,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Puzzle Widget Features
        Text(
          'Features',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          context,
          icon: Icons.extension,
          title: 'Puzzle Preview',
          description: 'See a 4x4 grid preview of your current puzzle challenge on your home screen.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.touch_app_outlined,
          title: 'Quick Access',
          description: 'Tap the widget to open the puzzle game and continue solving from where you left off.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.sync,
          title: 'State Synchronization',
          description: 'Your puzzle progress syncs between the app and widget. Rearrange pieces in either place and see updates everywhere.',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.celebration_outlined,
          title: 'Goal Celebration',
          description: 'When you complete a puzzle, the widget shows a celebration message with your goal: "You are 1 step closer in reaching your goal: [Goal Title]".',
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          context,
          icon: Icons.save_outlined,
          title: 'Progress Persistence',
          description: 'Your puzzle state is saved automatically. Continue solving the same puzzle until you complete it or assign a new image.',
        ),
        const SizedBox(height: 32),

        // Puzzle Widget Setup Instructions
        Text(
          'How to Add the Puzzle Widget',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 16),
        // Android Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.android,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Android',
                      style: AppTypography.heading3(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStep(context, '1', 'Long-press your home screen.'),
                _buildStep(context, '2', 'Tap Widgets.'),
                _buildStep(context, '3', 'Find "Digital Vision Board".'),
                _buildStep(context, '4', 'Add "Puzzle Challenge" widget.'),
                _buildStep(context, '5', 'Tap the widget to open the puzzle game.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // iOS Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_iphone,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'iPhone / iPad',
                      style: AppTypography.heading3(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStep(context, '1', 'Long-press your home screen.'),
                _buildStep(context, '2', 'Tap the + button (top-left).'),
                _buildStep(context, '3', 'Search for "Digital Vision Board".'),
                _buildStep(context, '4', 'Add "Puzzle Challenge" widget.'),
                _buildStep(context, '5', 'Tap the widget to open the puzzle game.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
