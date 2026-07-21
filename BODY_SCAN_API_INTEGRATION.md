# AXIS Y — Body Scan API Integration Guide (Flutter)

**Status:** the Flutter app currently fakes the body scan end-to-end. The Python backend
(`backend/Axis_Y/body_scan`) now exposes a working FastAPI service that returns real
measurements and a real 3D body mesh. This document is the implementation contract for
wiring the two together.

**Golden rule (unchanged):** no Cubit and no View may know that HTTP exists. Everything goes
through `BodyScanRepository`. The only files that learn about the network are
`app_config.dart`, `injector.dart`, a new `api_client.dart`, and a new
`ApiBodyScanRepository`.

---

## 1. What exists today

### Backend — `backend/Axis_Y/body_scan/main.py`

| Endpoint | Method | Returns |
|---|---|---|
| `/health` | GET | `{"status":"ok","service":...,"version":"0.2.0"}` |
| `/scan` | POST multipart | JSON measurements |
| `/scan-3d` | POST multipart | binary `.glb` file |
| `/docs` | GET | Swagger UI |

CORS is `allow_origins=["*"]`, so there is nothing to configure on the server for mobile.

**Request body (identical for both scan endpoints):**

| Field | Type | Notes |
|---|---|---|
| `front_image` | file | full body, head to feet, JPEG/PNG/WebP/AVIF |
| `side_image` | file | side profile, same framing |
| `height_cm` | form field, float | must be `100 <= h <= 250`, else HTTP 422 |

**`POST /scan` — 200 response:**

```json
{
  "success": true,
  "measurements": {
    "height_cm": 175.0,
    "shoulder_cm": 44.2,
    "chest_cm": 98.7,
    "waist_cm": 84.1,
    "hips_cm": 99.3,
    "inseam_cm": 79.5,
    "weight_kg_estimate": 74.6
  },
  "confidence": 0.9713
}
```

Every value is a **double**, not an int. `confidence` is a 0–1 fraction, at the top level —
not inside `measurements`.

**`POST /scan-3d` — 200 response:** raw bytes, `Content-Type: model/gltf-binary`,
`Content-Disposition: attachment; filename=body_model.glb`. **No measurements are returned
with it** — see §9, this needs a backend change.

**Error responses** are FastAPI's standard shape, `{"detail": "..."}`:

| Status | `detail` | Cause |
|---|---|---|
| 422 | `height_cm must be between 100 and 250.` | bad height |
| 422 | `No person detected in the front image.` | MediaPipe found nobody |
| 422 | `No person detected in the side image.` | same, side photo |
| 422 | *(a JSON **list**, not a string)* | missing/invalid form field — Pydantic validation |
| 500 | `Internal error: ...` | anything thrown inside the pipeline |

Note the 422 case where `detail` is a list of objects. Parsing code must survive that.

### Flutter — what is mock today

- [body_scan_repository.dart](lib/core/repositories/body_scan_repository.dart) —
  `analyze()` takes **no arguments**, sleeps 2.5s, returns a hardcoded `Measurements`.
- [scan_camera_screen.dart](lib/features/body_scan/view/scan_camera_screen.dart) — no real
  camera. A `CustomPaint` guide overlay and a button that flips `_step` 0→1 then navigates.
  **No image is ever captured.**
- [body_scan_cubit.dart](lib/features/body_scan/cubit/body_scan_cubit.dart) — calls
  `analyze()` with nothing, saves the result onto the user.
- [user.dart](lib/core/models/user.dart) — `Measurements` holds five **ints**: chest, waist,
  hips, height, weight. No shoulder, no inseam, no confidence.
- [injector.dart](lib/core/di/injector.dart) — the `useMockData == false` branch is
  `throw UnimplementedError(...)`.
- **The app never asks the user for their height.** This is the single hardest blocker: the
  API cannot compute anything without it, because height is the pixel→cm reference scale.

---

## 2. Gap list (implement in this order)

1. **Height input** — new UI, the API is unusable without it.
2. **Real camera capture** — two real image files on disk.
3. **`Measurements` model** — carry doubles + shoulder/inseam/confidence without breaking
   the ~12 existing call sites that do int math.
