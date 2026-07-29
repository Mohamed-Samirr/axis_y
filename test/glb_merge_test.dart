import 'dart:convert';
import 'dart:typed_data';

import 'package:axis_y/core/utils/glb_merge.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal but *referential* glTF: one mesh whose primitive names an accessor,
/// a bufferView and a material, the material naming a texture, the texture an
/// image and a sampler, and a node holding the mesh under a scene. Every index
/// in it has to move when it is merged as the overlay — which is exactly what
/// makes it worth merging in a test.
Uint8List _document({required String name, required int binLength}) {
  final json = <String, dynamic>{
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [1],
      },
    ],
    // Node 0 is deliberately unreferenced by the scene and node 1 holds it as a
    // child, so child remapping is exercised too.
    'nodes': [
      {'mesh': 0, 'name': '$name-child'},
      {
        'children': [0],
        'name': '$name-root',
      },
    ],
    'meshes': [
      {
        'name': name,
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'indices': 0,
            'material': 0,
          },
        ],
      },
    ],
    'materials': [
      {
        'name': name,
        'pbrMetallicRoughness': {
          'baseColorTexture': {'index': 0},
        },
      },
    ],
    'textures': [
      {'source': 0, 'sampler': 0},
    ],
    'images': [
      {'bufferView': 0, 'mimeType': 'image/png'},
    ],
    'samplers': [
      {'magFilter': 9729},
    ],
    'accessors': [
      {'bufferView': 0, 'componentType': 5126, 'count': 1, 'type': 'VEC3'},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': binLength},
    ],
    'buffers': [
      {'byteLength': binLength},
    ],
  };
  // Distinct byte values per document so the merged binary chunk can be checked
  // for both halves landing intact.
  final fill = name == 'body' ? 0xAA : 0xBB;
  return buildGlb(json, Uint8List.fromList(List.filled(binLength, fill)));
}

Map<String, dynamic> _jsonOf(Uint8List glb) => parseGlb(glb)!.json;

