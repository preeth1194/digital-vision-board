import 'package:digital_vision_board/models/habit_item.dart';
import 'package:digital_vision_board/widgets/insights/insights_habit_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _habits = [
  const HabitItem(id: 'a', name: 'Morning Run'),
  const HabitItem(id: 'b', name: 'Read'),
];

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('InsightsHabitChips', () {
    testWidgets('renders All chip and one chip per habit', (tester) async {
      await tester.pumpWidget(_wrap(
        InsightsHabitChips(
          habits: _habits,
          selectedId: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('tapping habit chip calls onChanged with habit id', (tester) async {
      String? received;
      await tester.pumpWidget(_wrap(
        InsightsHabitChips(
          habits: _habits,
          selectedId: null,
          onChanged: (id) => received = id,
        ),
      ));
      await tester.tap(find.text('Morning Run'));
      await tester.pump();
      expect(received, 'a');
    });

    testWidgets('tapping already-selected habit chip deselects', (tester) async {
      String? received = 'sentinel';
      await tester.pumpWidget(_wrap(
        InsightsHabitChips(
          habits: _habits,
          selectedId: 'a',
          onChanged: (id) => received = id,
        ),
      ));
      await tester.tap(find.text('Morning Run'));
      await tester.pump();
      expect(received, isNull);
    });

    testWidgets('tapping All when already selected is a no-op', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(_wrap(
        InsightsHabitChips(
          habits: _habits,
          selectedId: null,
          onChanged: (_) => callCount++,
        ),
      ));
      await tester.tap(find.text('All'));
      await tester.pump();
      expect(callCount, 0);
    });
  });
}
