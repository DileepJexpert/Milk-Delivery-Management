import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_store.dart';

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(_initial());

  static const _key = 'locale';

  static Locale _initial() {
    final code = LocalStore.instance.settings.get(_key, defaultValue: 'en');
    return Locale(code as String);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await LocalStore.instance.settings.put(_key, locale.languageCode);
  }

  Future<void> toggle() async {
    final next = state.languageCode == 'en'
        ? const Locale('hi')
        : const Locale('en');
    await setLocale(next);
  }
}
