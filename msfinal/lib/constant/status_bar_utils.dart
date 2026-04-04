import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Returns a [SystemUiOverlayStyle] that sets the status bar [color] and
/// icon [brightness].  Wrap your screen's [Scaffold] (or the topmost widget)
/// with [AnnotatedRegion<SystemUiOverlayStyle>] and pass the result of this
/// function as the value to control the status bar per-screen.
///
/// Example:
/// ```dart
/// AnnotatedRegion<SystemUiOverlayStyle>(
///   value: setStatusBar(Colors.white, Brightness.dark),
///   child: Scaffold(...),
/// )
/// ```
SystemUiOverlayStyle setStatusBar(Color color, Brightness iconBrightness) {
  return SystemUiOverlayStyle(
    statusBarColor: color,
    statusBarIconBrightness: iconBrightness, // Android
    // iOS uses statusBarBrightness (opposite semantics to iconBrightness)
    statusBarBrightness: iconBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
    systemStatusBarContrastEnforced: false,
  );
}
