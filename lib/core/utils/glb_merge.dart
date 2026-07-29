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
/// Neither model is transformed: they are dropped into one scene exactly where
/// each was authored, which is right when both come out of the same pipeline
/// and wrong if they do not share an origin and scale.
///
/// Returns null for anything it cannot compose faithfully — a document with
/// external buffers, or bytes that are not a glTF 2.0 binary at all. Callers
/// fall back to showing a single mesh rather than a broken one.
Uint8List? mergeGlb(Uint8List baseBytes, Uint8List overlayBytes) {
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
    merged['scenes'] = [
      <String, dynamic>{'nodes': [...baseRoots, ...overlayRoots]},
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
