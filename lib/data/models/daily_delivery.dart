enum DeliveryStatus { pending, delivered, skipped, paused, milkmanAbsent }

/// One row per (flat, product, day). A flat with 3 subscribed products produces
/// 3 DailyDelivery rows per day.
class DailyDelivery {
  DailyDelivery({
    required this.id,
    required this.flatId,
    required this.productId,
    required this.dateKey,
    required this.plannedQuantity,
    required this.actualQuantity,
    required this.unitPrice,
    required this.status,
    this.deliveredAt,
    this.notes,
    this.proofPhotoB64,
    this.isOneTime = false,
  });

  final String id;
  final String flatId;

  /// Empty string for legacy rows created before multi-product support — those
  /// are migrated to the seeded cow-milk product id on first run.
  final String productId;

  /// `yyyy-MM-dd`.
  final String dateKey;
  final double plannedQuantity;
  final double actualQuantity;

  /// Price per unit at the time of delivery. Locked here so retroactive price
  /// changes don't alter past bills.
  final double unitPrice;
  final DeliveryStatus status;
  final DateTime? deliveredAt;
  final String? notes;

  /// Base64-encoded JPEG of the delivery proof photo (bottle at door etc.).
  /// Optional. Captured at mark-delivered time. We store inline rather than as
  /// a file path so it survives across web origins and lazily syncs to remote.
  final String? proofPhotoB64;

  /// True for one-time / extra orders (not driven by a subscription). The
  /// route screen tags these with a "1×" badge so the milkman knows it's
  /// a one-off ask.
  final bool isOneTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'productId': productId,
        'dateKey': dateKey,
        'plannedQuantity': plannedQuantity,
        'actualQuantity': actualQuantity,
        'unitPrice': unitPrice,
        'status': status.name,
        'deliveredAt': deliveredAt?.toIso8601String(),
        'notes': notes,
        'proofPhotoB64': proofPhotoB64,
        'isOneTime': isOneTime,
      };

  factory DailyDelivery.fromJson(Map json) => DailyDelivery(
        id: json['id'] as String,
        flatId: (json['flatId'] ?? json['flat_id']) as String,
        productId: ((json['productId'] ?? json['product_id']) as String?) ?? '',
        dateKey: (json['dateKey'] ?? json['date_key']) as String,
        plannedQuantity:
            ((json['plannedQuantity'] ?? json['planned_quantity']) as num)
                .toDouble(),
        actualQuantity:
            ((json['actualQuantity'] ?? json['actual_quantity']) as num)
                .toDouble(),
        unitPrice: ((json['unitPrice'] ?? json['unit_price']) as num?)
                ?.toDouble() ??
            0.0,
        status: DeliveryStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DeliveryStatus.pending,
        ),
        deliveredAt: (json['deliveredAt'] ?? json['delivered_at']) == null
            ? null
            : DateTime.parse(
                (json['deliveredAt'] ?? json['delivered_at']) as String),
        notes: json['notes'] as String?,
        proofPhotoB64:
            (json['proofPhotoB64'] ?? json['proof_photo_b64']) as String?,
        isOneTime: (json['isOneTime'] ?? json['is_one_time']) as bool? ?? false,
      );

  DailyDelivery copyWith({
    String? productId,
    double? plannedQuantity,
    double? actualQuantity,
    double? unitPrice,
    DeliveryStatus? status,
    DateTime? deliveredAt,
    String? notes,
    String? proofPhotoB64,
    bool? isOneTime,
  }) =>
      DailyDelivery(
        id: id,
        flatId: flatId,
        productId: productId ?? this.productId,
        dateKey: dateKey,
        plannedQuantity: plannedQuantity ?? this.plannedQuantity,
        actualQuantity: actualQuantity ?? this.actualQuantity,
        unitPrice: unitPrice ?? this.unitPrice,
        status: status ?? this.status,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        notes: notes ?? this.notes,
        proofPhotoB64: proofPhotoB64 ?? this.proofPhotoB64,
        isOneTime: isOneTime ?? this.isOneTime,
      );
}
