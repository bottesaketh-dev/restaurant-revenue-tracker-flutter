import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized helper for showing friendly, auto-dismissing feedback toasts
/// (success/error) across the app, replacing plain default SnackBars.
class AppNotifier {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle,
      iconColor: Colors.green.shade600,
      backgroundColor: Colors.green.shade50,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error,
      iconColor: AppTheme.error,
      backgroundColor: AppTheme.error.withValues(alpha: 0.08),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: backgroundColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: iconColor.withValues(alpha: 0.3)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
