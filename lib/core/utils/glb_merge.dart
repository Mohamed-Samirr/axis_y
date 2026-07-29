import 'dart:convert';
import 'dart:typed_data';

/// Binary glTF container constants (glTF 2.0 spec §4.4).
const int _magic = 0x46546C67; //     'glTF'
const int _chunkJson = 0x4E4F534A; // 'JSON'
const int _chunkBin = 0x004E4942; //  'BIN\0'

/// A parsed `.glb`: its glTF JSON and the single binary chunk behind it.
class GlbDocument {
  final Map<String, dynamic> json;
  final Uint8List bin;
  const GlbDocument(this.json, this.bin);
}

/// Reads a binary glTF, or null when [bytes] is not one this can work with.
GlbDocument? parseGlb(Uint8List bytes) {
  try {
    if (bytes.length < 12) return null;
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.little) != _magic) return null;
    if (data.getUint32(4, Endian.little) != 2) return null;

    // A truncated file still declares its intended length; trust whichever is
    // smaller so a bad read cannot walk off the end of the buffer.
    final declared = data.getUint32(8, Endian.little);
    final end = declared < bytes.length ? declared : bytes.length;

    Map<String, dynamic>? json;
    var bin = Uint8List(0);
    var offset = 12;
    while (offset + 8 <= end) {
      final length = data.getUint32(offset, Endian.little);
      final type = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + length > end) return null;
      // `chunkLength` already includes the chunk's own 4-byte padding, so this
      // lands on the next chunk header exactly.
      if (type == _chunkJson && json == null) {
        json = jsonDecode(utf8.decode(Uint8List.sublistView(bytes, start, start + length)))
            as Map<String, dynamic>;
      } else if (type == _chunkBin && bin.isEmpty) {
        bin = Uint8List.fromList(Uint8List.sublistView(bytes, start, start + length));
      }
      offset = start + length;
    }
    return json == null ? null : GlbDocument(json, bin);
  } catch (_) {
    return null;
  }
}

/// Writes [json] and [bin] back out as a binary glTF.
Uint8List buildGlb(Map<String, dynamic> json, Uint8List bin) {
  final jsonBytes = utf8.encode(jsonEncode(json));
  final jsonLength = _padded(jsonBytes.length);
  final binLength = _padded(bin.length);
  final total = 12 + 8 + jsonLength + (bin.isEmpty ? 0 : 8 + binLength);

  final out = Uint8List(total);
  final view = ByteData.sublistView(out);
  view.setUint32(0, _magic, Endian.little);
  view.setUint32(4, 2, Endian.little);
  view.setUint32(8, total, Endian.little);

  view.setUint32(12, jsonLength, Endian.little);
  view.setUint32(16, _chunkJson, Endian.little);
  out.setRange(20, 20 + jsonBytes.length, jsonBytes);
  // The JSON chunk pads with spaces, the binary one with zeroes (spec §4.4.1).
  out.fillRange(20 + jsonBytes.length, 20 + jsonLength, 0x20);

  if (bin.isNotEmpty) {
    final at = 20 + jsonLength;
    view.setUint32(at, binLength, Endian.little);
    view.setUint32(at + 4, _chunkBin, Endian.little);
    out.setRange(at + 8, at + 8 + bin.length, bin);
  }
  return out;
}

