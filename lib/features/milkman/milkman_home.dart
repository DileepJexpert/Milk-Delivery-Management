import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../providers/data_providers.dart';
import '../auth/session_controller.dart';
import 'billing/billing_screen.dart';
import 'inbox/change_requests_screen.dart';
import 'societies/societies_screen.dart';
import 'todays_route/todays_route_screen.dart';

class MilkmanHome extends ConsumerStatefulWidget {
  const MilkmanHome({super.key});

  @override
  ConsumerState<MilkmanHome> createState() => _MilkmanHomeState();
}

class _MilkmanHomeState extends ConsumerState<MilkmanHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).user;
    final pages = const [
      TodaysRouteScreen(),
      SocietiesScreen(),
      ChangeRequestsScreen(),
      BillingScreen(),
    ];
    final titles = [
      t.t('milkman_home'),
      t.t('societies'),
      t.t('inbox'),
      t.t('billing'),
    ];

    final pendingCount = ref.watch(pendingChangeRequestsProvider).maybeWhen(
          data: (rows) => rows.length,
          orElse: () => 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: t.t('language'),
            icon: const Icon(Icons.translate),
            onPressed: () =>
                ref.read(localeControllerProvider.notifier).toggle(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await ref.read(sessionControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'logout',
                child: Text('${t.t('logout')} (${user?.name ?? ''})'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: t.t('milkman_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.apartment_outlined),
            selectedIcon: const Icon(Icons.apartment),
            label: t.t('societies'),
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$pendingCount'),
              isLabelVisible: pendingCount > 0,
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: const Icon(Icons.inbox),
            label: t.t('inbox'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: t.t('billing'),
          ),
        ],
      ),
    );
  }
}
