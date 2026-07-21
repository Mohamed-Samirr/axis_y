import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Storage for the scanned `.glb` body mesh.
///
/// Only the *relative* name is persisted on [Measurements.modelPath]; the
/// absolute path is rebuilt at read time because iOS rotates the app container
/// UUID between installs, which would invalidate a stored absolute path.
abstract class ModelStorage {
  static const String fileName = 'body_model.glb';

  /// Absolute destination for the cached model.
  static Future<File> target() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Resolves a stored relative path to an absolute one, or null when the file
  /// no longer exists.
  static Future<String?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$relativePath');
    return await file.exists() ? file.path : null;
  }
}