/// Composes [overlayBytes] into [baseBytes] as one `.glb` holding both.
///
/// Every glTF cross-reference is an index into a top-level array, so merging is
/// a matter of concatenating those arrays and shifting the overlay's indices by
/// how long the base's already were. The two binary chunks are concatenated the
/// same way and the overlay's buffer views are moved along by that offset.
///
/// By default neither model is transformed: they are dropped into one scene
/// exactly where each was authored, which is what two meshes out of the same
/// pipeline need and the only faithful thing to do. Pass [fitOverlayToBase] for
/// the case where they demonstrably do not share a space — see [fitTopToBody].
///
/// Returns null for anything it cannot compose faithfully — a document with
/// external buffers, or bytes that are not a glTF 2.0 binary at all. Callers
/// fall back to showing a single mesh rather than a broken one.
Uint8List? mergeGlb(
  Uint8List baseBytes,
  Uint8List overlayBytes, {
  bool fitOverlayToBase = false,
}) {
  try {
    final base = parseGlb(baseBytes);
    final overlay = parseGlb(overlayBytes);
    if (base == null || overlay == null) return null;
    // Both must keep their bytes in the BIN chunk. A buffer with a `uri` lives
    // in a file this has never seen, and there is nothing to concatenate.
    if (!_hasSingleEmbeddedBuffer(base.json) || !_hasSingleEmbeddedBuffer(overlay.json)) {
      return null;
    }

    final offsets = _Offsets(base.json);
    final binOffset = _padded(base.bin.length);

    // Both root sets have to be read *before* the walk below, which rewrites the
    // child lists they are derived from. Only the overlay's move.
    final baseRoots = _sceneNodes(base.json);
    final overlayRoots = [for (final i in _sceneNodes(overlay.json)) i + offsets.nodes];
    // Same story for the bounds: they are read through the original indices.
    final fit = fitOverlayToBase
        ? fitTopToBody(sceneBounds(base), sceneBounds(overlay))
        : null;

    _remap(overlay.json, offsets, binOffset);

    final bin = Uint8List(binOffset + overlay.bin.length)
      ..setRange(0, base.bin.length, base.bin)
      ..setRange(binOffset, binOffset + overlay.bin.length, overlay.bin);

    final merged = <String, dynamic>{...base.json};
    for (final key in _indexedArrays) {
      final joined = [..._list(base.json, key), ..._list(overlay.json, key)];
      if (joined.isNotEmpty) merged[key] = joined;
    }
    merged['buffers'] = [
      <String, dynamic>{'byteLength': bin.length},
    ];

    // One scene holding both models' roots, whichever scene each called default.
    // A fit is applied by parenting the overlay's roots to a single new node
    // rather than by touching their own transforms, so each model keeps the
    // transform it was authored with.
    var roots = [...baseRoots, ...overlayRoots];
    if (fit != null) {
      final nodes = (merged['nodes'] as List?) ?? <dynamic>[];
      nodes.add(<String, dynamic>{
        'name': 'axis-y-fit',
        'children': overlayRoots,
        'scale': [fit.scale, fit.scale, fit.scale],
        'translation': fit.translation,
      });
      merged['nodes'] = nodes;
      roots = [...baseRoots, nodes.length - 1];
    }
    merged['scenes'] = [
      <String, dynamic>{'nodes': roots},
    ];
    merged['scene'] = 0;
    merged['asset'] = base.json['asset'] ?? <String, dynamic>{'version': '2.0'};
    _union(merged, base.json, overlay.json, 'extensionsUsed');
    _union(merged, base.json, overlay.json, 'extensionsRequired');

    return buildGlb(merged, bin);
  } catch (_) {
    return null;
  }
}

/// The axis-aligned box a document's default scene occupies, in its own space.
class GlbBounds {
  final List<double> min;
  final List<double> max;
  const GlbBounds(this.min, this.max);

  double get width => max[0] - min[0];
  double get height => max[1] - min[1];
  double get depth => max[2] - min[2];
  double centre(int axis) => (min[axis] + max[axis]) / 2;

  /// A box with no extent at all — an empty scene, or meshes whose accessors
  /// declared no bounds — is not something to scale against.
  bool get isDegenerate => !(height > 0) || !(width > 0);
}

/// Bounds of everything [doc]'s default scene draws.
///
/// Read straight off the position accessors' `min`/`max`, which glTF requires
/// on `POSITION` (spec §5.1.1) — so this never has to decode the binary chunk.
GlbBounds? sceneBounds(GlbDocument? doc) {
  if (doc == null) return null;
  final json = doc.json;
  final nodes = _list(json, 'nodes');
  final min = <double>[double.infinity, double.infinity, double.infinity];
  final max = <double>[double.negativeInfinity, double.negativeInfinity, double.negativeInfinity];
  var found = false;

  void visit(int index, List<double> parent, Set<int> seen) {
    // A malformed file can name a node as its own descendant; that is a hang,
    // not a mesh, so stop at the first repeat.
    if (index < 0 || index >= nodes.length || !seen.add(index)) return;
    final node = nodes[index];
    if (node is! Map<String, dynamic>) return;
    final world = _multiply(parent, _localMatrix(node));

    final mesh = (node['mesh'] as num?)?.toInt();
    if (mesh != null) {
      final meshes = _list(json, 'meshes');
      if (mesh >= 0 && mesh < meshes.length) {
        for (final primitive in _maps(meshes[mesh] as Map<String, dynamic>, 'primitives')) {
          final attributes = primitive['attributes'] as Map<String, dynamic>?;
          final position = (attributes?['POSITION'] as num?)?.toInt();
          if (position == null) continue;
          final accessors = _list(json, 'accessors');
          if (position < 0 || position >= accessors.length) continue;
          final accessor = accessors[position] as Map<String, dynamic>;
          final lo = _vec3(accessor['min']);
          final hi = _vec3(accessor['max']);
          if (lo == null || hi == null) continue;
          // Under rotation the box's own corners are what move, so all eight of
          // them have to be transformed — not just the two extremes.
          for (var corner = 0; corner < 8; corner++) {
            final point = _transform(world, [
              (corner & 1) == 0 ? lo[0] : hi[0],
              (corner & 2) == 0 ? lo[1] : hi[1],
              (corner & 4) == 0 ? lo[2] : hi[2],
            ]);
            for (var axis = 0; axis < 3; axis++) {
              if (point[axis] < min[axis]) min[axis] = point[axis];
              if (point[axis] > max[axis]) max[axis] = point[axis];
            }
          }
          found = true;
        }
      }
    }
    for (final child in _list(node, 'children')) {
      visit((child as num).toInt(), world, seen);
    }
  }

  for (final root in _sceneNodes(json)) {
    visit(root, _identity(), <int>{});
  }
  return found ? GlbBounds(min, max) : null;
}

