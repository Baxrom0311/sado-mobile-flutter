import 'package:flutter/material.dart';

/// App-wide [ScaffoldMessengerState] key. Used so global event listeners
/// (e.g. the online-recovery handler in `main.dart` that flushes pending
/// audio uploads) can surface a snackbar regardless of which screen the
/// user is currently on.
///
/// Anything reaching for this key should null-check `currentState` —
/// during the very first frame and after a hot-restart it can briefly be
/// null. Tests that don't wire up `MaterialApp.scaffoldMessengerKey`
/// should never hit it.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Helper that fires-and-forgets a snackbar through [appMessengerKey].
/// No-op when the key has not yet been mounted (e.g. before the first
/// frame, or in pure-Dart unit tests).
void showAppSnackBar(SnackBar bar) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  // Hide any in-flight snackbar so quick successive events don't queue
  // up and feel laggy ("Hammasi yuborildi" stacking on top of "Sessiya
  // tugadi" would be confusing).
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(bar);
}