4. **Repository contract** — `analyze()` must accept the two files and the height.
5. **HTTP layer** — dio client, long timeouts, error mapping to localized keys.
6. **DI** — a body-scan-only real/mock switch (do not flip the global `useMockData`; every
   other repository would throw).
7. **Long-running UX** — the real pipeline takes 5–30s, not 2.5s.
8. **3D model** — download, cache, and render the `.glb` in the try-on screen.
9. **Photo deletion** — the privacy promise in `scan_privacy` is currently trivially true
   because no photo exists. Once photos are real, deleting them becomes actual work.

---

## 3. Before any Flutter code: get the backend reachable

The Flutter developer will lose an hour to this if it is not done first.

```bash
cd "backend/Axis_Y/body_scan"
pip install -r requirements.txt

# One-time: the MediaPipe model (~30MB) must sit in body_scan/
# (see body_scan/README.md for the download command)

# One-time and REQUIRED for /scan-3d: downloads base_mesh.obj
python download_base.py

# Serve on all interfaces, not just localhost, so a phone can reach it
python main.py            # binds 0.0.0.0:8000
```

Three traps:

- **`/scan-3d` will 500 until `download_base.py` has been run.** `body_model.py` loads
  `base_mesh.obj` from a **relative** path, so the server must also be *started from inside
  `body_scan/`*. Starting it from the repo root gives `FileNotFoundError` on every 3D
  request while `/scan` keeps working — a confusing failure mode.
- **First `/scan` call is very slow.** `rembg` downloads the U2-Net model (~170MB) on first
  use. Warm it up with one curl before demoing.
- **Per-request time is 5–30s** on CPU: MediaPipe twice, then rembg twice, then (for 3D) a
  mesh warp. Budget timeouts accordingly.

Verify from the dev machine before touching Dart:

```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/scan \
  -F "front_image=@f1.png" -F "side_image=@s1.png" -F "height_cm=175"
```

### Base URL per platform

| Target | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator | `http://localhost:8000` |
| Physical phone (same Wi-Fi) | `http://<dev-machine-LAN-IP>:8000` |
| Web / desktop | `http://localhost:8000` |

On Windows, allow inbound TCP 8000 through the firewall or the physical-device case fails
silently with a connection timeout.

---

## 4. Step 1 — packages

`pubspec.yaml`:

```yaml
dependencies:
  # Networking
  dio: ^5.7.0

  # Camera + files
  camera: ^0.11.0+2
  path_provider: ^2.1.4

  # 3D viewer (already named as the intended approach in AXIS_Y_MASTER_PROMPT.md §F9)
  model_viewer_plus: ^1.7.2
```

`image_picker` is a valid alternative to `camera` if the guide-overlay viewfinder is
dropped, but the overlay is a spec requirement (F4) and matters for scan quality, so prefer
`camera`.

---

## 5. Step 2 — config

`lib/core/config/app_config.dart` — add, do **not** flip `useMockData`:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

abstract class AppConfig {
  static const bool useMockData = true;

  /// Body scan is the first feature with a real backend. It opts out of
  /// [useMockData] on its own so the rest of the app keeps running on mocks.
  static const bool useRealBodyScan = true;

  /// Override at build time:
  ///   flutter run --dart-define=AXIS_API_BASE=http://192.168.1.7:8000
  static const String _override = String.fromEnvironment('AXIS_API_BASE');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // emulator loopback
    return 'http://localhost:8000';
  }

  /// The scan pipeline runs MediaPipe + rembg on CPU. 5–30s is normal.
  static const Duration scanTimeout = Duration(seconds: 120);
  static const Duration connectTimeout = Duration(seconds: 15);

  // ...existing constants unchanged
}
```

Using `--dart-define` for the physical-device IP keeps a machine-specific address out of
version control.

---

## 6. Step 3 — the `Measurements` model

`Measurements` is read in ~12 places that do integer arithmetic — `compareFit` in
[tryon_repository.dart:41-49](lib/core/repositories/tryon_repository.dart#L41-L49),
`recommendedSize`, `home_cubit` personalization, `mock_seed`. Converting the fields to
`double` would cascade through all of them.

**Keep the int fields. Add the precise values alongside.** `fromJson` must stay tolerant so
already-persisted sessions in SharedPreferences still load.

```dart
class Measurements extends Equatable {
  // Rounded, kept as int for sizing logic and display.
  final int chest;
  final int waist;
  final int hips;
  final int height;
  final int weight;

