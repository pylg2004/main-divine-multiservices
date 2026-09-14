import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Affiche des SnackBars cohérentes dans toute l'app via une seule clé
/// globale, pour ne pas dépendre du BuildContext de chaque écran.
class ToastService {
  ToastService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(String message) => _show(message, AppColors.success);
  static void error(String message) => _show(message, AppColors.danger);
  static void info(String message) => _show(message, AppColors.info);

  static void _show(String message, Color color) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
