import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sado_mobile/core/utils/permissions.dart';

void main() {
  group('MicPermission.resolveOutcome', () {
    test('granted maps to granted', () {
      expect(
        MicPermission.resolveOutcome(PermissionStatus.granted),
        MicPermissionOutcome.granted,
      );
    });

    test('limited maps to granted', () {
      expect(
        MicPermission.resolveOutcome(PermissionStatus.limited),
        MicPermissionOutcome.granted,
      );
    });

    test('denied maps to denied', () {
      expect(
        MicPermission.resolveOutcome(PermissionStatus.denied),
        MicPermissionOutcome.denied,
      );
    });

    test('permanentlyDenied maps to permanentlyDenied', () {
      expect(
        MicPermission.resolveOutcome(PermissionStatus.permanentlyDenied),
        MicPermissionOutcome.permanentlyDenied,
      );
    });

    test('restricted maps to permanentlyDenied (iOS parental controls)', () {
      expect(
        MicPermission.resolveOutcome(PermissionStatus.restricted),
        MicPermissionOutcome.permanentlyDenied,
      );
    });
  });
}
