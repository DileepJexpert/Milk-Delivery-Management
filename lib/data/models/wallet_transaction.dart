enum WalletTxnType { topup, debit, refund }

class WalletTxn {
  WalletTxn({
    required this.id,
    required this.flatId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.timestamp,
    required this.actorUserId,
    required this.actorName,
    this.reason,
    this.relatedDeliveryId,
  });

  final String id;
  final String flatId;
  final WalletTxnType type;

  /// Always positive; sign is implied by [type] (topup/refund credit, debit debit).
  final double amount;
  final double balanceAfter;
  final DateTime timestamp;
  final String actorUserId;
  final String actorName;
  final String? reason;

  /// When this transaction is the auto-debit for a specific delivery, this is
  /// that delivery's id — used to make the audit chain reconstructable.
  final String? relatedDeliveryId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'type': type.name,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'timestamp': timestamp.toIso8601String(),
        'actorUserId': actorUserId,
        'actorName': actorName,
        'reason': reason,
        'relatedDeliveryId': relatedDeliveryId,
      };

  factory WalletTxn.fromJson(Map json) => WalletTxn(
        id: json['id'] as String,
        flatId: json['flatId'] as String,
        type: WalletTxnType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => WalletTxnType.topup,
        ),
        amount: (json['amount'] as num).toDouble(),
        balanceAfter: (json['balanceAfter'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        actorUserId: json['actorUserId'] as String,
        actorName: json['actorName'] as String,
        reason: json['reason'] as String?,
        relatedDeliveryId: json['relatedDeliveryId'] as String?,
      );
}
