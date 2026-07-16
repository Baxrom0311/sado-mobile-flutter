import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/core/utils/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Captured `HapticFeedbackType` arguments from each
  /// `HapticFeedback.vibrate` call. We assert on these to verify the
  /// utility maps semantic intents to the correct platform calls.
  final captured = <String>[];

  setUp(() {
    captured.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        captured.add(call.arguments as String? ?? '');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('light() triggers a single lightImpact', () async {
    await Haptics.light();
    expect(captured, ['HapticFeedbackType.lightImpact']);
  });

  test('medium() triggers a single mediumImpact', () async {
    await Haptics.medium();
    expect(captured, ['HapticFeedbackType.mediumImpact']);
  });

  test('heavy() triggers a single heavyImpact', () async {
    await Haptics.heavy();
    expect(captured, ['HapticFeedbackType.heavyImpact']);
  });

  test('selection() triggers a single selectionClick', () async {
    await Haptics.selection();
    expect(captured, ['HapticFeedbackType.selectionClick']);
  });

  test('success() fires light then medium in order', () async {
    await Haptics.success();
    expect(
      captured,
      ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact'],
    );
  });

  test('error() fires two heavy pulses', () async {
    await Haptics.error();
    expect(
      captured,
      ['HapticFeedbackType.heavyImpact', 'HapticFeedbackType.heavyImpact'],
    );
  });

  test('plugin errors are silently swallowed', () async {
    // Replace the handler with one that throws — Haptics must still
    // resolve normally so callers can use it unconditionally on web /
    // desktop where haptics aren't available.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      throw MissingPluginException('No platform impl');
    });

    await expectLater(Haptics.light(), completes);
    await expectLater(Haptics.success(), completes);
    await expectLater(Haptics.error(), completes);
  });
}
