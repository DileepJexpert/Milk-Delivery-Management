import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations.dart';
import 'core/localization/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_controller.dart';
import 'features/milkman/milkman_home.dart';
import 'features/subscriber/subscriber_home.dart';
import 'data/models/user.dart';

class MilkDeliveryApp extends ConsumerWidget {
  const MilkDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final session = ref.watch(sessionControllerProvider);

    return MaterialApp(
      title: 'Milk Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _homeFor(session),
    );
  }

  Widget _homeFor(SessionState session) {
    final user = session.user;
    if (user == null) return const LoginScreen();
    return switch (user.role) {
      UserRole.milkman => const MilkmanHome(),
      UserRole.subscriber => const SubscriberHome(),
    };
  }
}
