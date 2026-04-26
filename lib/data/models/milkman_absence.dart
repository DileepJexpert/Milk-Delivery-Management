class MilkmanAbsence {
  MilkmanAbsence({
    required this.id,
    required this.milkmanId,
    required this.fromDateKey,
    required this.toDateKey,
    this.reason,
    required this.isRecurring,
    this.recurringDayOfWeek,
    this.notifiedAt,
  });

  final String id;
  final String milkmanId;
  /// `yyyy-MM-dd` — for recurring entries this is just a reference anchor.
  final String fromDateKey;
  final String toDateKey;
  final String? reason;
  /// If true, absence repeats every [recurringDayOfWeek] (1=Mon … 7=Sun).
  final bool isRecurring;
  final int? recurringDayOfWeek;
  final DateTime? notifiedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'milkmanId': milkmanId,
        'fromDateKey': fromDateKey,
        'toDateKey': toDateKey,
        'reason': reason,
        'isRecurring': isRecurring,
        'recurringDayOfWeek': recurringDayOfWeek,
        'notifiedAt': notifiedAt?.toIso8601String(),
      };

  factory MilkmanAbsence.fromJson(Map json) => MilkmanAbsence(
        id: json['id'] as String,
        milkmanId: json['milkmanId'] as String,
        fromDateKey: json['fromDateKey'] as String,
        toDateKey: json['toDateKey'] as String,
        reason: json['reason'] as String?,
        isRecurring: json['isRecurring'] as bool? ?? false,
        recurringDayOfWeek: json['recurringDayOfWeek'] as int?,
        notifiedAt: json['notifiedAt'] == null
            ? null
            : DateTime.parse(json['notifiedAt'] as String),
      );

  MilkmanAbsence copyWith({DateTime? notifiedAt}) => MilkmanAbsence(
        id: id,
        milkmanId: milkmanId,
        fromDateKey: fromDateKey,
        toDateKey: toDateKey,
        reason: reason,
        isRecurring: isRecurring,
        recurringDayOfWeek: recurringDayOfWeek,
        notifiedAt: notifiedAt ?? this.notifiedAt,
      );
}
