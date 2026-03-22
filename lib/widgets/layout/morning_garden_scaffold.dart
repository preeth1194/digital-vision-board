import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

/// Full-screen shell: Morning Garden page background + transparent [Scaffold].
///
/// Use [minimalPageBackground] `true` (default) for the flat onboarding-style
/// canvas. Set to `false` for the subtle textured [AppColors.skyDecoration].
class MorningGardenScaffold extends StatelessWidget {
  const MorningGardenScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.minimalPageBackground = true,
    this.extendBodyBehindAppBar = false,
    this.wrapBodyInSafeArea = true,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;

  /// When `true`, uses [AppColors.pageBackgroundDecoration] with flat mist /
  /// night soil (no texture overlay).
  final bool minimalPageBackground;

  final bool extendBodyBehindAppBar;

  /// When `true`, wraps [body] in [SafeArea]. Set `false` when the screen
  /// manages insets itself (e.g. legal consent with a custom [SafeArea]).
  final bool wrapBodyInSafeArea;

  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final innerBody = wrapBodyInSafeArea ? SafeArea(child: body) : body;

    return Container(
      decoration: AppColors.pageBackgroundDecoration(
        isDark: isDark,
        minimal: minimalPageBackground,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: innerBody,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        drawer: drawer,
        endDrawer: endDrawer,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      ),
    );
  }
}