/// A uniform scale and offset that make [garment] look worn on [body].
///
/// This exists only for the case where the two meshes came from different
/// places — the morph engine's garment against the user's own scanned avatar —
/// and so share no units or origin. It is a *visual* placement, not a fitting
/// one: the verdict on screen comes from the backend and is unaffected by
/// anything here.
///
/// A top covers roughly the neckline down to the hip, which is a stable
/// fraction of a standing body's height whatever units either file is in.
/// Returns null when either box is unusable, leaving both meshes untouched.
GlbFit? fitTopToBody(GlbBounds? body, GlbBounds? garment) {
  if (body == null || garment == null) return null;
  if (body.isDegenerate || garment.isDegenerate) return null;

  final scale = (body.height * _topHeightFraction) / garment.height;
  if (!scale.isFinite || scale <= 0) return null;

  return GlbFit(scale, [
    body.centre(0) - scale * garment.centre(0),
    // Hang it from the shoulders: the top edge sits a neck's length below the
    // crown, and the garment falls from there.
    (body.max[1] - body.height * _topFromCrownFraction) - scale * garment.max[1],
    body.centre(2) - scale * garment.centre(2),
  ]);
}

/// Result of [fitTopToBody]: a uniform scale and a translation, in that order,
/// which is exactly what a glTF node applies (`T * R * S`, spec §3.7.2).
class GlbFit {
  final double scale;
  final List<double> translation;
  const GlbFit(this.scale, this.translation);
}

/// Proportions of a standing adult, used only by [fitTopToBody]. A T-shirt runs
/// from just under the chin to the hip — a bit over a third of standing height,
/// starting a bit over a tenth of the way down from the crown.
const double _topHeightFraction = 0.36;
const double _topFromCrownFraction = 0.13;

/// Column-major 4x4, the layout glTF stores node matrices in (spec §3.7.2).
List<double> _identity() => <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

List<double> _multiply(List<double> a, List<double> b) {
  final out = List<double>.filled(16, 0);
  for (var col = 0; col < 4; col++) {
    for (var row = 0; row < 4; row++) {
      var sum = 0.0;
      for (var k = 0; k < 4; k++) {
        sum += a[k * 4 + row] * b[col * 4 + k];
      }
      out[col * 4 + row] = sum;
    }
  }
  return out;
}

List<double> _transform(List<double> m, List<double> p) => <double>[
      m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
      m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
      m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14],
    ];

