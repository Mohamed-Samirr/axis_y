import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_store.dart';

/// Controls the app locale (Arabic default) and persists the choice.
class LocaleCubit extends Cubit<Locale> {
  final LocalStore _store;

  LocaleCubit(this._store) : super(const Locale('ar')) {
    final code = _store.getString(StoreKeys.locale);
    if (code != null) emit(Locale(code));
  }

  void setLocale(String code) {
    _store.setString(StoreKeys.locale, code);
    emit(Locale(code));
  }

  void toggle() => setLocale(state.languageCode == 'ar' ? 'en' : 'ar');
}
