// Small convenience extensions on BuildContext to keep UI code tidy.

import 'package:flutter/material.dart';

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => mediaQuery.size;
  double get screenWidth => mediaQuery.size.width;
  double get screenHeight => mediaQuery.size.height;

  bool get isDarkMode => theme.brightness == Brightness.dark;

  void showSnackBarMessage(
      String message, {
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null
            ? SnackBarAction(
          label: actionLabel,
          onPressed: onAction ?? () {},
        )
            : null,
      ),
    );
  }
}
