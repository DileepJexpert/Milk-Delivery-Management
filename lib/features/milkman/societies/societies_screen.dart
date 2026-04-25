import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';
import 'society_detail_screen.dart';

class SocietiesScreen extends ConsumerWidget {
  const SocietiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(societiesForCurrentMilkmanProvider);
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(child: Text(t.t('no_societies')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = rows[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.apartment)),
                  title: Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(s.address),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SocietyDetailScreen(societyId: s.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t.t('add_society')),
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final user = ref.read(sessionControllerProvider).user;
    if (user == null) return;
    final nameC = TextEditingController();
    final addrC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('add_society')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: InputDecoration(labelText: t.t('society_name')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addrC,
              decoration: InputDecoration(labelText: t.t('society_address')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.t('save'))),
        ],
      ),
    );
    if (ok == true && nameC.text.trim().isNotEmpty) {
      await ref.read(societyRepositoryProvider).create(
            milkmanId: user.id,
            name: nameC.text.trim(),
            address: addrC.text.trim(),
          );
    }
  }
}
