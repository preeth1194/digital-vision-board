import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/reward_ads_coin_card.dart';

void main() {
  testWidgets('shows Rewards label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardAdsCoinCard())),
    );
    await tester.pump();
    expect(find.text('Rewards'), findsOneWidget);
  });

  testWidgets('shows Watch button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardAdsCoinCard())),
    );
    await tester.pump();
    expect(find.text('Watch'), findsOneWidget);
  });

  testWidgets('does NOT show large 0/3 counter text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardAdsCoinCard())),
    );
    await tester.pump();
    final heading1Texts = tester.widgetList<Text>(find.byType(Text))
        .where((t) => t.data != null && RegExp(r'^\d/\d$').hasMatch(t.data!))
        .toList();
    expect(heading1Texts, isEmpty);
  });
}
