import 'dart:convert';

import 'package:axis_y/core/services/glb_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// The GLB is cached to disk under a hash of its URL, so anything accepted here
/// is served from disk on every later retry. A wrong payload that gets accepted
/// breaks the viewer permanently, not just once.
void main() {
  group('isGlbHeader', () {
    test('accepts the binary glTF magic', () {
      expect(isGlbHeader(ascii.encode('glTF')), isTrue);
    });

    test('accepts a real header with the version and length bytes after it', () {
      expect(isGlbHeader([...ascii.encode('glTF'), 0x02, 0x00, 0x00, 0x00]), isTrue);
    });

    test('rejects an HTML page that arrived with a 200', () {
      // What a proxy interstitial or an error page looks like.
      expect(isGlbHeader(ascii.encode('<!DOCTYPE html>')), isFalse);
      expect(isGlbHeader(ascii.encode('<html')), isFalse);
    });

    test('rejects a JSON error body', () {
      expect(isGlbHeader(ascii.encode('{"detail":"not found"}')), isFalse);
    });

    test('rejects a truncated or empty download', () {
      expect(isGlbHeader(const []), isFalse);
      expect(isGlbHeader(ascii.encode('gl')), isFalse);
    });

    test('is case sensitive — the magic is exactly "glTF"', () {
      expect(isGlbHeader(ascii.encode('GLTF')), isFalse);
      expect(isGlbHeader(ascii.encode('gltf')), isFalse);
    });
  });
}
