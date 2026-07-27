import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injector.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_cubit.dart';
import 'core/data/local_store.dart';
import 'core/repositories/cart_repository.dart';
import 'core/repositories/wishlist_repository.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/cart_checkout/cubit/cart_cubit.dart';
import 'features/compare/cubit/compare_cubit.dart';
import 'features/wishlist/cubit/wishlist_cubit.dart';

class AxisYApp extends StatelessWidget {
  const AxisYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit(sl<LocalStore>())),
        BlocProvider(create: (_) => CartCubit(sl<CartRepository>())),
        BlocProvider(create: (_) => WishlistCubit(sl<WishlistRepository>())),
        BlocProvider(create: (_) => CompareCubit()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp.router(
            title: 'AXIS Y',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Several cards (e.g. ProductCard) use tightly-budgeted fixed
            // heights; an unclamped system font size overflows them.
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
              child: child!,
            ),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
