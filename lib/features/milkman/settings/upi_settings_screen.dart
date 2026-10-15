import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import 'milkman_settings.dart';

class UpiSettingsScreen extends ConsumerStatefulWidget {
  const UpiSettingsScreen({super.key});

  @override
  ConsumerState<UpiSettingsScreen> createState() => _UpiSettingsScreenState();
}

class _UpiSettingsScreenState extends ConsumerState<UpiSettingsScreen> {
  late final TextEditingController _upi;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final s = ref.read(milkmanSettingsProvider);
    _upi = TextEditingController(text: s.upiId ?? '');
    _name = TextEditingController(text: s.upiPayeeName ?? '');
  }

  @override
  void dispose() {
    _upi.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('upi_settings'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t('upi_explainer'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _upi,
              decoration: InputDecoration(
                labelText: t.t('upi_id'),
                hintText: 'ramu@oksbi',
                prefixIcon: const Icon(Icons.account_balance),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: t.t('upi_payee_name'),
                hintText: 'Ramu Milkman',
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(t.t('save')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline),
                label: Text(t.t('clear')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final upi = _upi.text.trim();
    final name = _name.text.trim();
    if (upi.isEmpty || !upi.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('invalid_upi'))),
      );
      return;
    }
    await ref
        .read(milkmanSettingsProvider.notifier)
        .setUpi(upi, name.isEmpty ? 'Milkman' : name);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.t('saved'))));
  }

  Future<void> _clear() async {
    await ref.read(milkmanSettingsProvider.notifier).clearUpi();
    if (!mounted) return;
    _upi.clear();
    _name.clear();
  }
}
