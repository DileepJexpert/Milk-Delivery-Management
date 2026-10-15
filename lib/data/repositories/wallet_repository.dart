import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/flat.dart';
import '../models/user.dart';
import '../models/wallet_transaction.dart';
import 'audit_repository.dart';
import 'flat_repository.dart';

class WalletRepository {
  WalletRepository(this._flats, this._audit);

  final FlatRepository _flats;
  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<WalletTxn>> watchForFlat(String flatId) async* {
    yield _allForFlat(flatId);
    yield* LocalStore.instance.walletTxns
        .watch()
        .map((_) => _allForFlat(flatId));
  }

  List<WalletTxn> _allForFlat(String flatId) =>
      LocalStore.instance.walletTxns.values
          .whereType<Map>()
          .map(WalletTxn.fromJson)
          .where((t) => t.flatId == flatId)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  Future<WalletTxn> topup(
    Flat flat,
    AppUser actor,
    double amount, {
    String? reason,
  }) async {
    if (amount <= 0) throw ArgumentError('amount must be positive');
    final newBalance = flat.walletBalance + amount;
    final txn = WalletTxn(
      id: _uuid.v4(),
      flatId: flat.id,
      type: WalletTxnType.topup,
      amount: amount,
      balanceAfter: newBalance,
      timestamp: DateTime.now(),
      actorUserId: actor.id,
      actorName: actor.name,
      reason: reason,
    );
    await _persist(txn);
    await _flats.update(flat.copyWith(walletBalance: newBalance));
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.walletTopup,
      oldValue: '₹${flat.walletBalance.toStringAsFixed(2)}',
      newValue: '₹${newBalance.toStringAsFixed(2)}',
      reason: reason,
    );
    return txn;
  }

  /// Auto-debit on delivery. Allows the balance to go negative so a milkman
  /// isn't blocked from delivering; the negative balance becomes a postpaid
  /// dues amount the customer needs to top up.
  Future<WalletTxn> debit(
    Flat flat,
    AppUser actor,
    double amount, {
    required String relatedDeliveryId,
    String? reason,
  }) async {
    if (amount <= 0) throw ArgumentError('amount must be positive');
    final newBalance = flat.walletBalance - amount;
    final txn = WalletTxn(
      id: _uuid.v4(),
      flatId: flat.id,
      type: WalletTxnType.debit,
      amount: amount,
      balanceAfter: newBalance,
      timestamp: DateTime.now(),
      actorUserId: actor.id,
      actorName: actor.name,
      reason: reason,
      relatedDeliveryId: relatedDeliveryId,
    );
    await _persist(txn);
    await _flats.update(flat.copyWith(walletBalance: newBalance));
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.walletDebit,
      oldValue: '₹${flat.walletBalance.toStringAsFixed(2)}',
      newValue: '₹${newBalance.toStringAsFixed(2)}',
      reason: reason ?? 'delivery',
    );
    return txn;
  }

  Future<WalletTxn> refund(
    Flat flat,
    AppUser actor,
    double amount, {
    String? reason,
    String? relatedDeliveryId,
  }) async {
    if (amount <= 0) throw ArgumentError('amount must be positive');
    final newBalance = flat.walletBalance + amount;
    final txn = WalletTxn(
      id: _uuid.v4(),
      flatId: flat.id,
      type: WalletTxnType.refund,
      amount: amount,
      balanceAfter: newBalance,
      timestamp: DateTime.now(),
      actorUserId: actor.id,
      actorName: actor.name,
      reason: reason,
      relatedDeliveryId: relatedDeliveryId,
    );
    await _persist(txn);
    await _flats.update(flat.copyWith(walletBalance: newBalance));
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.walletRefund,
      oldValue: '₹${flat.walletBalance.toStringAsFixed(2)}',
      newValue: '₹${newBalance.toStringAsFixed(2)}',
      reason: reason,
    );
    return txn;
  }

  Future<void> _persist(WalletTxn t) async {
    await LocalStore.instance.walletTxns.put(t.id, t.toJson());
    await SyncQueue.instance.enqueue('upsert', 'wallet_txns', t.toJson());
  }
}
