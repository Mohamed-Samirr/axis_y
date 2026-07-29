import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../utils/glb_merge.dart';

/// Every binary glTF starts with the 4-byte magic `glTF` (spec §4.4.1), which
/// is enough to tell a real mesh from an HTML error or interstitial page that
/// happened to arrive with a 200.
@visibleForTesting
bool isGlbHeader(List<int> head) =>
    head.length >= 4 &&
    head[0] == 0x67 && // g
    head[1] == 0x6C && // l
    head[2] == 0x54 && // T
    head[3] == 0x46; //  F

/// Arguments for [_mergeGlbBytes]. [compute] takes a single value, and a record
/// of raw bytes is clearer than positional list entries.
class _MergeRequest {
  final Uint8List body;
  final Uint8List garment;
  final bool fit;
  const _MergeRequest(this.body, this.garment, this.fit);
}

/// [compute] entry point for [GlbCache.merged]. Composing a pair of 1–5MB
/// meshes is enough parsing and copying to drop frames if it ran on the UI
/// isolate, and it lands right as the user is dragging the model around.
Uint8List? _mergeGlbBytes(_MergeRequest request) =>
    mergeGlb(request.body, request.garment, fitOverlayToBase: request.fit);

/// On-disk cache for try-on `.glb` meshes (guide §13).
///
/// Try-on GLBs are 1–5MB and the same body/garment pair is re-requested every
/// time the user toggles back to a size they already viewed, so a repeat view
/// must not hit the network. Files are keyed by a hash of their URL: the
/// backend versions the URL when it re-morphs, so a changed mesh naturally
/// lands on a new key.
class GlbCache {
  /// Deliberately *not* under `getTemporaryDirectory()`.
  ///
  /// Android empties an app's cache directory whenever it likes — including
  /// while the app is in the foreground — and it does: a mesh resolved seconds
  /// earlier was already gone by the time `model_viewer_plus` asked its proxy
  /// for it, so the proxy threw `PathNotFoundException` from inside an async
  /// callback nothing can catch and the try-on screen sat on an empty black
  /// stage. Nothing here needs the OS to reclaim space either — [maxFiles]
  /// already bounds the directory.
  static const _dirName = 'glb_cache';

  /// GLBs are large; keep the directory bounded. Oldest files go first.
  static const int maxFiles = 12;

  /// A GLB is 1–5MB over mobile data, so this is far longer than the JSON
  /// timeouts — but it must exist. A bare `Dio()` has **no** timeouts at all,
  /// and a mesh URL pointing at a host the phone cannot reach then stalls
  /// forever. The try-on Cubit awaits this download before clearing its
  /// `morphing` flag, so "no timeout" surfaced as the screen hanging on the
  /// spinner with no error and no way back.
  static const Duration downloadTimeout = Duration(seconds: 60);

  final Dio _dio;

  GlbCache([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: downloadTimeout,
            ));

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
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
      // Dio's receiveTimeout only measures the gap *between* chunks, so a
      // server trickling bytes could still hold this open indefinitely. The
      // wall-clock deadline is what actually bounds the wait.
      await _dio.download(url, part.path).timeout(downloadTimeout);
      if (!await part.exists() || await part.length() == 0) return null;
      // A 200 does not guarantee a mesh: a proxy interstitial or an HTML error
      // page downloads perfectly happily. Without this check that page would be
      // renamed to .glb and *cached*, so every later retry would serve the same
      // broken file from disk and the viewer would fail forever.
      if (!await _isGlb(part)) {
        await part.delete();
        return null;
      }
      await part.rename(file.path);
      await _evict(dir);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isGlb(File file) async {
    try {
      return isGlbHeader(await file.openRead(0, 4).expand((chunk) => chunk).toList());
    } catch (_) {
      return false;
    }
  }

  /// One mesh holding both [bodyPath] and [garmentPath], so the garment is worn
  /// rather than floating on its own.
  ///
  /// `model_viewer_plus` renders a single `src`. Stacking a second viewer would
  /// mean a second webview holding a second multi-megabyte mesh, which is the
  /// OOM the guide warns about (§11) — so the two files are composed into one
  /// and a single viewer keeps rendering.
  ///
  /// Set [fitGarment] when the two files did not come out of the same pipeline
  /// and so share no units or origin — the engine's garment against the user's
  /// own scanned avatar. Leave it off for two meshes the engine produced
  /// together, which already line up and must not be moved.
  ///
  /// Returns null when either file is missing or is not a glTF that can be
  /// composed; callers fall back to showing the garment alone.
  Future<String?> merged(
    String bodyPath,
    String garmentPath, {
    bool fitGarment = false,
  }) async {
    try {
      final dir = await _dir();
      // Keyed on both inputs: a re-morph lands on a new garment path, and so
      // on a new merged file, exactly like a re-morphed download does. The fit
      // is part of the key because it changes the bytes.
      final out = File('${dir.path}/${_key('$bodyPath|$garmentPath|$fitGarment')}.glb');
      if (await out.exists() && await out.length() > 0) return out.path;

      final body = File(bodyPath);
      final garment = File(garmentPath);
      if (!await body.exists() || !await garment.exists()) return null;

      final bytes = await compute(
        _mergeGlbBytes,
        _MergeRequest(
          await body.readAsBytes(),
          await garment.readAsBytes(),
          fitGarment,
        ),
      );
      if (bytes == null) return null;

      // Same two-step write as a download: a half-written merge must never be
      // mistaken for a finished one on the next launch.
      final part = File('${out.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(out.path);
      await _evict(dir);
      return out.path;
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
