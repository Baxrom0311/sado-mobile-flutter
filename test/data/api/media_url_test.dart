import 'package:flutter_test/flutter_test.dart';
import 'package:sado_mobile/data/api/api_client.dart';

void main() {
  group('resolveMediaUrl', () {
    test('returns null for null and empty input', () {
      expect(resolveMediaUrl(null), isNull);
      expect(resolveMediaUrl(''), isNull);
      expect(resolveMediaUrl('   '), isNull);
    });

    test('passes through fully qualified http(s) URLs unchanged', () {
      const url = 'https://cdn.example.com/audio/sample.m4a';
      expect(resolveMediaUrl(url), url);
      expect(
        resolveMediaUrl('http://example.com/x.m4a'),
        'http://example.com/x.m4a',
      );
    });

    test('strips the /api/v* suffix when prefixing relative root paths', () {
      // The default base URL is `https://...code.run/api/v1`.
      // Audio served from `/storage/...` lives at the host root, so the
      // resolver must strip the API suffix before prefixing.
      final url = resolveMediaUrl('/storage/exercises/abc.m4a');
      expect(url, isNotNull);
      expect(url!.endsWith('/storage/exercises/abc.m4a'), isTrue);
      expect(url.contains('/api/v1/storage'), isFalse);
    });

    test('joins relative paths (without leading slash) onto host root', () {
      final url = resolveMediaUrl('audio/foo.m4a');
      expect(url, isNotNull);
      expect(url!.endsWith('/audio/foo.m4a'), isTrue);
    });
  });
}
