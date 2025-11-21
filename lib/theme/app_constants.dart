import 'package:flutter/material.dart';

/// App-wide constants for consistent UI/UX
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // Spacing
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 16.0;
  static const double spaceLarge = 24.0;
  static const double spaceXLarge = 32.0;
  static const double spaceXXLarge = 40.0;

  // Padding
  static const EdgeInsets paddingSmall = EdgeInsets.all(spaceSmall);
  static const EdgeInsets paddingMedium = EdgeInsets.all(spaceMedium);
  static const EdgeInsets paddingLarge = EdgeInsets.all(spaceLarge);
  
  static const EdgeInsets paddingHorizontalSmall = EdgeInsets.symmetric(horizontal: spaceSmall);
  static const EdgeInsets paddingHorizontalMedium = EdgeInsets.symmetric(horizontal: spaceMedium);
  static const EdgeInsets paddingHorizontalLarge = EdgeInsets.symmetric(horizontal: spaceLarge);
  
  static const EdgeInsets paddingVerticalSmall = EdgeInsets.symmetric(vertical: spaceSmall);
  static const EdgeInsets paddingVerticalMedium = EdgeInsets.symmetric(vertical: spaceMedium);
  static const EdgeInsets paddingVerticalLarge = EdgeInsets.symmetric(vertical: spaceLarge);

  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeNormal = 16.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;
  static const double fontSizeTitle = 28.0;

  // Elevation (for cards, buttons, etc.)
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Button Heights
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 52.0;

  // Border Widths
  static const double borderWidthThin = 1.0;
  static const double borderWidthMedium = 2.0;
  static const double borderWidthThick = 3.0;

  // Dialog Constraints
  static const double dialogMaxWidth = 400.0;
  static const double dialogMinWidth = 280.0;

  // Card Constraints
  static const double cardMaxWidth = 600.0;
}
