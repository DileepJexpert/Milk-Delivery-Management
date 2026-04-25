import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../providers/data_providers.dart';
import '../auth/session_controller.dart';
import 'bill_screen.dart';
import 'history_screen.dart';
import 'today_screen.dart';

class SubscriberHome extends ConsumerStatefulWidget {
  const SubscriberHome({super.key});

  @override
  ConsumerState<SubscriberHome> createState() => _SubscriberHomeState();
}

class _SubscriberHomeState extends ConsumerState<SubscriberHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(myFlatProvider);
    final user = ref.watch(sessionControllerProvider).user;

    if (flat == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('app_title')), actions: _actions(context)),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 56),
                const SizedBox(height: 12),
                Text(t.t('unlinked_subscriber'),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text('${t.t('logged_in_as')}: ${user?.phone ?? ''}'),
              ],
            ),
          ),
        ),
      );
    }

    final pages = const [
      TodayScreen(),
      HistoryScreen(),
      BillScreen(),
    ];
    final titles = [
      t.t('subscriber_today'),
      t.t('subscriber_history'),
      t.t('subscriber_bill'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index]), actions: _actions(context)),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: t.t('subscriber_today'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: t.t('subscriber_history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: t.t('subscriber_bill'),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      IconButton(
        tooltip: t.t('language'),
        icon: const Icon(Icons.translate),
        onPressed: () => ref.read(localeControllerProvider.notifier).toggle(),
      ),
      PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'logout') {
            await ref.read(sessionControllerProvider.notifier).signOut();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'logout', child: Text(t.t('logout'))),
        ],
      ),
    ];
  }
}
