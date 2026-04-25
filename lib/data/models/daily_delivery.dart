enum DeliveryStatus { pending, delivered, skipped, paused }

class DailyDelivery {
  DailyDelivery({
    required this.id,
    required this.flatId,
    required this.dateKey,
    required this.plannedQuantity,
    required this.actualQuantity,
    required this.status,
    this.deliveredAt,
  });

  final String id;
  final String flatId;
  /// `yyyy-MM-dd`.
  final String dateKey;
  final double plannedQuantity;
  final double actualQuantity;
  final DeliveryStatus status;
  final DateTime? deliveredAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'dateKey': dateKey,
        'plannedQuantity': plannedQuantity,
        'actualQuantity': actualQuantity,
        'status': status.name,
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  factory DailyDelivery.fromJson(Map json) => DailyDelivery(
        id: json['id'] as String,
        flatId: json['flatId'] as String,
        dateKey: json['dateKey'] as String,
        plannedQuantity: (json['plannedQuantity'] as num).toDouble(),
        actualQuantity: (json['actualQuantity'] as num).toDouble(),
        status: DeliveryStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DeliveryStatus.pending,
        ),
        deliveredAt: json['deliveredAt'] == null
            ? null
            : DateTime.parse(json['deliveredAt'] as String),
      );

  DailyDelivery copyWith({
    double? plannedQuantity,
    double? actualQuantity,
    DeliveryStatus? status,
    DateTime? deliveredAt,
  }) =>
      DailyDelivery(
        id: id,
        flatId: flatId,
        dateKey: dateKey,
        plannedQuantity: plannedQuantity ?? this.plannedQuantity,
        actualQuantity: actualQuantity ?? this.actualQuantity,
        status: status ?? this.status,
        deliveredAt: deliveredAt ?? this.deliveredAt,
      );
}
