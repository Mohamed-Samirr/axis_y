import 'package:axis_y/core/models/catalog.dart';
import 'package:axis_y/features/home/view/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The carousel advances with `_index % banners.length`, which throws
/// IntegerDivisionByZeroException on an empty list — and the real product API
/// has no banner table at all, so an empty list is the normal case there.
void main() {
  Widget wrap(List<AppBanner> banners) =>
      MaterialApp(home: Scaffold(body: BannerSlider(banners: banners)));

  testWidgets('empty banner list never divides by zero', (tester) async {
    await tester.pumpWidget(wrap(const []));

    // The rotation timer fires every 5s; pumping past it is what used to throw.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a single banner renders and starts no rotation', (tester) async {
    await tester.pumpWidget(wrap(const [AppBanner(id: 'b1', image: '', title: 'Solo')]));
    await tester.pump(const Duration(seconds: 6));

    expect(tester.takeException(), isNull);
    expect(find.text('Solo'), findsOneWidget);
  });

  testWidgets('two banners still rotate', (tester) async {
    await tester.pumpWidget(wrap(const [
      AppBanner(id: 'b1', image: '', title: 'One'),
      AppBanner(id: 'b2', image: '', title: 'Two'),
    ]));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Two'), findsOneWidget);
  });
}
