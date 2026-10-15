import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/upi_payment.dart';
import '../../../data/local/local_store.dart';
import '../../../data/models/user.dart';
import '../../auth/session_controller.dart';
import '../absences/manage_absences_screen.dart';

class MilkmanProfileScreen extends ConsumerStatefulWidget {
  const MilkmanProfileScreen({super.key});

  @override
  ConsumerState<MilkmanProfileScreen> createState() =>
      _MilkmanProfileScreenState();
}

class _MilkmanProfileScreenState extends ConsumerState<MilkmanProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _upiController;
  bool _editing = false;
  bool _editingUpi = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _upiController = TextEditingController(
      text: LocalStore.instance.settings.get('custom_upi_vpa') as String? ??
          UpiPayment.defaultVpa,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _saveUpi() async {
    final newUpi = _upiController.text.trim();
    if (newUpi.isEmpty || !newUpi.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid UPI ID (e.g. mobile@upi)'),
        ),
      );
      return;
    }
    await LocalStore.instance.settings.put('custom_upi_vpa', newUpi);
    setState(() => _editingUpi = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('UPI ID updated to $newUpi')),
      );
    }
  }

  Future<void> _saveName(AppUser user) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    final updated = user.copyWith(name: newName);
    await LocalStore.instance.users.put(updated.id, updated.toJson());
    // Refresh session state so the app bar / popup reflects the new name.
    await ref
        .read(sessionControllerProvider.notifier)
        .verifyOtp(
          phone: updated.phone,
          otp: '123456',
          name: newName,
          role: updated.role,
        );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).user;
    // After signOut, the route can briefly rebuild before the navigator pops.
    // Return an empty Scaffold so layout constraints are satisfied.
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_editing)
            IconButton(
              tooltip: 'Edit name',
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar circle with initials
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                user.name.isNotEmpty
                    ? user.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  if (_editing)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            decoration: const InputDecoration(
                                hintText: 'Your name'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _saveName(user),
                          child: Text(t.t('save')),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: () {
                            _nameController.text = user.name;
                            setState(() => _editing = false);
                          },
                          child: Text(t.t('cancel')),
                        ),
                      ],
                    )
                  else
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Phone
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phone',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '+${user.phone}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: t.t('copy'),
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: user.phone));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.t('copied'))),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Role
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined),
                      const SizedBox(width: 8),
                      Text(
                        t.t('role_milkman'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // UPI ID for Payments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('UPI ID for Receiving Payments',
                          style: Theme.of(context).textTheme.labelMedium),
                      if (!_editingUpi)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit UPI ID',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _editingUpi = true),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_editingUpi)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _upiController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'e.g. mobile@upi or name@bank',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saveUpi,
                          child: Text(t.t('save')),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          onPressed: () {
                            _upiController.text = LocalStore.instance.settings.get('custom_upi_vpa') as String? ??
                                UpiPayment.defaultVpa;
                            setState(() => _editingUpi = false);
                          },
                          child: Text(t.t('cancel')),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.qr_code_2, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _upiController.text,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: t.t('copy'),
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: _upiController.text));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(t.t('copied'))),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Used to generate dynamic QR codes and direct payment links on monthly invoices.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Manage absences
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy),
              title: Text(t.t('manage_absences')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageAbsencesScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          OutlinedButton.icon(
            onPressed: () async {
              // Pop this route before clearing the session so the home widget
              // can swap to LoginScreen cleanly without an orphaned profile
              // screen on the navigator stack.
              final notifier = ref.read(sessionControllerProvider.notifier);
              Navigator.of(context).pop();
              await notifier.signOut();
            },
            icon: const Icon(Icons.logout),
            label: Text(t.t('logout')),
          ),
        ],
      ),
    );
  }
}