/// A node's own transform: its `matrix` when it has one, otherwise `T * R * S`
/// built from its translation, rotation quaternion and scale.
List<double> _localMatrix(Map<String, dynamic> node) {
  final matrix = node['matrix'];
  if (matrix is List && matrix.length == 16) {
    return [for (final v in matrix) (v as num).toDouble()];
  }

  final t = _vec3(node['translation']) ?? const [0.0, 0.0, 0.0];
  final s = _vec3(node['scale']) ?? const [1.0, 1.0, 1.0];
  final r = node['rotation'];
  var x = 0.0, y = 0.0, z = 0.0, w = 1.0;
  if (r is List && r.length == 4) {
    x = (r[0] as num).toDouble();
    y = (r[1] as num).toDouble();
    z = (r[2] as num).toDouble();
    w = (r[3] as num).toDouble();
  }

  final out = List<double>.filled(16, 0);
  out[0] = (1 - 2 * (y * y + z * z)) * s[0];
  out[1] = (2 * (x * y + z * w)) * s[0];
  out[2] = (2 * (x * z - y * w)) * s[0];
  out[4] = (2 * (x * y - z * w)) * s[1];
  out[5] = (1 - 2 * (x * x + z * z)) * s[1];
  out[6] = (2 * (y * z + x * w)) * s[1];
  out[8] = (2 * (x * z + y * w)) * s[2];
  out[9] = (2 * (y * z - x * w)) * s[2];
  out[10] = (1 - 2 * (x * x + y * y)) * s[2];
  out[12] = t[0];
  out[13] = t[1];
  out[14] = t[2];
  out[15] = 1;
  return out;
}

List<double>? _vec3(Object? value) {
  if (value is! List || value.length < 3) return null;
  if (value[0] is! num || value[1] is! num || value[2] is! num) return null;
  return [
    (value[0] as num).toDouble(),
    (value[1] as num).toDouble(),
    (value[2] as num).toDouble(),
  ];
}

/// Top-level arrays whose entries are referenced by index from elsewhere in the
/// document. `buffers` and `scenes` are rebuilt by hand instead.
const _indexedArrays = [
  'bufferViews',
  'accessors',
  'images',
  'samplers',
  'textures',
  'materials',
  'meshes',
  'nodes',
  'skins',
  'animations',
  'cameras',
];

/// How far every index in the overlay document has to move.
class _Offsets {
  final int bufferViews;
  final int accessors;
  final int images;
  final int samplers;
  final int textures;
  final int materials;
  final int meshes;
  final int nodes;
  final int skins;
  final int cameras;

  _Offsets(Map<String, dynamic> base)
      : bufferViews = _list(base, 'bufferViews').length,
        accessors = _list(base, 'accessors').length,
        images = _list(base, 'images').length,
        samplers = _list(base, 'samplers').length,
        textures = _list(base, 'textures').length,
        materials = _list(base, 'materials').length,
        meshes = _list(base, 'meshes').length,
        nodes = _list(base, 'nodes').length,
        skins = _list(base, 'skins').length,
        cameras = _list(base, 'cameras').length;
}

/// Rewrites [json] in place so every index points into the merged arrays and
/// every buffer view points into the merged binary chunk.
void _remap(Map<String, dynamic> json, _Offsets o, int binOffset) {
  for (final view in _maps(json, 'bufferViews')) {
    // Two buffers became one, so everything now reads from buffer 0 — just
    // further along it.
    view['buffer'] = 0;
    view['byteOffset'] = ((view['byteOffset'] as num?)?.toInt() ?? 0) + binOffset;
  }

  for (final accessor in _maps(json, 'accessors')) {
    _shift(accessor, 'bufferView', o.bufferViews);
    final sparse = accessor['sparse'] as Map<String, dynamic>?;
    if (sparse != null) {
      _shift(sparse['indices'] as Map<String, dynamic>?, 'bufferView', o.bufferViews);
      _shift(sparse['values'] as Map<String, dynamic>?, 'bufferView', o.bufferViews);
    }
  }

  for (final image in _maps(json, 'images')) {
    _shift(image, 'bufferView', o.bufferViews);
  }

  for (final texture in _maps(json, 'textures')) {
    _shift(texture, 'source', o.images);
    _shift(texture, 'sampler', o.samplers);
    // Compressed-texture extensions (KHR_texture_basisu and friends) name their
    // image the same way the core property does.
    for (final ext in _extensions(texture)) {
      _shift(ext, 'source', o.images);
    }
  }

  // Anywhere inside a material, an object carrying an `index` is a `textureInfo`
  // — that holds for the core properties and for every KHR material extension,
  // which is why this walks rather than lists them.
  for (final material in _maps(json, 'materials')) {
    _remapTextureInfo(material, o.textures);
  }

  for (final mesh in _maps(json, 'meshes')) {
    for (final primitive in _maps(mesh, 'primitives')) {
      _shiftValues(primitive['attributes'] as Map<String, dynamic>?, o.accessors);
      _shift(primitive, 'indices', o.accessors);
      _shift(primitive, 'material', o.materials);
      for (final target in _list(primitive, 'targets')) {
        _shiftValues(target as Map<String, dynamic>?, o.accessors);
      }
      final variants =
          (primitive['extensions'] as Map<String, dynamic>?)?['KHR_materials_variants'];
      if (variants is Map<String, dynamic>) {
        for (final mapping in _maps(variants, 'mappings')) {
          _shift(mapping, 'material', o.materials);
        }
      }
    }
  }

  for (final node in _maps(json, 'nodes')) {
    _shift(node, 'mesh', o.meshes);
    _shift(node, 'skin', o.skins);
    _shift(node, 'camera', o.cameras);
    _shiftAll(node, 'children', o.nodes);
  }

  for (final skin in _maps(json, 'skins')) {
    _shift(skin, 'inverseBindMatrices', o.accessors);
    _shift(skin, 'skeleton', o.nodes);
    _shiftAll(skin, 'joints', o.nodes);
  }

  for (final animation in _maps(json, 'animations')) {
    for (final sampler in _maps(animation, 'samplers')) {
      _shift(sampler, 'input', o.accessors);
      _shift(sampler, 'output', o.accessors);
    }
    for (final channel in _maps(animation, 'channels')) {
      _shift(channel['target'] as Map<String, dynamic>?, 'node', o.nodes);
    }
  }
  // `scenes` is deliberately not touched: the merge replaces every scene with a
  // single one built from both documents' roots, which are read before this
  // runs precisely because it rewrites the child lists they come from.
}

