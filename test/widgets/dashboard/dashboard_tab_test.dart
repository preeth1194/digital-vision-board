import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:digital_vision_board/widgets/dashboard/dashboard_tab.dart';
import 'package:digital_vision_board/widgets/dashboard/mood_tracker_card.dart';
import 'package:digital_vision_board/widgets/dashboard/insights_summary_card.dart';
import 'package:digital_vision_board/widgets/dashboard/water_intake_card.dart';
import 'package:digital_vision_board/widgets/dashboard/reward_ads_coin_card.dart';
import 'package:digital_vision_board/widgets/dashboard/puzzle_summary_card.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  Widget buildTab() => MaterialApp(
        home: Scaffold(
          body: DashboardTab(
            boards: const [],
            activeBoardId: null,
            routines: const [],
            activeRoutineId: null,
            onCreateBoard: () {},
            onOpenEditor: (_) {},
            onOpenViewer: (_) {},
            onDeleteBoard: (_) {},
          ),
        ),
      );

  testWidgets('renders all 5 card types', (tester) async {
    await tester.pumpWidget(buildTab());
    // Do not pump() — avoids async service calls that require extra setup
    expect(find.byType(MoodTrackerCard), findsOneWidget);
    expect(find.byType(InsightsSummaryCard), findsOneWidget);
    expect(find.byType(WaterIntakeCard), findsOneWidget);
    expect(find.byType(RewardAdsCoinCard), findsOneWidget);
    expect(find.byType(PuzzleSummaryCard), findsOneWidget);
  });

  testWidgets('Insights and Water are in a fixed-height SizedBox(160)', (tester) async {
    await tester.pumpWidget(buildTab());
    final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final has160 = boxes.any((b) => b.height == 160.0);
    expect(has160, isTrue);
  });

  testWidgets('no IntrinsicHeight widget in the tree', (tester) async {
    await tester.pumpWidget(buildTab());
    expect(find.byType(IntrinsicHeight), findsNothing);
  });
}
