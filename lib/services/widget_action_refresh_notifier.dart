import 'package:flutter/foundation.dart';

/// Broadcasts successful widget-originated habit actions to visible UI.
final class WidgetActionRefreshNotifier {
  WidgetActionRefreshNotifier._();

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static void bump() {
    version.value = version.value + 1;
  }
}
