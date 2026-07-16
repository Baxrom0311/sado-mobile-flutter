import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sado_mobile/data/services/external_url_launcher.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Mock implementation of the `url_launcher` platform interface so
/// the tests can exercise the production [ExternalUrlLauncher]
/// without bouncing into an actual browser. Uses
/// [MockPlatformInterfaceMixin] so `PlatformInterface.verify` accepts
/// the mock instance.
class _RecordingPlatform extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  String? lastUrl;
  bool nextResult = true;
  Object? throwOn;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    final t = throwOn;
    if (t != null) throw t;
    return nextResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingPlatform platform;

  setUp(() {
    platform = _RecordingPlatform();
    UrlLauncherPlatform.instance = platform;
  });

  test('open returns false for an empty URL without touching the platform',
      () async {
    final ok = await ExternalUrlLauncher.production.open('');
    expect(ok, isFalse);
    expect(platform.lastUrl, isNull);
  });

  test('open returns false for a non-http(s) scheme', () async {
    final ok = await ExternalUrlLauncher.production.open(
      'mailto:hi@sado.uz',
    );
    expect(ok, isFalse);
    expect(platform.lastUrl, isNull);
  });

  test('open hands an https URL to the platform launcher', () async {
    platform.nextResult = true;
    final ok = await ExternalUrlLauncher.production.open(
      'https://checkout.paycom.uz/abc',
    );
    expect(ok, isTrue);
    expect(platform.lastUrl, 'https://checkout.paycom.uz/abc');
  });

  test('open returns false when the platform reports it could not launch',
      () async {
    platform.nextResult = false;
    final ok = await ExternalUrlLauncher.production.open(
      'https://my.click.uz/checkout/x',
    );
    expect(ok, isFalse);
    expect(platform.lastUrl, 'https://my.click.uz/checkout/x');
  });

  test('open swallows PlatformException and returns false', () async {
    platform.throwOn = PlatformException(code: 'no_browser');
    final ok = await ExternalUrlLauncher.production.open(
      'https://checkout.paycom.uz/lock',
    );
    expect(ok, isFalse);
  });
}
