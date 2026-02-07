/// Unified spacing constants for the journal editor.
class EditorSpacing {
  EditorSpacing._();
  
  /// Outer page container padding
  static const double pagePadding = 16.0;
  
  /// Content padding (horizontal margins for text content)
  static const double contentPadding = 24.0;
  
  /// Gap between major elements
  static const double elementGap = 16.0;
  
  /// Small gap between related elements
  static const double smallGap = 8.0;
  
  /// Tiny gap for tight spacing
  static const double tinyGap = 4.0;
  
  /// App bar padding
  static const double appBarPadding = 12.0;
  
  /// Bottom bar height
  static const double bottomBarHeight = 56.0;
  
  /// Border radius for cards and containers
  static const double cardRadius = 16.0;
  
  /// Border radius for small elements (chips, buttons)
  static const double smallRadius = 12.0;
  
  /// Paper line height (must match text line height exactly)
  static const double lineHeight = 28.0;
  
  /// Font size for body text
  static const double bodyFontSize = 15.0;
  
  /// Text height multiplier (lineHeight / bodyFontSize)
  static double get textHeight => lineHeight / bodyFontSize;
}
