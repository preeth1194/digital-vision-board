import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/mood_tracker_card.dart';

void main() {
  testWidgets('loading state: pill is hidden, no Log or Edit text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodTrackerCard())),
    );
    // Don't pump async — widget is in loading state before getMoodsForRange completes
    expect(find.text('Log →'), findsNothing);
    expect(find.text('Edit →'), findsNothing);
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('card is tappable — InkWell is present in the widget tree', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodTrackerCard())),
    );
    final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
    expect(inkWells.isNotEmpty, isTrue);
  });

  testWidgets('shows Mood label text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodTrackerCard())),
    );
    expect(find.text('Mood'), findsOneWidget);
  });
}
