import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/models/daily_delivery.dart';
import '../../../data/models/flat.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';
import 'subscriptions_screen.dart';
import 'wallet_screen.dart';

class FlatDetailScreen extends ConsumerStatefulWidget {
  const FlatDetailScreen({super.key, required this.flatId});

  final String flatId;

  @override
  ConsumerState<FlatDetailScreen> createState() => _FlatDetailScreenState();
}

class _FlatDetailScreenState extends ConsumerState<FlatDetailScreen> {
  // ── Record a one-off quantity change for a specific date ──────────────────
  Future<void> _showRecordChangeDialog() async {
    final t = AppLocalizations.of(context);
    final flat = ref.read(flatRepositoryProvider).byId(widget.flatId);
    if (flat == null) return;

    final qtyCtrl = TextEditingController(text: flat.defaultQuantity.toString());
    final reasonCtrl = TextEditingController();
    DateTime selectedDate = AppDates.today();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(t.t('record_qty_change')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(AppDates.dateKey(selectedDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setInner(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.t('change_qty_dialog')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(labelText: t.t('reason_optional')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('save'))),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final newQty = double.tryParse(qtyCtrl.text.trim());
    if (newQty == null || newQty <= 0) return;
    final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
    final actor = ref.read(sessionControllerProvider).user!;
    final deliveryRepo = ref.read(deliveryRepositoryProvider);
    // Apply to all active subscriptions on this flat for the chosen date. Most
    // flats have a single (cow milk) subscription; for multi-product flats the
    // milkman can fine-tune from Today's Route instead.
    final subs = deliveryRepo.subscriptionsForFlat(flat.id);
    for (final sub in subs) {
      final row =
          deliveryRepo.ensureForSubscription(flat, sub, when: selectedDate);
      await deliveryRepo.setQuantity(row, actor, newQty, reason: reason);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('change_recorded'))),
      );
    }
  }

