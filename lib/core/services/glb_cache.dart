import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// On-disk cache for try-on `.glb` meshes (guide §13).
///
/// Try-on GLBs are 1–5MB and the same body/garment pair is re-requested every
/// time the user toggles back to a size they already viewed, so a repeat view
/// must not hit the network. Files are keyed by a hash of their URL: the
/// backend versions the URL when it re-morphs, so a changed mesh naturally
/// lands on a new key.
class GlbCache {
  static const _dirName = 'glb_cache';

  /// GLBs are large; keep the directory bounded. Oldest files go first.
  static const int maxFiles = 12;

  final Dio _dio;

  GlbCache([Dio? dio]) : _dio = dio ?? Dio();

  Future<Directory> _dir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Absolute path of the locally cached mesh, downloading it if needed.
  /// Returns null when the download fails — callers fall back to the painted
  /// mannequin rather than failing the whole try-on.
  Future<String?> resolve(String url) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/${_key(url)}.glb');
      if (await file.exists() && await file.length() > 0) return file.path;

      // Download to a temp name first so an interrupted transfer can never be
      // mistaken for a complete cache entry.
      final part = File('${file.path}.part');
      await _dio.download(url, part.path);
      if (!await part.exists() || await part.length() == 0) return null;
      await part.rename(file.path);
      await _evict(dir);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Already-downloaded path, or null. Lets the UI show a cached mesh with no
  /// spinner while a fresh one is still in flight.
  Future<String?> cached(String url) async {
    try {
      final file = File('${(await _dir()).path}/${_key(url)}.glb');
      return await file.exists() ? file.path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> _evict(Directory dir) async {
    try {
      final files = (await dir.list().toList()).whereType<File>().toList();
      if (files.length <= maxFiles) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - maxFiles)) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// FNV-1a: stable across launches, unlike `String.hashCode`, which is what a
  /// cache that must survive a restart needs.
  static String _key(String url) {
    var hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
