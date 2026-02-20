import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:digital_vision_board/main.dart';

void main() {
  testWidgets('App boots and shows vision board', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DigitalVisionBoardApp());
    // Use pump() instead of pumpAndSettle() because the widget tree contains
    // repeating animations (e.g. pulse in bottom nav bar) and periodic timers
    // that prevent settling.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(Scaffold), findsWidgets);
  });
}
