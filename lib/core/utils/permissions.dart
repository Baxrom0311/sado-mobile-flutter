import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sado_mobile/l10n/app_localizations.dart';

import '../theme.dart';

/// Outcome of attempting to acquire microphone permission with the
/// rationale-aware UX in [ensureMicPermission].
enum MicPermissionOutcome {
  /// User has granted the permission. Recording can begin.
  granted,

  /// User declined the rationale dialog or denied the OS prompt. The UI
  /// should display a non-blocking hint but stay on the same screen.
  denied,

  /// Permission is permanently denied (Android "Don't ask again" or iOS
  /// after the first denial). The UI should surface the [openAppSettings]
  /// CTA so the user can re-enable it manually.
  permanentlyDenied,

  /// User cancelled the rationale dialog before the OS prompt was shown.
  cancelled,
}

/// Thin wrapper around [permission_handler] that adds a context-aware
/// rationale dialog before requesting microphone access — improves App
/// Store review acceptance and protects users from confusing OS prompts.
///
/// The implementation is split into a presenter + a pure [resolveOutcome]
/// helper so the mapping logic is unit-testable without a BuildContext.
class MicPermission {
  const MicPermission._();

  /// Pure mapping from a [PermissionStatus] to a [MicPermissionOutcome].
  /// Exposed for tests.
  static MicPermissionOutcome resolveOutcome(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return MicPermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermissionOutcome.permanentlyDenied;
    }
    return MicPermissionOutcome.denied;
  }

  /// Full permission flow:
  ///   1. If already granted → return granted.
  ///   2. If permanently denied → return permanentlyDenied (caller shows
  ///      a settings CTA).
  ///   3. Otherwise show a kid-friendly rationale dialog. If the user
  ///      cancels → return cancelled.
  ///   4. Request the OS permission and map the result.
  ///
  /// [requester] is injectable for tests; defaults to a real OS request.
  /// [statusReader] returns the current status; defaults to the platform.
  static Future<MicPermissionOutcome> ensureMicPermission(
    BuildContext context, {
    Future<PermissionStatus> Function()? statusReader,
    Future<PermissionStatus> Function()? requester,
  }) async {
    final readStatus =
        statusReader ?? () => Permission.microphone.status;
    final requestStatus =
        requester ?? () => Permission.microphone.request();

    final current = await readStatus();
    final mapped = resolveOutcome(current);
    if (mapped == MicPermissionOutcome.granted ||
        mapped == MicPermissionOutcome.permanentlyDenied) {
      return mapped;
    }

    if (!context.mounted) return MicPermissionOutcome.cancelled;
    final accepted = await _showRationaleDialog(context);
    if (accepted != true) return MicPermissionOutcome.cancelled;

    final result = await requestStatus();
    return resolveOutcome(result);
  }

  static Future<bool?> _showRationaleDialog(BuildContext context) {
    final l = L.of(context)!;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.mic_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l.microphoneRationaleTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l.microphoneRationaleBody,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.only(
          right: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l.notNow,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.allow),
          ),
        ],
      ),
    );
  }
}

/// Convenience function: opens the OS app settings page so the user can
/// re-enable a permanently-denied permission. Re-exported so callers don't
/// need to import [permission_handler] directly.
Future<bool> openMicPermissionSettings() => openAppSettings();
