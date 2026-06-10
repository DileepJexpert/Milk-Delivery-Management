enum SubscriptionStatus { active, stopped }

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
  });

  final String id;
  final String flatId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final SubscriptionStatus status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'flatId': flatId,
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
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
      );

  Subscription copyWith({
    double? quantity,
    double? unitPrice,
    SubscriptionStatus? status,
  }) =>
      Subscription(
        id: id,
        flatId: flatId,
        productId: productId,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
