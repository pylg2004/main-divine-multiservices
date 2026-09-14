import 'package:flutter/material.dart';

/// Couleurs globales de l'application. Les couleurs par poste de travail
/// vivent sur [Workstation] (voir shared/permissions/workstation.dart) —
/// celles-ci ne sont que la palette neutre partagée par toute l'UI.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2D6CDF);
  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE3E5E8);

  static const Color success = Color(0xFF1E9E5A);
  static const Color warning = Color(0xFFE0A82E);
  static const Color danger = Color(0xFFD64545);
  static const Color info = Color(0xFF2D6CDF);

  // Postes de travail (voir aussi Workstation.color)
  static const Color posGreen = Color(0xFF0F5A42);
  static const Color beautyPink = Color(0xFFD4788F);
  static const Color adminBlue = Color(0xFF2D6CDF);
}
