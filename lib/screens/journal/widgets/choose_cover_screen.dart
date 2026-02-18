import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/grid/image_source_sheet.dart';

/// Cover style with color and optional pattern/texture.
class BookCoverStyle {
  final String name;
  final int primaryColor;
  final int? secondaryColor;
  final bool hasPattern;
  final bool isCustom;

  const BookCoverStyle({
    required this.name,
    required this.primaryColor,
    this.secondaryColor,
    this.hasPattern = false,
    this.isCustom = false,
  });
}

/// Screen for choosing a book cover when creating a new journal book.
class ChooseCoverScreen extends StatefulWidget {
  const ChooseCoverScreen({super.key});

  /// Show the cover selection screen and return the selected cover color, name, and optional image path.
  static Future<({int color, String name, String? imagePath})?> show(BuildContext context) async {
    return Navigator.of(context).push<({int color, String name, String? imagePath})>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChooseCoverScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<ChooseCoverScreen> createState() => _ChooseCoverScreenState();
}

class _ChooseCoverScreenState extends State<ChooseCoverScreen> {
  static const List<BookCoverStyle> _coverStyles = [
    BookCoverStyle(name: 'Coral', primaryColor: AppColors.coverCoral),
    BookCoverStyle(name: 'Sunset', primaryColor: AppColors.coverOrange),
    BookCoverStyle(name: 'Fiji', primaryColor: AppColors.coverFijiPrimary, secondaryColor: AppColors.coverFijiSecondary, hasPattern: true),
    BookCoverStyle(name: 'Forest', primaryColor: AppColors.coverTeal),
    BookCoverStyle(name: 'Lavender', primaryColor: AppColors.coverPurple),
    BookCoverStyle(name: 'Rose', primaryColor: AppColors.coverPink),
    BookCoverStyle(name: 'Midnight', primaryColor: AppColors.coverMidnightPrimary, secondaryColor: AppColors.coverMidnightSecondary, hasPattern: true),
    BookCoverStyle(name: 'Custom', primaryColor: AppColors.coverCustomGrey, isCustom: true),
  ];

  int _selectedIndex = 2; // Default to Fiji (like reference)
  late PageController _pageController;
  String? _customImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _selectedIndex,
      viewportFraction: 0.65,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  BookCoverStyle get _selectedStyle => _coverStyles[_selectedIndex];

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() {
        _customImagePath = picked.path;
      });
    }
  }

  void _onNext() {
    Navigator.of(context).pop((
      color: _selectedStyle.primaryColor,
      name: _selectedStyle.isCustom && _customImagePath != null ? 'Journal' : _selectedStyle.name,
      imagePath: _selectedStyle.isCustom ? _customImagePath : null,
    ));
  }

  String get _displayName {
    if (_selectedStyle.isCustom && _customImagePath != null) {
      return 'Custom Image';
    }
    return _selectedStyle.name;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: colorScheme.onSurface,
                    ),
                    tooltip: 'Cancel',
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'First things first.',
              style: AppTypography.heading1(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a cover.',
              style: AppTypography.heading1(context),
            ),
            const SizedBox(height: 40),
            // Cover name
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _displayName,
                key: ValueKey(_displayName),
                style: AppTypography.secondary(context),
              ),
            ),
            const SizedBox(height: 16),
            // Cover carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _coverStyles.length,
                onPageChanged: (index) async {
                  setState(() => _selectedIndex = index);
                  // Auto-open image picker when custom is selected and no image yet
                  if (_coverStyles[index].isCustom && _customImagePath == null) {
                    await _pickImage();
                  }
                },
                itemBuilder: (context, index) {
                  final style = _coverStyles[index];
                  final isSelected = index == _selectedIndex;
                  return AnimatedScale(
                    scale: isSelected ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: isSelected ? 1.0 : 0.6,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: GestureDetector(
                          onTap: style.isCustom ? _pickImage : null,
                          child: _BookCoverPreview(
                            style: style,
                            width: size.width * 0.5,
                            height: size.height * 0.32,
                            customImagePath: style.isCustom ? _customImagePath : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Color dots
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_coverStyles.length, (index) {
                  final style = _coverStyles[index];
                  final isSelected = index == _selectedIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: isSelected ? 36 : 28,
                      height: isSelected ? 36 : 28,
                      decoration: BoxDecoration(
                        color: style.isCustom && _customImagePath != null
                            ? null
                            : Color(style.primaryColor),
                        image: style.isCustom && _customImagePath != null
                            ? DecorationImage(
                                image: FileImage(File(_customImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : colorScheme.primary)
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(style.primaryColor).withOpacity(0.4),
                            blurRadius: isSelected ? 12 : 6,
                            spreadRadius: isSelected ? 2 : 0,
                          ),
                        ],
                      ),
                      child: style.isCustom && _customImagePath == null
                          ? Icon(
                              Icons.add_photo_alternate_outlined,
                              size: isSelected ? 18 : 14,
                              color: Colors.white.withOpacity(0.8),
                            )
                          : style.hasPattern && isSelected
                              ? Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.8),
                                )
                              : null,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),
            // Next button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedStyle.isCustom && _customImagePath == null
                      ? null
                      : _onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'NEXT',
                    style: AppTypography.button(context).copyWith(
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Preview of a book cover with optional pattern or custom image.
class _BookCoverPreview extends StatelessWidget {
  final BookCoverStyle style;
  final double width;
  final double height;
  final String? customImagePath;

  const _BookCoverPreview({
    required this.style,
    required this.width,
    required this.height,
    this.customImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = Color(style.primaryColor);
    final secondaryColor = style.secondaryColor != null
        ? Color(style.secondaryColor!)
        : HSLColor.fromColor(primaryColor)
            .withLightness((HSLColor.fromColor(primaryColor).lightness - 0.1).clamp(0.0, 1.0))
            .toColor();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(4, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Background - either custom image or gradient
            if (style.isCustom && customImagePath != null)
              Positioned.fill(
                child: Image.file(
                  File(customImagePath!),
                  fit: BoxFit.cover,
                ),
              )
            else if (style.isCustom)
              // Placeholder for custom image
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to upload',
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Base gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      secondaryColor,
                    ],
                  ),
                ),
              ),
            // Pattern overlay for styled covers
            if (style.hasPattern && !style.isCustom) ...[
              // Abstract shapes
              Positioned(
                top: -20,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              // Brush stroke effect
              Positioned(
                top: height * 0.3,
                right: -10,
                child: Transform.rotate(
                  angle: -0.3,
                  child: Container(
                    width: width * 0.6,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                ),
              ),
            ],
            // Spine effect on left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Page edges on right
            Positioned(
              right: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
