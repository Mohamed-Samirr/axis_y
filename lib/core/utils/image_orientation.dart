import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Rewrites [file] so its pixels are already the right way up, with no EXIF
/// orientation tag left for the reader to honour.
///
/// Why this is needed: on Android `CameraController.takePicture()` saves the
/// sensor buffer as-is — a portrait shot lands in the JPEG as a *landscape*
/// image plus an EXIF `Orientation` tag saying "rotate me 90°". Flutter's
/// decoder and every gallery app apply that tag, so the photo looks upright on
/// the phone, but the scan backend reads raw pixels and sees a person lying
/// down. Its width extraction scans horizontal rows of the body mask, so a
/// sideways body makes it measure *length* as girth: that is where a 490cm
/// chest and a 4.4cm inseam come from.
///
/// Rotating is not enough on its own — the tag has to go too, or a reader that
/// does honour EXIF would rotate the already-rotated pixels a second time.
/// [img.bakeOrientation] does both.
///
/// Overwrites in place so the caller's existing delete-after-scan logic keeps
/// covering the file (privacy rule F4), and returns [file] for chaining.
/// Best effort: if anything fails the original is left untouched, since an
/// unrotated scan still beats no scan at all.
Future<File> bakeImageOrientation(File file) async {
  try {
    final bytes = await file.readAsBytes();
    // Off the UI isolate: decoding and re-encoding a 1080×1920 JPEG is enough
    // pure-Dart work to drop frames on the shutter animation.
    final baked = await compute(bakeOrientationBytes, bytes);
    if (baked != null) await file.writeAsBytes(baked, flush: true);
  } catch (_) {
    // Best effort.
  }
  return file;
}

/// The pixel work behind [bakeImageOrientation]. Top-level so it can be handed
/// to `compute`. Returns null when the bytes aren't a decodable image —
/// including the truncated ones `decodeImage` throws on rather than rejecting.
@visibleForTesting
Uint8List? bakeOrientationBytes(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    // A no-op when the tag is already normal, so re-running this is harmless
    // beyond the cost of one re-encode.
    return img.encodeJpg(img.bakeOrientation(decoded), quality: 92);
  } catch (_) {
    return null;
  }
}
