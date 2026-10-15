enum SubscriptionStatus { active, stopped }

/// How often a subscription delivers.
/// * daily — every day
/// * alternateDays — every other day, anchored to createdAt
/// * weekdaysOnly — Mon–Fri
/// * weekendsOnly — Sat–Sun
/// * custom — uses [Subscription.weekDays] list (1=Mon … 7=Sun)
enum SchedulePattern { daily, alternateDays, weekdaysOnly, weekendsOnly, custom }

extension SchedulePatternDisplay on SchedulePattern {
  String get key {
    switch (this) {
      case SchedulePattern.daily:
        return 'sched_daily';
      case SchedulePattern.alternateDays:
        return 'sched_alternate';
      case SchedulePattern.weekdaysOnly:
        return 'sched_weekdays';
      case SchedulePattern.weekendsOnly:
        return 'sched_weekends';
      case SchedulePattern.custom:
        return 'sched_custom';
    }
  }
}

/// Per-flat, per-product daily subscription. Quantity is in the product's unit
/// (litres, kg, pieces). Price snapshot is taken when the subscription is
/// created so price changes at the catalog level don't retroactively change
/// past deliveries.
class Subscription {
  Subscription({
    required this.id,
    required this.flatId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.status,
    required this.createdAt,
    this.pattern = SchedulePattern.daily,
    this.weekDays = const [1, 2, 3, 4, 5, 6, 7],
  });

  final String id;
  final String flatId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final SubscriptionStatus status;
  final DateTime createdAt;
  final SchedulePattern pattern;

  /// Only relevant when [pattern] is [SchedulePattern.custom].
  /// Each entry is a `DateTime.weekday` (1=Mon … 7=Sun).
  final List<int> weekDays;

  /// True if this subscription should deliver on [date] given its pattern.
  bool isActiveOn(DateTime date) {
    switch (pattern) {
      case SchedulePattern.daily:
        return true;
      case SchedulePattern.alternateDays:
        final created = DateTime(
            createdAt.year, createdAt.month, createdAt.day);
        final d = DateTime(date.year, date.month, date.day);
        final diff = d.difference(created).inDays;
        return diff >= 0 && diff % 2 == 0;
      case SchedulePattern.weekdaysOnly:
        return date.weekday >= 1 && date.weekday <= 5;
      case SchedulePattern.weekendsOnly:
        return date.weekday == 6 || date.weekday == 7;
      case SchedulePattern.custom:
        return weekDays.contains(date.weekday);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'pattern': pattern.name,
        'weekDays': weekDays,
      };

  factory Subscription.fromJson(Map json) => Subscription(
        id: json['id'] as String,
        flatId: json['flatId'] as String,
        productId: json['productId'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        status: SubscriptionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SubscriptionStatus.active,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        pattern: SchedulePattern.values.firstWhere(
          (p) => p.name == (json['pattern'] as String? ?? ''),
          orElse: () => SchedulePattern.daily,
        ),
        weekDays: (json['weekDays'] as List?)
                ?.whereType<num>()
                .map((n) => n.toInt())
                .toList() ??
            const [1, 2, 3, 4, 5, 6, 7],
      );

  Subscription copyWith({
    double? quantity,
    double? unitPrice,
    SubscriptionStatus? status,
    SchedulePattern? pattern,
    List<int>? weekDays,
  }) =>
      Subscription(
        id: id,
        flatId: flatId,
        productId: productId,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        status: status ?? this.status,
        createdAt: createdAt,
        pattern: pattern ?? this.pattern,
        weekDays: weekDays ?? this.weekDays,
      );
}