  // From the scan API. Null for mock / legacy stored data.
  final double? shoulderCm;
  final double? inseamCm;
  final double? confidence;

  /// Relative path (inside the app documents dir) of the cached .glb body model.
  /// Stored as a relative path because iOS changes the container UUID between
  /// installs, which would invalidate an absolute path.
  final String? modelPath;

  const Measurements({
    required this.chest,
    required this.waist,
    required this.hips,
    required this.height,
    required this.weight,
    this.shoulderCm,
    this.inseamCm,
    this.confidence,
    this.modelPath,
  });

  /// Builds from the `POST /scan` response body.
  factory Measurements.fromApi(Map<String, dynamic> body) {
    final m = body['measurements'] as Map<String, dynamic>;
    double d(String k) => (m[k] as num).toDouble();
    return Measurements(
      chest: d('chest_cm').round(),
      waist: d('waist_cm').round(),
      hips: d('hips_cm').round(),
      height: d('height_cm').round(),
      weight: d('weight_kg_estimate').round(),
      shoulderCm: d('shoulder_cm'),
      inseamCm: d('inseam_cm'),
      confidence: (body['confidence'] as num?)?.toDouble(),
    );
  }

  Measurements copyWith({String? modelPath}) => Measurements(
        chest: chest, waist: waist, hips: hips, height: height, weight: weight,
        shoulderCm: shoulderCm, inseamCm: inseamCm, confidence: confidence,
        modelPath: modelPath ?? this.modelPath,
      );

  String get recommendedSize { /* unchanged */ }

  Map<String, dynamic> toJson() => {
        'chest': chest, 'waist': waist, 'hips': hips,
        'height': height, 'weight': weight,
        'shoulderCm': shoulderCm, 'inseamCm': inseamCm,
        'confidence': confidence, 'modelPath': modelPath,
      };

  factory Measurements.fromJson(Map<String, dynamic> json) => Measurements(
        chest: (json['chest'] as num).toInt(),
        waist: (json['waist'] as num).toInt(),
        hips: (json['hips'] as num).toInt(),
        height: (json['height'] as num).toInt(),
        weight: (json['weight'] as num).toInt(),
        shoulderCm: (json['shoulderCm'] as num?)?.toDouble(),
        inseamCm: (json['inseamCm'] as num?)?.toDouble(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        modelPath: json['modelPath'] as String?,
      );

  @override
  List<Object?> get props =>
      [chest, waist, hips, height, weight, shoulderCm, inseamCm, confidence, modelPath];
}
```

`as num` rather than `as int` in `fromJson` matters: a stored value that round-tripped
through JSON as `92.0` throws on `as int`.

---

## 7. Step 4 — HTTP client and error mapping

New file `lib/core/network/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.scanTimeout,
          sendTimeout: AppConfig.scanTimeout,
        ));
}

/// Maps a [DioException] to an [AppStrings] key so the UI stays localized and
/// no raw server text is shown to the user.
String mapDioError(Object error) {
  if (error is! DioException) return 'error_generic';

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
      return 'scan_err_offline';
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'scan_err_timeout';
    default:
      break;
  }

  final status = error.response?.statusCode;
  final detail = error.response?.data;

  if (status == 422 && detail is Map && detail['detail'] is String) {
    final d = detail['detail'] as String;
    if (d.contains('front image')) return 'scan_err_no_person_front';
    if (d.contains('side image')) return 'scan_err_no_person_side';
    if (d.contains('height_cm')) return 'scan_err_bad_height';
  }
  // 422 with a List detail = a malformed request we built. Client bug.
  if (status == 422) return 'scan_err_bad_request';
  if (status != null && status >= 500) return 'scan_err_server';
  return 'error_generic';
}
```

The returned string is a translation key, matching how `MockAuthRepository` already returns
`'otp_wrong'` as a `Failure` message and the view resolves it with `context.tr(...)`. Keep
that convention — `ErrorView` should be given `context.tr(state.error!)`, not the raw value.

**Do not add a logging interceptor that prints request bodies.** It would dump the user's
body photos into the console.

---

## 8. Step 5 — repository

`lib/core/repositories/body_scan_repository.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../network/api_client.dart';
import '../utils/result.dart';

