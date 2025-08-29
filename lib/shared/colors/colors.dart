import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFFFF2056);

  // Muted Colors
  static const Color mutedForeground = Color(0xFF737373);

  // Custom Colors
  static const Color primaryForeground = Color(0xFFff6900);

  // Gradient
  static const LinearGradient customGradient = LinearGradient(
    colors: [
      primary,
      primaryForeground,
      primary,
      primary,
      primaryForeground,
      primary,
      primary,
      primary,
      primary,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
