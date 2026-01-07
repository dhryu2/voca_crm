import 'dart:ui';

/// Modern CRM Design System
/// Inspired by HubSpot, Salesforce, Zoho, Trello, Asana, Notion
class ThemeColor {
  // ===== Primary Brand Colors =====
  // Modern blue - trustworthy, professional (Salesforce/Trello inspired)
  static const Color primary = Color(0xFF1C06B1);
  static const Color primaryLight = Color(0xFF1C06B1);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primarySurface = Color(
    0xFFEFF6FF,
  ); // Very light blue for backgrounds

  // Legacy support
  static const Color primaryPurple = primary;
  static const Color primaryVariant = primaryDark;

  // ===== Secondary / Accent Colors =====
  // Teal/Cyan - modern, fresh accent (HubSpot inspired)
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentLight = Color(0xFF22D3EE);
  static const Color accentDark = Color(0xFF0891B2);
  static const Color accentSurface = Color(0xFFECFEFF);

  // Legacy support
  static const Color accentPink = accent;
  static const Color accentSecondary = accentDark;

  // ===== Semantic Colors =====
  static const Color success = Color(0xFF10B981); // Green
  static const Color successLight = Color(0xFF34D399);
  static const Color successSurface = Color(0xFFECFDF5);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningSurface = Color(0xFFFFFBEB);

  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorSurface = Color(0xFFFEF2F2);

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ===== Neutral Colors (Notion/Asana inspired) =====
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  // ===== Background Colors =====
  static const Color background = Color(
    0xFFF9FAFB,
  ); // Light gray (Notion inspired)
  static const Color backgroundSecondary = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF); // White cards
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Legacy support
  static const Color backgroundStart = neutral50;
  static const Color backgroundEnd = neutral100;
  static const Color whiteColor = Color(0xFFFFFFFF);

  // ===== Text Colors =====
  static const Color textPrimary = Color(0xFF1F2937); // Dark gray
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ===== Border Colors =====
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderFocus = primary;

  // ===== Shadow Colors =====
  static const Color shadowLight = Color(0x0A000000); // 4% opacity
  static const Color shadowMedium = Color(0x14000000); // 8% opacity
  static const Color shadowDark = Color(0x1F000000); // 12% opacity

  // ===== Gradient Colors =====
  static const List<Color> primaryGradient = [
    Color(0xFF2563EB),
    Color(0xFF3B82F6),
  ];

  static const List<Color> accentGradient = [
    Color(0xFF06B6D4),
    Color(0xFF22D3EE),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF1F2937),
    Color(0xFF374151),
  ];

  // Legacy support
  static const Color lightPurple = primarySurface;
  static const Color mediumPurple = primaryLight;
  static const Color darkerMediumPurple = primary;
}