void _remapTextureInfo(Object? node, int offset) {
  if (node is Map<String, dynamic>) {
    _shift(node, 'index', offset);
    for (final value in node.values) {
      _remapTextureInfo(value, offset);
    }
  } else if (node is List) {
    for (final value in node) {
      _remapTextureInfo(value, offset);
    }
  }
}

/// The node indices the document draws by default: its default scene's roots,
/// or every node nobody claims as a child when there is no scene graph at all.
List<int> _sceneNodes(Map<String, dynamic> json) {
  final scenes = _list(json, 'scenes');
  if (scenes.isNotEmpty) {
    final index = (json['scene'] as num?)?.toInt() ?? 0;
    final scene = (index >= 0 && index < scenes.length ? scenes[index] : scenes.first);
    if (scene is Map<String, dynamic>) {
      return [for (final n in _list(scene, 'nodes')) (n as num).toInt()];
    }
  }
  final nodes = _list(json, 'nodes');
  final claimed = <int>{};
  for (final node in _maps(json, 'nodes')) {
    for (final child in _list(node, 'children')) {
      claimed.add((child as num).toInt());
    }
  }
  return [for (var i = 0; i < nodes.length; i++) if (!claimed.contains(i)) i];
}

bool _hasSingleEmbeddedBuffer(Map<String, dynamic> json) {
  final buffers = _list(json, 'buffers');
  if (buffers.length != 1) return false;
  final buffer = buffers.first;
  return buffer is Map<String, dynamic> && buffer['uri'] == null;
}

void _union(
  Map<String, dynamic> into,
  Map<String, dynamic> base,
  Map<String, dynamic> overlay,
  String key,
) {
  final all = <String>{
    for (final e in _list(base, key)) '$e',
    for (final e in _list(overlay, key)) '$e',
  };
  if (all.isEmpty) {
    into.remove(key);
  } else {
    into[key] = all.toList();
  }
}

int _padded(int length) => length + ((4 - length % 4) % 4);

List<dynamic> _list(Map<String, dynamic> json, String key) =>
    (json[key] as List?) ?? const [];

Iterable<Map<String, dynamic>> _maps(Map<String, dynamic> json, String key) =>
    _list(json, key).whereType<Map<String, dynamic>>();

Iterable<Map<String, dynamic>> _extensions(Map<String, dynamic> json) =>
    ((json['extensions'] as Map<String, dynamic>?)?.values ?? const [])
        .whereType<Map<String, dynamic>>();

void _shift(Map<String, dynamic>? json, String key, int offset) {
  final value = json?[key];
  if (value is num) json![key] = value.toInt() + offset;
}

void _shiftAll(Map<String, dynamic> json, String key, int offset) {
  final value = json[key];
  if (value is List) {
    json[key] = [for (final e in value) if (e is num) e.toInt() + offset else e];
  }
}

void _shiftValues(Map<String, dynamic>? json, int offset) {
  if (json == null) return;
  for (final key in json.keys.toList()) {
    _shift(json, key, offset);
  }
}
