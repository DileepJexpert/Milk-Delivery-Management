enum AuditChangeType {
  deliveryMarked,
  quantityChanged,
  paused,
  unpaused,
  flatCreated,
  flatUpdated,
  changeRequestCreated,
  changeRequestApplied,
}

class AuditLog {
  AuditLog({
    required this.id,
    required this.flatId,
    required this.changedByUserId,
    required this.changedByName,
    required this.changedByPhone,
    required this.changeType,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    this.reason,
  });

  final String id;
  final String flatId;
  final String changedByUserId;
  final String changedByName;
  final String changedByPhone;
  final AuditChangeType changeType;
  final String oldValue;
  final String newValue;
  final DateTime timestamp;
  final String? reason;

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'changedByUserId': changedByUserId,
        'changedByName': changedByName,
        'changedByPhone': changedByPhone,
        'changeType': changeType.name,
        'oldValue': oldValue,
        'newValue': newValue,
        'timestamp': timestamp.toIso8601String(),
        'reason': reason,
      };

  factory AuditLog.fromJson(Map json) => AuditLog(
        id: json['id'] as String,
        flatId: json['flatId'] as String,
        changedByUserId: json['changedByUserId'] as String,
        changedByName: json['changedByName'] as String,
        changedByPhone: json['changedByPhone'] as String,
        changeType: AuditChangeType.values.firstWhere(
          (c) => c.name == json['changeType'],
          orElse: () => AuditChangeType.flatUpdated,
        ),
        oldValue: (json['oldValue'] ?? '') as String,
        newValue: (json['newValue'] ?? '') as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        reason: json['reason'] as String?,
      );
}
