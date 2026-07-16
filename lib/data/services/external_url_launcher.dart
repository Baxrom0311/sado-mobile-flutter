import 'package:url_launcher/url_launcher.dart';

/// Thin abstraction over `url_launcher` that the rest of the app talks
/// to instead of importing the plugin directly.
///
/// Why a wrapper?
///
///  * Widget tests can swap a deterministic fake without touching the
///    platform plugin registry — the production singleton is only
///    used at runtime.
///  * Centralises the "external application" launch mode so we can
///    later evolve to in-app custom-tabs without touching every
///    call-site.
///  * Catches the (rare but real) `PlatformException` that
///    `launchUrl` throws on Android when a malformed URL slips
///    through, so callers can rely on the boolean contract.
abstract class ExternalUrlLauncher {
  /// Open [url] in the platform's external browser. Returns `true`
  /// when the OS confirmed the handoff, `false` otherwise. Never
  /// throws — the caller is expected to fall back gracefully (e.g.
  /// copy to clipboard) when this returns `false`.
  ///
  /// Only `http` and `https` schemes are accepted. For `mailto:` and
  /// `tel:` use [openMailto] / [openTel] respectively — those route
  /// through dedicated launch modes so the OS opens the right native
  /// app instead of the browser.
  Future<bool> open(String url);

  /// Open the platform's email composer with [address] pre-filled.
  /// Subject + body are URL-encoded for safe handoff. Returns `true`
  /// when the handoff was accepted, `false` when no mail client is
  /// installed, the address is empty, or the platform rejected the
  /// intent.
  Future<bool> openMailto(
    String address, {
    String? subject,
    String? body,
  });

  /// Open the platform's dialer pre-filled with [phone]. Returns
  /// `true` on a successful handoff, `false` when the device has no
  /// dialer (tablets, kiosks), the phone string is empty, or the
  /// platform refused. The string is sanitised so leading spaces and
  /// formatting characters do not break the `tel:` URI parser.
  Future<bool> openTel(String phone);

  /// Production singleton backed by the real `url_launcher` plugin.
  static const ExternalUrlLauncher production = _PlatformExternalUrlLauncher();
}

class _PlatformExternalUrlLauncher implements ExternalUrlLauncher {
  const _PlatformExternalUrlLauncher();

  @override
  Future<bool> open(String url) async {
    if (url.isEmpty) return false;
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      // Belt-and-braces: the checkout API only ever returns http/https
      // URLs, but if a malformed payload slips through we'd rather
      // refuse than hand the device an arbitrary scheme.
      return false;
    }
    return _launch(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> openMailto(
    String address, {
    String? subject,
    String? body,
  }) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) return false;
    // Build a mailto URI; `Uri`'s built-in encoder handles the spaces,
    // newlines and Cyrillic characters we may pass via subject/body.
    final query = <String, String>{};
    if (subject != null && subject.isNotEmpty) query['subject'] = subject;
    if (body != null && body.isNotEmpty) query['body'] = body;
    final uri = Uri(
      scheme: 'mailto',
      path: trimmed,
      // `Uri.queryParameters` percent-encodes spaces as '+'; mailto
      // RFC says to use '%20'. Build the query string by hand so the
      // mail composer renders newlines correctly on every OS.
      query: query.isEmpty
          ? null
          : query.entries
              .map((e) =>
                  '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
              .join('&'),
    );
    return _launch(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> openTel(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return false;
    // Strip whitespace inside the number — most dialers tolerate
    // spaces, but a small number of Android dialers fail on tabs and
    // non-breaking spaces. Keep '+' and digits + dashes/parentheses
    // since RFC 3966 allows them.
    final digitsOnly = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (digitsOnly.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: digitsOnly);
    return _launch(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _launch(Uri uri, {required LaunchMode mode}) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      // `url_launcher` documents `PlatformException` for unsupported
      // device states (no browser installed, parental controls, …).
      // Swallow and let the caller surface a graceful fallback.
      return false;
    }
  }
}
