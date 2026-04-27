import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    // After signOut(), user is briefly null before MaterialApp swaps the
    // home widget to LoginScreen. Bail out so we don't render the
    // unlinked-subscriber screen for one frame mid-logout.
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    if (flat == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('app_title')), actions: _actions(context)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.link_off, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  t.t('unlinked_subscriber'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  t.t('unlinked_explainer'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(t.t('your_phone'),
                            style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 4),
                        SelectableText(
                          user?.phone ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: user == null
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: user.phone));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(t.t('copied'))),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.copy),
                          label: Text(t.t('copy')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(t.t('try_demo'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(t.t('demo_subscriber_hint')),
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
        onSelected: (v) {
          if (v == 'logout') {
            // Defer to the next frame so the popup's closing animation
            // finishes before the session swap replaces this widget tree.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(sessionControllerProvider.notifier).signOut();
            });
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'logout', child: Text(t.t('logout'))),
        ],
      ),
    ];
  }
}