abstract class BodyScanRepository {
  /// Analyzes the two captured photos. The caller owns [frontImage] /
  /// [sideImage] and MUST delete them once this returns — the images are never
  /// persisted (privacy rule F4).
  Future<Result<Measurements>> analyze({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  });

  /// Fetches the .glb body mesh and caches it, returning the saved file.
  /// Optional: a failure here must not fail the scan.
  Future<Result<File>> generateModel({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  });
}

class ApiBodyScanRepository implements BodyScanRepository {
  final ApiClient _api;
  ApiBodyScanRepository(this._api);

  Future<FormData> _form(File front, File side, double heightCm) async => FormData.fromMap({
        'front_image': await MultipartFile.fromFile(
          front.path,
          filename: 'front.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        'side_image': await MultipartFile.fromFile(
          side.path,
          filename: 'side.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        'height_cm': heightCm.toString(),
      });

  @override
  Future<Result<Measurements>> analyze({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/scan',
        data: await _form(frontImage, sideImage, heightCm),
      );
      return Success(Measurements.fromApi(res.data!));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<File>> generateModel({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  }) async {
    try {
      final res = await _api.dio.post<List<int>>(
        '/scan-3d',
        data: await _form(frontImage, sideImage, heightCm),
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/body_model.glb');
      await file.writeAsBytes(res.data!, flush: true);
      return Success(file);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}
```

`http_parser` comes in transitively with dio; declare it in `pubspec.yaml` if the analyzer
complains about the implicit dependency.

`MockBodyScanRepository` must be updated to the same signature — accept and ignore the
arguments, keep the 2.5s delay, and return a `Success(File(...))` stub or a
`Failure('scan_err_server')` for `generateModel`.

---

## 9. Step 6 — DI

`lib/core/di/injector.dart` — register body scan **outside** the `useMockData` branch:

```dart
Future<void> setupInjector() async {
  final localStore = await LocalStore.create();
  sl.registerSingleton<LocalStore>(localStore);
  sl.registerLazySingleton<ApiClient>(() => ApiClient());

  // Body scan has a real backend; it opts out of the global mock flag.
  sl.registerLazySingleton<BodyScanRepository>(
    () => AppConfig.useRealBodyScan
        ? ApiBodyScanRepository(sl())
        : MockBodyScanRepository(),
  );

  if (AppConfig.useMockData) {
    // ...all other mock registrations, minus the BodyScanRepository line
  } else {
    throw UnimplementedError('Real API repositories not wired yet.');
  }
}
```

Setting `useRealBodyScan = false` must restore today's fully offline behaviour. Verify that
before shipping — it is the demo fallback when Wi-Fi is unavailable.

---

## 10. Step 7 — height input

The API rejects the request without a height, so this must be collected before the camera.
Add it to [scan_intro_screen.dart](lib/features/body_scan/view/scan_intro_screen.dart),
which already exists and is the natural place — one `TextFormField`, `keyboardType:
TextInputType.number`, validated to 100–250 client-side so the user gets an instant error
instead of a 15-second round trip.

Pass the value forward with a small payload class rather than a global:

```dart
// lib/features/body_scan/models/scan_input.dart
import 'dart:io';

class ScanInput {
  final double heightCm;
  final File? front;
  final File? side;
  const ScanInput({required this.heightCm, this.front, this.side});

  ScanInput copyWith({File? front, File? side}) =>
      ScanInput(heightCm: heightCm, front: front ?? this.front, side: side ?? this.side);
}
```

Route it through `go_router`'s `extra`:

- `scanIntro` → `context.push(Routes.scanCamera, extra: ScanInput(heightCm: h))`
- `scanCamera` → `context.pushReplacement(Routes.scanResult, extra: input.copyWith(...))`
- `app_router.dart`: `builder: (_, state) => ScanResultScreen(input: state.extra as ScanInput)`

`ScanResultScreen` currently takes no arguments; give it a required `ScanInput input` and
pass it into `BodyScanCubit(...)..analyze(input)`.

Guard against a null `state.extra`: a deep link or a hot restart on `/scan-result` would
otherwise crash on the cast. Redirect to `Routes.scanIntro` when it is null.

---

## 11. Step 8 — real camera capture

Rewrite `scan_camera_screen.dart` around `CameraController`, keeping the existing
`_BodyGuidePainter` overlay on top of the preview — the overlay is what makes users frame
themselves head-to-feet, which the backend's `compute_scale_factor` requires (it needs the
nose **and** both heels visible, otherwise it raises and the request fails with a 500).

Essentials:

```dart
final cameras = await availableCameras();
final front = cameras.firstWhere(
  (c) => c.lensDirection == CameraLensDirection.back,
  orElse: () => cameras.first,
);
_controller = CameraController(front, ResolutionPreset.high, enableAudio: false);
await _controller.initialize();

// on capture:
final shot = await _controller.takePicture();     // XFile in a temp dir
final file = File(shot.path);
```

Notes:

- `ResolutionPreset.high` (720p) is enough and keeps upload time down; `max` can produce
  8MB+ files that make a slow request slower. Do not go below `high` — rembg segmentation
  quality drops.
- Use the **rear** camera. A selfie camera cannot frame a full standing body at arm's
  length, and the spec's two-photo flow assumes the phone is propped up or held by someone.
- Dispose the controller in `dispose()`; the preview keeps the camera hardware open.
- Handle permission denial with the rationale UI required by F4 rather than a silent
  failure.
- Keep the `1 / 2` step counter and the front/side prompt already in the screen.

### Permissions

`android/app/src/main/AndroidManifest.xml` — add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

and on `<application>`:

```xml
android:usesCleartextTraffic="true"
```

Cleartext is needed twice over: the API is plain `http` during development, **and**
`model_viewer_plus` serves the local `.glb` to its internal WebView over a localhost HTTP
proxy. Before any production release, move the API to HTTPS and replace the blanket flag
with a `network_security_config.xml` that whitelists only `localhost` / `10.0.2.2`.

`ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>عشان ناخد صورتين ونحسب مقاساتك بدقة</string>

<!-- Development only — remove once the API is HTTPS -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key><true/>
</dict>
```

`camera` requires iOS 12+; bump the Podfile platform if the build complains.

---

## 12. Step 9 — Cubit and the long wait

The current Cubit shows one spinner for 2.5s. The real call can take 30s, and with the 3D
model roughly double that. A single undifferentiated spinner will read as a hang.

Extend `ScanStatus` and drive staged copy:

```dart
enum ScanStatus { idle, uploading, analyzing, buildingModel, done, error }

class BodyScanCubit extends Cubit<BodyScanState> {
  final BodyScanRepository _repo;
  final AuthRepository _auth;

  BodyScanCubit(this._repo, this._auth) : super(const BodyScanState());

  Future<void> analyze(ScanInput input) async {
    final front = input.front!, side = input.side!;
    emit(const BodyScanState(status: ScanStatus.uploading));
    try {
      final result = await _repo.analyze(
        frontImage: front, sideImage: side, heightCm: input.heightCm,
      );
      await result.when(
        success: (m) async {
          emit(BodyScanState(status: ScanStatus.buildingModel, measurements: m));
          final model = await _repo.generateModel(
            frontImage: front, sideImage: side, heightCm: input.heightCm,
          );
          // A missing 3D model is not a scan failure — the try-on screen falls
          // back to the painted mannequin.
          emit(BodyScanState(
            status: ScanStatus.done,
            measurements: m.copyWith(modelPath: model.valueOrNull?.path),
          ));
        },
        failure: (msg) async => emit(BodyScanState(status: ScanStatus.error, error: msg)),
      );
    } finally {
      // Privacy rule F4: photos are deleted immediately after analysis,
      // whatever the outcome.
      await _safeDelete(front);
      await _safeDelete(side);
    }
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {/* best effort */}
  }
}
```

Points that are easy to get wrong:

- **Delete in `finally`, not on the success path.** An error or a user backing out must
  still wipe the photos. This is the promise made by the `scan_privacy` string on the intro
  screen.
- **Do not save the images anywhere else** — not the gallery, not `path_provider`
  documents. `takePicture()` writes to a temp dir; that file is the only copy and it gets
  deleted.
- **`generateModel` failure is non-fatal.** The `.glb` is an enhancement; measurements are
  the product. Emit `done` regardless.
- If the user leaves the screen mid-scan, `close()` runs while the request is in flight —
  guard `emit` with `if (isClosed) return;` or the Cubit throws after disposal.

`scan_result_screen.dart` should render distinct copy per status (`scan_uploading`,
`analyzing`, `scan_building_model`) and add an error branch — it currently force-unwraps
`state.measurements!`, which throws on any failure. Use `ErrorView(message:
context.tr(state.error!), onRetry: ...)`.

Also add the new numbers to the result rows: shoulder and inseam are now available, and
`confidence` is worth surfacing as a low-confidence warning (say, below 0.85: "الصور مش
واضحة أوي — جرب تاني في إضاءة أحسن").

---

## 13. Step 10 — rendering the 3D model

`_Mannequin` in [tryon_screen.dart:152-235](lib/features/virtual_try_on/view/tryon_screen.dart#L152-L235)
is a hand-painted placeholder. Replace it **only when a real model exists**:

```dart
final path = state.measurements.modelPath;
final hasModel = path != null && File(path).existsSync();

hasModel
  ? ModelViewer(
      src: 'file://$path',
      alt: context.tr('tryon_title'),
      cameraControls: true,   // drag = rotate, pinch = zoom (matches F9)
      autoRotate: false,
      disableZoom: false,
      backgroundColor: const Color(0xFF0E1526),
    )
  : _Mannequin(color: Color(state.color.hex))
```

Caveats worth knowing before you start:

- `modelPath` is stored on `Measurements`, which is persisted inside the session JSON, so
  the model survives restarts. Store it **relative** to the documents directory and rebuild
  the absolute path at read time — iOS rotates the app container UUID on reinstall and an
  absolute path saved today will not resolve tomorrow.
- `ModelViewer` is a WebView. It is heavier than the `CustomPaint` and will not meet the
  "opens in under 3 seconds" target on a low-end device if the `.glb` is large. The
  MakeHuman base mesh is dense; if load time is a problem, decimate the mesh server-side in
  `body_model.py` before export.
- **The mesh is a nude body model with no garment.** `/scan-3d` returns the user's body
  shape only — `body_model.py` warps a base mesh to the measurements and has no concept of
  clothing. The color circles and the "try this garment on" part of F9 are still not
  implemented anywhere. Rendering this mesh in the try-on screen shows the *body*, not the
  outfit. Decide deliberately whether that ships to users, or whether the model belongs on
  the profile/measurements screen instead until garment draping (backend Phase 5) exists.

Given that, the lower-risk sequencing is: render the `.glb` on the **scan result / profile**
screen first, as proof the measurements are real, and leave the try-on mannequin alone until
the backend can drape a garment.

---

## 14. Backend change worth requesting

`/scan` and `/scan-3d` each run the *entire* pipeline — two MediaPipe passes and two rembg
passes. Calling both, as §12 does, doubles a 30-second wait to 60 seconds for data the
server already computed once.

Ask the backend for a single endpoint returning both, e.g. measurements JSON with the mesh
base64-encoded, or a `/scan` response containing a short-lived `model_url` that the app
fetches separately. In `main.py` this is a small refactor: extract the shared
load → detect → measure block into a helper, then have one endpoint return
`{"measurements": {...}, "confidence": ..., "model_glb_base64": ...}`.

Until that exists, consider calling `/scan-3d` **lazily** — only when the user first opens a
screen that shows the model — rather than during the scan flow. That keeps the scan itself
at ~30s and moves the second wait somewhere it can be backgrounded.

---

## 15. New localization keys

Add to **both** the `'ar'` and `'en'` maps in
[app_strings.dart](lib/core/localization/app_strings.dart):

| Key | ar | en |
|---|---|---|
| `enter_height` | ادخل طولك بالسنتيمتر | Enter your height in cm |
| `height_invalid` | الطول لازم يكون بين 100 و 250 سم | Height must be between 100 and 250 cm |
| `scan_uploading` | بنرفع صورك… | Uploading your photos… |
| `scan_building_model` | بنبني الموديل ثلاثي الأبعاد… | Building your 3D model… |
| `scan_takes_time` | ممكن تاخد لحد نص دقيقة، استنى معانا | This can take up to 30 seconds |
| `shoulder` | عرض الكتف | Shoulder |
| `inseam` | طول الرجل الداخلي | Inseam |
| `scan_low_confidence` | الصور مش واضحة أوي — جرب تاني في إضاءة أحسن | Photos were unclear — try again in better light |
| `scan_err_offline` | مش قادرين نوصل للسيرفر، اتأكد من النت | Can't reach the server, check your connection |
| `scan_err_timeout` | التحليل أخد وقت طويل، جرب تاني | Analysis took too long, try again |
| `scan_err_no_person_front` | مش شايفين حد في الصورة الأمامية، اتأكد إن جسمك كامل ظاهر | No person detected in the front photo |
| `scan_err_no_person_side` | مش شايفين حد في صورة الجنب، اتأكد إن جسمك كامل ظاهر | No person detected in the side photo |
| `scan_err_bad_height` | الطول اللي دخلته مش مظبوط | The height you entered isn't valid |
| `scan_err_bad_request` | حصلت مشكلة في إرسال الصور | Something went wrong sending the photos |
| `scan_err_server` | السيرفر مش متاح دلوقتي، جرب كمان شوية | Server unavailable, try again shortly |
| `camera_permission` | محتاجين إذن الكاميرا عشان نقدر نمسح جسمك | We need camera access to scan your body |

No hardcoded strings in widgets — that is a standing rule from the master prompt (§4), and
the error path is exactly where it usually gets broken.

---

## 16. Test checklist

Backend reachable:

- [ ] `curl /health` from the dev machine
- [ ] `curl /health` from the phone's browser on the same Wi-Fi
- [ ] `/scan` returns 200 with the sample `f1.png` / `s1.png` and `height_cm=175`
- [ ] `/scan-3d` returns a non-empty `.glb` (confirms `base_mesh.obj` is present)

App:

- [ ] Height below 100 / above 250 is rejected client-side, no request sent
- [ ] Both photos captured, both files exist before the request
- [ ] Real measurements appear on the result screen and differ from the old mock
      `92/78/100/172/74`
- [ ] Both photo files are **gone** after the scan (success path)
- [ ] Both photo files are **gone** after a forced failure (kill the server mid-scan)
- [ ] Leaving the screen mid-scan does not crash (`isClosed` guard)
- [ ] Server down → `scan_err_offline`, not a raw dio exception string
- [ ] Photo of an empty room → `scan_err_no_person_front`
- [ ] Measurements persist across an app restart (SharedPreferences round-trip, including
      the new nullable fields)
- [ ] A profile saved *before* this change still loads — no crash in
      `Measurements.fromJson` on the missing keys
- [ ] `useRealBodyScan = false` restores the fully offline mock flow
- [ ] `flutter analyze` is clean

---

## 17. Out of scope / still missing

Things this integration does **not** solve, listed so they are not assumed done:

- **Garment draping.** The 3D model is a bare body. Virtual try-on of an actual product does
  not exist on either side yet (backend roadmap Phase 5).
- **Authentication.** `/scan` is unauthenticated and accepts photos from anyone. Before this
  leaves a dev machine it needs a token check, request size limits, and rate limiting.
- **HTTPS.** Body photos currently travel over plain HTTP. This is acceptable on a LAN
  during development and not acceptable anywhere else.
- **Server-side retention.** `main.py` holds images in memory and never writes them to
  disk — good — but that should be verified again if the pipeline is ever refactored to use
  temp files.
- **Deployment.** There is no Dockerfile or host config in the backend repo; it runs from a
  developer machine only. The app's base URL will need to change when that lands.
