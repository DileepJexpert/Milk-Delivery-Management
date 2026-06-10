enum FlatStatus { active, paused, stopped }

enum BillingMode { prepaid, postpaid }

class Flat {
  Flat({
    required this.id,
    required this.societyId,
    required this.flatNumber,
    required this.ownerName,
    required this.ownerPhone,
    required this.hasApp,
    required this.defaultQuantity,
    required this.pricePerLitre,
    this.status = FlatStatus.active,
    this.billingMode = BillingMode.postpaid,
    this.walletBalance = 0,
  });

  final String id;
  final String societyId;
  final String flatNumber;
  final String ownerName;
  final String ownerPhone;
  final bool hasApp;

  /// Legacy: pre-multi-product daily quantity for cow milk. Kept for migration
  /// of existing data; new code should read the matching Subscription instead.
  final double defaultQuantity;

  /// Legacy: pre-multi-product cow milk price. Kept for migration.
  final double pricePerLitre;

  final FlatStatus status;
  final BillingMode billingMode;

  /// Denormalised wallet balance. Source of truth is the sum of WalletTxn rows,
  /// but we cache here to avoid recomputing on every UI rebuild.
  final double walletBalance;

  Map<String, dynamic> toJson() => {
        'id': id,
        'societyId': societyId,
        'flatNumber': flatNumber,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'hasApp': hasApp,
        'defaultQuantity': defaultQuantity,
        'pricePerLitre': pricePerLitre,
        'status': status.name,
        'billingMode': billingMode.name,
        'walletBalance': walletBalance,
      };

  factory Flat.fromJson(Map json) => Flat(
        id: json['id'] as String,
        societyId: json['societyId'] as String,
        flatNumber: json['flatNumber'] as String,
        ownerName: json['ownerName'] as String,
        ownerPhone: json['ownerPhone'] as String,
        hasApp: json['hasApp'] as bool? ?? false,
        defaultQuantity: (json['defaultQuantity'] as num).toDouble(),
        pricePerLitre: (json['pricePerLitre'] as num).toDouble(),
        status: FlatStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String? ?? ''),
          orElse: () => FlatStatus.active,
        ),
        billingMode: BillingMode.values.firstWhere(
          (b) => b.name == (json['billingMode'] as String? ?? ''),
          orElse: () => BillingMode.postpaid,
        ),
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      );

  Flat copyWith({
    String? flatNumber,
    String? ownerName,
    String? ownerPhone,
    bool? hasApp,
    double? defaultQuantity,
    double? pricePerLitre,
    FlatStatus? status,
    BillingMode? billingMode,
    double? walletBalance,
  }) =>
      Flat(
        id: id,
        societyId: societyId,
        flatNumber: flatNumber ?? this.flatNumber,
        ownerName: ownerName ?? this.ownerName,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        hasApp: hasApp ?? this.hasApp,
        defaultQuantity: defaultQuantity ?? this.defaultQuantity,
        pricePerLitre: pricePerLitre ?? this.pricePerLitre,
        status: status ?? this.status,
        billingMode: billingMode ?? this.billingMode,
        walletBalance: walletBalance ?? this.walletBalance,
      );
}
