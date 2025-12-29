import 'package:flutter/services.dart';

class HapticHelper {
  /// Light haptic feedback for general button taps
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium haptic feedback for switches and toggles
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy haptic feedback for important actions
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection haptic feedback
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate for errors
  static void error() {
    HapticFeedback.vibrate();
  }

  /// Light haptic for success
  static void success() {
    HapticFeedback.lightImpact();
  }
}