void main() {
  group('parseGlb / buildGlb round trip', () {
    test('reads back what it wrote', () {
      final bytes = _document(name: 'body', binLength: 12);
      final doc = parseGlb(bytes);

      expect(doc, isNotNull);
      expect(doc!.json['asset'], {'version': '2.0'});
      expect(doc.bin.length, 12);
      expect(doc.bin.every((b) => b == 0xAA), isTrue);
    });

    test('pads both chunks to a 4-byte boundary', () {
      // 7 bytes of payload forces padding in the binary chunk, and the JSON
      // chunk is whatever length it happens to be.
      final bytes = _document(name: 'body', binLength: 7);
      expect(bytes.length % 4, 0);
      expect(parseGlb(bytes)!.bin.length % 4, 0);
    });

    test('rejects bytes that are not a glTF binary', () {
      expect(parseGlb(Uint8List.fromList(utf8.encode('<html>404</html>'))), isNull);
      expect(parseGlb(Uint8List(0)), isNull);
      expect(parseGlb(Uint8List.fromList([0x67, 0x6C, 0x54])), isNull);
    });
  });

  group('mergeGlb', () {
    late Uint8List merged;
    late Map<String, dynamic> json;

    setUp(() {
      merged = mergeGlb(
        _document(name: 'body', binLength: 12),
        _document(name: 'garment', binLength: 8),
      )!;
      json = _jsonOf(merged);
    });

    test('produces a readable glTF binary', () {
      expect(parseGlb(merged), isNotNull);
      expect(merged.length % 4, 0);
    });

    test('keeps both models', () {
      expect((json['meshes'] as List).length, 2);
      expect((json['nodes'] as List).length, 4);
      expect((json['materials'] as List).length, 2);
      expect((json['textures'] as List).length, 2);
    });

    test('draws both from one scene', () {
      expect(json['scene'], 0);
      expect((json['scenes'] as List).length, 1);
      // Root of the body (index 1) and root of the garment (1 + 2 nodes before).
      expect((json['scenes'] as List).first['nodes'], [1, 3]);
    });

    test('shifts the overlay indices and leaves the base ones alone', () {
      final nodes = json['nodes'] as List;
      expect(nodes[0]['mesh'], 0, reason: 'base mesh index must not move');
      expect(nodes[1]['children'], [0]);
      expect(nodes[2]['mesh'], 1, reason: 'overlay mesh moved past the base one');
      expect(nodes[3]['children'], [2]);

      final primitives = (json['meshes'] as List)[1]['primitives'] as List;
      expect(primitives.first['attributes'], {'POSITION': 1});
      expect(primitives.first['indices'], 1);
      expect(primitives.first['material'], 1);

      expect((json['accessors'] as List)[1]['bufferView'], 1);
      expect((json['images'] as List)[1]['bufferView'], 1);
      expect((json['textures'] as List)[1], {'source': 1, 'sampler': 1});
      expect(
        (json['materials'] as List)[1]['pbrMetallicRoughness']['baseColorTexture'],
        {'index': 1},
      );
    });

    test('concatenates the binary chunks and points the overlay at its half', () {
      final bin = parseGlb(merged)!.bin;
      // 12 bytes of body, already 4-aligned, then 8 of garment.
      expect(bin.length, 20);
      expect(bin.sublist(0, 12).every((b) => b == 0xAA), isTrue);
      expect(bin.sublist(12, 20).every((b) => b == 0xBB), isTrue);

      final views = json['bufferViews'] as List;
      expect(views[0]['byteOffset'], 0);
      expect(views[1]['byteOffset'], 12);
      expect(views.every((v) => v['buffer'] == 0), isTrue);
      expect((json['buffers'] as List).single['byteLength'], 20);
      expect((json['buffers'] as List).length, 1);
    });

    test('pads the base chunk so the overlay stays 4-byte aligned', () {
      final odd = mergeGlb(
        _document(name: 'body', binLength: 6),
        _document(name: 'garment', binLength: 8),
      )!;
      final views = _jsonOf(odd)['bufferViews'] as List;
      // 6 rounds up to 8, not 6 — an accessor may not start off-alignment.
      expect(views[1]['byteOffset'], 8);
      expect(parseGlb(odd)!.bin.length, 16);
    });

    test('refuses a document whose bytes live outside the file', () {
      final external = parseGlb(_document(name: 'garment', binLength: 8))!;
      external.json['buffers'] = [
        {'byteLength': 8, 'uri': 'garment.bin'},
      ];
      final rebuilt = buildGlb(external.json, external.bin);

      expect(mergeGlb(_document(name: 'body', binLength: 8), rebuilt), isNull);
      expect(mergeGlb(rebuilt, _document(name: 'body', binLength: 8)), isNull);
    });

    test('refuses anything that is not a glTF binary', () {
      final html = Uint8List.fromList(utf8.encode('<html>not a mesh</html>'));
      expect(mergeGlb(_document(name: 'body', binLength: 8), html), isNull);
      expect(mergeGlb(html, _document(name: 'body', binLength: 8)), isNull);
    });

    test('leaves both models where they were authored by default', () {
      // No wrapper node, so nothing is scaled or moved.
      expect((json['nodes'] as List).length, 4);
      expect(
        (json['nodes'] as List).any((n) => (n as Map)['name'] == 'axis-y-fit'),
        isFalse,
      );
    });
  });

  group('sceneBounds', () {
    test('reads the box off the position accessors', () {
      final doc = parseGlb(_box(min: [-1, 0, -1], max: [1, 2, 1]))!;
      final bounds = sceneBounds(doc)!;

      expect(bounds.min, [-1.0, 0.0, -1.0]);
      expect(bounds.max, [1.0, 2.0, 1.0]);
      expect(bounds.height, 2.0);
      expect(bounds.width, 2.0);
      expect(bounds.centre(1), 1.0);
    });

    test('applies the node transform the mesh hangs under', () {
      final doc = parseGlb(_box(
        min: [-1, 0, -1],
        max: [1, 2, 1],
        scale: [2, 3, 2],
        translation: [10, 5, 0],
      ))!;
      final bounds = sceneBounds(doc)!;

      expect(bounds.min, [8.0, 5.0, -2.0]);
      expect(bounds.max, [12.0, 11.0, 2.0]);
      expect(bounds.height, 6.0);
    });

    test('is null when nothing declares bounds', () {
      final doc = parseGlb(_box(min: null, max: null))!;
      expect(sceneBounds(doc), isNull);
    });
  });

  group('fitTopToBody', () {
    // A 2-unit-tall body centred on the origin, and a garment ten times too big
    // sitting nowhere near it — the mismatch the fit exists to absorb.
    final body = const GlbBounds([-0.5, 0, -0.2], [0.5, 2, 0.2]);
    final garment = const GlbBounds([90, 100, 90], [110, 120, 110]);

    test('scales the garment to a top-sized fraction of the body', () {
      final fit = fitTopToBody(body, garment)!;
      // 0.36 of a 2-unit body over a 20-unit garment.
      expect(fit.scale, closeTo(0.036, 1e-9));
    });

    test('hangs it from the shoulders and centres it on the body', () {
      final fit = fitTopToBody(body, garment)!;
      final scale = fit.scale;

      // Top edge lands a neck below the crown.
      expect(fit.translation[1] + scale * garment.max[1], closeTo(2 - 0.26, 1e-9));
      // Centred on the body in the two horizontal axes.
      expect(fit.translation[0] + scale * garment.centre(0), closeTo(0, 1e-9));
      expect(fit.translation[2] + scale * garment.centre(2), closeTo(0, 1e-9));
    });

    test('declines a box with no extent rather than dividing by zero', () {
      const flat = GlbBounds([0, 0, 0], [0, 0, 0]);
      expect(fitTopToBody(body, flat), isNull);
      expect(fitTopToBody(flat, garment), isNull);
      expect(fitTopToBody(null, garment), isNull);
      expect(fitTopToBody(body, null), isNull);
    });
  });

  group('mergeGlb with fitOverlayToBase', () {
    test('parents the garment to a single scaling node', () {
      final merged = mergeGlb(
        _box(min: [-0.5, 0, -0.2], max: [0.5, 2, 0.2]),
        _box(min: [90, 100, 90], max: [110, 120, 110]),
        fitOverlayToBase: true,
      )!;
      final json = _jsonOf(merged);
      final nodes = json['nodes'] as List;

      final wrapper = nodes.last as Map<String, dynamic>;
      expect(wrapper['name'], 'axis-y-fit');
      expect(wrapper['children'], [1]);
      expect((wrapper['scale'] as List).first, closeTo(0.036, 1e-9));

      // The scene draws the body's root and the wrapper, not the raw garment.
      expect((json['scenes'] as List).single['nodes'], [0, nodes.length - 1]);
    });

    test('ends up with the garment sitting on the body', () {
      final merged = mergeGlb(
        _box(min: [-0.5, 0, -0.2], max: [0.5, 2, 0.2]),
        _box(min: [90, 100, 90], max: [110, 120, 110]),
        fitOverlayToBase: true,
      )!;
      // Re-measuring the merged document is the real check: the garment must now
      // live inside the body's box rather than a hundred units away from it.
      final bounds = sceneBounds(parseGlb(merged))!;
      expect(bounds.min[1], closeTo(0, 1e-9), reason: 'body still stands on zero');
      expect(bounds.max[1], closeTo(2, 1e-9), reason: 'garment must not tower over it');
      expect(bounds.max[0], lessThan(0.6));
      expect(bounds.min[0], greaterThan(-0.6));
    });

    test('falls back to a plain merge when the base has no bounds', () {
      final merged = mergeGlb(
        _box(min: null, max: null),
        _box(min: [90, 100, 90], max: [110, 120, 110]),
        fitOverlayToBase: true,
      )!;
      final nodes = _jsonOf(merged)['nodes'] as List;
      expect(nodes.any((n) => (n as Map)['name'] == 'axis-y-fit'), isFalse);
    });
  });
}

/// One box mesh under one node, with the accessor bounds a fit reads and an
/// optional node transform to apply to them.
Uint8List _box({
  required List<double>? min,
  required List<double>? max,
  List<double>? scale,
  List<double>? translation,
}) {
  final node = <String, dynamic>{'mesh': 0};
  if (scale != null) node['scale'] = scale;
  if (translation != null) node['translation'] = translation;

  final accessor = <String, dynamic>{
    'bufferView': 0,
    'componentType': 5126,
    'count': 8,
    'type': 'VEC3',
  };
  if (min != null) accessor['min'] = min;
  if (max != null) accessor['max'] = max;

  return buildGlb(<String, dynamic>{
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': [node],
    'meshes': [
      {
        'primitives': [
          {
            'attributes': {'POSITION': 0},
          },
        ],
      },
    ],
    'accessors': [accessor],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
    ],
    'buffers': [
      {'byteLength': 4},
    ],
  }, Uint8List.fromList([1, 2, 3, 4]));
}