  // ── Edit flat details ─────────────────────────────────────────────────────
  Future<void> _showEditDialog(Flat flat) async {
    final t = AppLocalizations.of(context);
    final flatNoCtrl = TextEditingController(text: flat.flatNumber);
    final ownerCtrl = TextEditingController(text: flat.ownerName);
    final phoneCtrl = TextEditingController(text: flat.ownerPhone);
    final qtyCtrl = TextEditingController(text: flat.defaultQuantity.toString());
    final priceCtrl = TextEditingController(text: flat.pricePerLitre.toString());
    bool hasApp = flat.hasApp;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(t.t('edit_flat')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: flatNoCtrl,
                  decoration: InputDecoration(labelText: t.t('flat_number')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ownerCtrl,
                  decoration: InputDecoration(labelText: t.t('owner_name')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: t.t('owner_phone')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.t('default_quantity')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.t('price_per_litre')),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(t.t('has_app')),
                  value: hasApp,
                  onChanged: (v) => setInner(() => hasApp = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('save'))),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final actor = ref.read(sessionControllerProvider).user!;
    await ref.read(flatRepositoryProvider).editFlat(
          flat,
          actor,
          flatNumber: flatNoCtrl.text.trim().isEmpty ? null : flatNoCtrl.text.trim(),
          ownerName: ownerCtrl.text.trim().isEmpty ? null : ownerCtrl.text.trim(),
          ownerPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          hasApp: hasApp,
          defaultQuantity: double.tryParse(qtyCtrl.text),
          pricePerLitre: double.tryParse(priceCtrl.text),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('flat_updated'))),
      );
    }
  }

  // ── Pause / Resume / Stop with reason dialog ──────────────────────────────
  Future<void> _showLifecycleDialog(
    Flat flat, {
    required String title,
    required String confirmKey,
    required Future<void> Function(String? reason) onConfirm,
  }) async {
    final t = AppLocalizations.of(context);
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(labelText: t.t('reason_optional')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t(confirmKey))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
    await onConfirm(reason);
  }

  Future<void> _pauseFlat(Flat flat) => _showLifecycleDialog(
        flat,
        title: AppLocalizations.of(context).t('pause_flat'),
        confirmKey: 'pause_flat_confirm',
        onConfirm: (reason) async {
          final actor = ref.read(sessionControllerProvider).user!;
          await ref.read(flatRepositoryProvider).pauseFlat(flat, actor, reason: reason);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('flat_paused'))));
          }
        },
      );

  Future<void> _resumeFlat(Flat flat) => _showLifecycleDialog(
        flat,
        title: AppLocalizations.of(context).t('resume_flat'),
        confirmKey: 'resume_flat_confirm',
        onConfirm: (reason) async {
          final actor = ref.read(sessionControllerProvider).user!;
          await ref.read(flatRepositoryProvider).resumeFlat(flat, actor, reason: reason);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('flat_resumed'))));
          }
        },
      );

  Future<void> _stopFlat(Flat flat) => _showLifecycleDialog(
        flat,
        title: AppLocalizations.of(context).t('stop_flat'),
        confirmKey: 'stop_flat_confirm',
        onConfirm: (reason) async {
          final actor = ref.read(sessionControllerProvider).user!;
          await ref.read(flatRepositoryProvider).stopFlat(flat, actor, reason: reason);
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('flat_stopped'))));
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(flatRepositoryProvider).byId(widget.flatId);
    final audit = ref.watch(auditForFlatProvider(widget.flatId));
    final history = ref.watch(deliveriesForFlatProvider(widget.flatId));

    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found')));
    }

    final scheme = Theme.of(context).colorScheme;
    final status = flat.status;

    return Scaffold(
      appBar: AppBar(
        title: Text('Flat ${flat.flatNumber} — ${flat.ownerName}'),
        actions: [
          IconButton(
            tooltip: t.t('edit_flat'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(flat),
          ),
        ],
      ),
      floatingActionButton: status != FlatStatus.stopped
          ? FloatingActionButton.extended(
              onPressed: _showRecordChangeDialog,
              icon: const Icon(Icons.edit_note),
              label: Text(t.t('record_qty_change')),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── Status card ──────────────────────────────────────────────────
          _StatusCard(flat: flat, onPause: _pauseFlat, onResume: _resumeFlat, onStop: _stopFlat),
          const SizedBox(height: 12),

          // ── Subscriptions + Wallet quick nav ─────────────────────────────
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.subscriptions_outlined),
                  title: Text(t.t('manage_subscriptions')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionsScreen(flatId: flat.id),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(t.t('wallet')),
                  subtitle: Text(
                    '${t.t('wallet_balance')}: ₹${flat.walletBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: flat.walletBalance < 0 ? Colors.red : null,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WalletScreen(flatId: flat.id),
                    ),
                  ),
                ),
                const Divider(height: 1),
                _BillingModeRow(flat: flat),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Info card ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(label: t.t('owner_phone'), value: flat.ownerPhone),
                  _InfoRow(label: t.t('default_quantity'), value: '${flat.defaultQuantity}L/day'),
                  _InfoRow(label: t.t('price_per_litre'), value: '₹${flat.pricePerLitre.toStringAsFixed(2)}/L'),
                  _InfoRow(label: 'App', value: flat.hasApp ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Delivery history ─────────────────────────────────────────────
          Text(t.t('subscriber_history'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) Text(t.t('no_history')),
                for (final r in rows.take(20))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      r.status == DeliveryStatus.delivered ? Icons.check_circle : Icons.cancel,
                      color: r.status == DeliveryStatus.delivered ? Colors.green : Colors.orange,
                    ),
                    title: Text(r.dateKey),
                    trailing: Text('${r.actualQuantity}L'),
                    subtitle: Text(r.status.name),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Audit log ────────────────────────────────────────────────────
          Text(t.t('audit_log'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          audit.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(t.t('no_audit'), style: TextStyle(color: scheme.outline)),
                  ),
                for (final a in rows) _AuditTile(a: a),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.flat,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final Flat flat;
  final Future<void> Function(Flat) onPause;
  final Future<void> Function(Flat) onResume;
  final Future<void> Function(Flat) onStop;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final status = flat.status;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case FlatStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusLabel = t.t('flat_status_active');
        break;
      case FlatStatus.paused:
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle_outline;
        statusLabel = t.t('flat_status_paused');
        break;
      case FlatStatus.stopped:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_outlined;
        statusLabel = t.t('flat_status_stopped');
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == FlatStatus.active) ...[
                  OutlinedButton.icon(
                    onPressed: () => onPause(flat),
                    icon: const Icon(Icons.pause),
                    label: Text(t.t('pause_flat')),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onStop(flat),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(t.t('stop_flat')),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
                if (status == FlatStatus.paused) ...[
                  FilledButton.icon(
                    onPressed: () => onResume(flat),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(t.t('resume_flat')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onStop(flat),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(t.t('stop_flat')),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
                if (status == FlatStatus.stopped)
                  FilledButton.icon(
                    onPressed: () => onResume(flat),
                    icon: const Icon(Icons.refresh),
                    label: Text(t.t('resume_flat')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.a});

  final AuditLog a;

  static const _lifecycleTypes = {
    AuditChangeType.flatPaused,
    AuditChangeType.flatResumed,
    AuditChangeType.flatStopped,
    AuditChangeType.flatUpdated,
    AuditChangeType.flatCreated,
  };

  Color _chipColor(AuditChangeType t, BuildContext ctx) {
    switch (t) {
      case AuditChangeType.flatPaused:
        return Colors.orange;
      case AuditChangeType.flatStopped:
        return Colors.red;
      case AuditChangeType.flatResumed:
        return Colors.green;
      case AuditChangeType.deliveryMarked:
        return Colors.green;
      case AuditChangeType.quantityChanged:
        return Colors.blue;
      default:
        return Theme.of(ctx).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = _chipColor(a.changeType, context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(_typeIcon(a.changeType), color: color, size: 16),
        ),
        title: Text(_typeLabel(a.changeType, t)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_lifecycleTypes.contains(a.changeType))
              Text('${t.t('old')}: ${a.oldValue}  →  ${t.t('new')}: ${a.newValue}'),
            if (_lifecycleTypes.contains(a.changeType) && a.oldValue != a.newValue)
              Text('${a.oldValue} → ${a.newValue}'),
            Text('${t.t('by')} ${a.changedByName}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${AppDates.prettyDate(a.timestamp, locale: Localizations.localeOf(context).languageCode)}'
              '  ${TimeOfDay.fromDateTime(a.timestamp).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (a.reason != null && a.reason!.isNotEmpty)
              Text('"${a.reason}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(AuditChangeType t) {
    switch (t) {
      case AuditChangeType.deliveryMarked:
        return Icons.check_circle_outline;
      case AuditChangeType.quantityChanged:
        return Icons.edit_outlined;
      case AuditChangeType.flatPaused:
        return Icons.pause_circle_outline;
      case AuditChangeType.flatResumed:
        return Icons.play_circle_outline;
      case AuditChangeType.flatStopped:
        return Icons.cancel_outlined;
      case AuditChangeType.flatUpdated:
        return Icons.edit_note;
      case AuditChangeType.flatCreated:
        return Icons.add_circle_outline;
      case AuditChangeType.changeRequestCreated:
        return Icons.send_outlined;
      case AuditChangeType.changeRequestApplied:
        return Icons.done_all;
      default:
        return Icons.history;
    }
  }

  String _typeLabel(AuditChangeType t, AppLocalizations loc) {
    switch (t) {
      case AuditChangeType.deliveryMarked:
        return loc.t('delivered');
      case AuditChangeType.quantityChanged:
        return loc.t('record_qty_change');
      case AuditChangeType.flatPaused:
        return loc.t('flat_paused');
      case AuditChangeType.flatResumed:
        return loc.t('flat_resumed');
      case AuditChangeType.flatStopped:
        return loc.t('flat_stopped');
      case AuditChangeType.flatUpdated:
        return loc.t('flat_updated');
      case AuditChangeType.flatCreated:
        return loc.t('add_flat');
      case AuditChangeType.changeRequestCreated:
        return loc.t('change_requests');
      case AuditChangeType.changeRequestApplied:
        return loc.t('apply');
      case AuditChangeType.paused:
        return loc.t('paused');
      default:
        return t.name;
    }
  }
}

class _BillingModeRow extends ConsumerWidget {
  const _BillingModeRow({required this.flat});
  final Flat flat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.t('billing_mode'),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                SegmentedButton<BillingMode>(
                  segments: [
                    ButtonSegment(
                      value: BillingMode.prepaid,
                      label: Text(t.t('billing_prepaid')),
                    ),
                    ButtonSegment(
                      value: BillingMode.postpaid,
                      label: Text(t.t('billing_postpaid')),
                    ),
                  ],
                  selected: {flat.billingMode},
                  onSelectionChanged: (s) async {
                    final actor = ref.read(sessionControllerProvider).user!;
                    await ref
                        .read(flatRepositoryProvider)
                        .setBillingMode(flat, actor, s.first);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
