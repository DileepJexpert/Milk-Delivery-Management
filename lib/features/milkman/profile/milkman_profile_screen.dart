import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/local/local_store.dart';
import '../../../data/models/user.dart';
import '../../auth/session_controller.dart';
import '../absences/manage_absences_screen.dart';
import '../catalog/catalog_screen.dart';

class MilkmanProfileScreen extends ConsumerStatefulWidget {
  const MilkmanProfileScreen({super.key});

  @override
  ConsumerState<MilkmanProfileScreen> createState() =>
      _MilkmanProfileScreenState();
}

class _MilkmanProfileScreenState extends ConsumerState<MilkmanProfileScreen> {
  late TextEditingController _nameController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

          // Manage catalog
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(t.t('catalog')),
              subtitle: Text(t.t('manage_products')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CatalogScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

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
