import 'dart:ui';

extension WithValues on Color {
  /// Returns a new Color with the same red, green, and blue values,
  /// but with the provided alpha value (0.0 to 1.0).
  Color withValues({required double alpha}) {
    return Color.fromRGBO(red, green, blue, alpha);
  }
}
