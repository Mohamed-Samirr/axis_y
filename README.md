# AXIS Y

AXIS Y is an Egyptian virtual clothing try-on app built with Flutter. Users can
browse products, create a body scan, review measurements and a 3D body model,
and try clothing virtually before purchasing. The app also includes Arabic and
English localization, cart and checkout flows, wishlists, product comparison,
notifications, and a shopping assistant.

## Features

- Body scanning from front and side images with measurement confidence
- 3D body model rendering and virtual try-on / fit checks
- Product catalog, search, product details, ratings, and store information
- Cart, checkout, orders, wishlist, and product comparison
- Arabic and English localization with a light Material theme
- Offline-friendly mock repositories for authentication and commerce flows
- Network error mapping, retry handling, secure session storage, and GLB caching

## Tech stack

- Flutter and Dart
- `flutter_bloc` / Cubit for state management
- `get_it` for dependency injection
- `go_router` for navigation
- Dio for API requests
- `camera`, `image_picker`, and `sensors_plus` for scan capture
- `model_viewer_plus` for `.glb` model viewing
- `shared_preferences` and `flutter_secure_storage` for local persistence

## Project structure

```text
lib/
  core/       Configuration, models, repositories, networking, routing, theme
  features/   Feature-specific screens, Cubits, and UI
  app.dart    Root application and shared providers
  main.dart   Application entry point
test/         Unit and widget tests
```

The UI depends on repository interfaces rather than directly on HTTP or local
storage. Implementations are selected in `lib/core/di/injector.dart`, which
keeps the presentation layer independent of the backend.

## Requirements

- Flutter SDK compatible with Dart `3.9.2` or newer
- Android Studio / Android SDK for Android builds
- Xcode and CocoaPods for iOS builds

## Getting started

```bash
flutter pub get
flutter run
```

Run the test suite with:

```bash
flutter test
```

## Configuration

Runtime feature switches and API settings are defined in
`lib/core/config/app_config.dart`:

- `useMockData` keeps authentication and commerce repositories local.
- `useRealBodyScan` enables the body scan API.
- `useRealCatalog` enables the backend product catalog.
- `useRealTryOn` enables fit-check and virtual try-on requests.

The default API base URL can be overridden without changing source code:

```bash
flutter run --dart-define=AXIS_API_BASE=http://10.0.2.2:8000
```

Annotated scan frames are enabled in debug builds. To enable them in another
build mode, pass:

```bash
flutter run --dart-define=AXIS_ANNOTATED_SCAN=true
```

The body scan API expects front and side images plus a height in centimeters.
See [BODY_SCAN_API_INTEGRATION.md](BODY_SCAN_API_INTEGRATION.md) for endpoint
contracts, local backend setup, image orientation handling, and privacy notes.

## Development notes

- Body scan, catalog, and try-on can use the deployed API independently.
- Authentication, cart, wishlist, orders, notifications, and assistant flows
  currently use mock or local implementations when `useMockData` is enabled.
- The app is designed to remain usable with mock data while backend services
  are developed.
- Do not commit credentials, API keys, generated signing files, or user scan
  images.

## Related documentation

- [Body Scan API Integration](BODY_SCAN_API_INTEGRATION.md)
- [Firebase Authentication Plan](FIREBASE_AUTH_PLAN.md)
- [Flutter Integration Guide](flutter_integration_guide.md)
- [AXIS Y Master Prompt](AXIS_Y_MASTER_PROMPT.md)
