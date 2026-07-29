import 'package:axis_y/core/di/injector.dart';
import 'package:axis_y/core/localization/app_localizations.dart';
import 'package:axis_y/core/models/user.dart';
import 'package:axis_y/core/repositories/auth_repository.dart';
import 'package:axis_y/core/utils/result.dart';
import 'package:axis_y/features/avatar/view/avatar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only [currentUser] is read by the avatar screen; the rest of the interface
/// exists so this compiles against [AuthRepository].
class _FakeAuth implements AuthRepository {
  @override
  AppUser? currentUser;

  _FakeAuth(this.currentUser);

  @override
  bool get isLoggedIn => currentUser != null;

  @override
  Future<Result<AppUser>> register({
    required String name,
    required String phoneOrEmail,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<AppUser>> login({required String phoneOrEmail, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> verifyOtp(String otp) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> saveUser(AppUser user) => throw UnimplementedError();

  @override
  Future<Result<AppUser>> loginWithGoogle() => throw UnimplementedError();

  @override
  Future<Result<AppUser>> loginWithApple() => throw UnimplementedError();
}

/// Three-digit measurements and the longest size label — the widest the stat
/// row can legitimately get.
const _wide = Measurements(chest: 118, waist: 108, hips: 122, height: 195, weight: 105);

AppUser _user(Measurements? m) =>
    AppUser(id: 'u1', name: 'محمد', phoneOrEmail: 'a@b.c', measurements: m);

Widget _host({required Size size, required double textScale, String? nextRoute}) {
  return MaterialApp(
    locale: const Locale('ar'),
    // The same delegates `AxisYApp` installs — `DefaultMaterialLocalizations`
    // is English-only and leaves the AppBar without localizations under `ar`.
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    // Applied inside the app so the Scaffold sees the scaled text, which is
    // what drives the panel's height.
    builder: (context, child) => MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: AvatarScreen(nextRoute: nextRoute),
  );
}

/// Pumps past the mesh-resolution future.
///
/// `modelPath` is left null throughout, so `ModelStorage.resolve` short-circuits
/// without touching path_provider and the screen settles on its no-mesh state.
/// That keeps `ModelViewer` — a platform webview that cannot run under
/// `flutter test` — out of the tree while laying out the panel that actually
/// carries the overflow risk.
Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  expect(find.byType(AvatarScreen), findsOneWidget);
}

void main() {
  // `sl.reset()` is async — awaiting it matters, or the registration below is
  // wiped by a reset that lands after it.
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<AuthRepository>(_FakeAuth(_user(_wide)));
  });

  tearDown(() async => sl.reset());

  const sizes = [Size(320, 568), Size(360, 640), Size(411, 891)];
  const scales = [1.0, 1.3, 2.0];

  group('AvatarScreen never overflows', () {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('at ${size.width}px, textScale $scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          // The post-scan variant, which carries the extra "continue" button
          // and so is the taller of the two.
          await _pump(tester, _host(size: size, textScale: scale, nextRoute: '/preferences'));

          expect(find.text('118'), findsOneWidget, reason: 'stat row never rendered');
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('shows the recommended size and the try-on CTA', (tester) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, _host(size: size, textScale: 1, nextRoute: '/preferences'));

    // XXL: the size the 118cm chest maps to.
    expect(find.text('XXL'), findsOneWidget);
    expect(find.text(AppStringsProbe.tr('try_on_cta')), findsOneWidget);
    expect(find.text(AppStringsProbe.tr('avatar_continue')), findsOneWidget);
  });

  testWidgets('omits the continue button when opened from the profile', (tester) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, _host(size: size, textScale: 1));

    expect(find.text(AppStringsProbe.tr('avatar_continue')), findsNothing);
    expect(find.text(AppStringsProbe.tr('try_on_cta')), findsOneWidget);
  });

  testWidgets('renders without measurements instead of crashing', (tester) async {
    await sl.reset();
    sl.registerSingleton<AuthRepository>(_FakeAuth(_user(null)));

    const size = Size(360, 640);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pump(tester, _host(size: size, textScale: 1));

    expect(find.text('118'), findsNothing);
    expect(find.text(AppStringsProbe.tr('try_on_cta')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Resolves Arabic copy the same way the widgets do, so the assertions do not
/// hard-code strings that live in `app_strings.dart`.
abstract class AppStringsProbe {
  static String tr(String key) => const AppLocalizations(Locale('ar')).t(key);
}
