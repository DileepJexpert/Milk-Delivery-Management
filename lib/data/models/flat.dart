enum FlatStatus { active, paused, stopped }

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
  });

  final String id;
  final String societyId;
  final String flatNumber;
  final String ownerName;
  final String ownerPhone;
  final bool hasApp;
  final double defaultQuantity;
  final double pricePerLitre;
  final FlatStatus status;

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
      };

  factory Flat.fromJson(Map json) => Flat(
        id: json['id'] as String,
        societyId: (json['societyId'] ?? json['society_id']) as String,
        flatNumber: (json['flatNumber'] ?? json['flat_number']) as String,
        ownerName: (json['ownerName'] ?? json['owner_name']) as String,
        ownerPhone: (json['ownerPhone'] ?? json['owner_phone']) as String,
        hasApp: json['hasApp'] == true || json['has_app'] == 1 || json['has_app'] == true,
        defaultQuantity: ((json['defaultQuantity'] ?? json['default_quantity']) as num).toDouble(),
        pricePerLitre: ((json['pricePerLitre'] ?? json['price_per_litre']) as num).toDouble(),
        status: FlatStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String? ?? ''),
          orElse: () => FlatStatus.active,
        ),
      );

  Flat copyWith({
    String? flatNumber,
    String? ownerName,
    String? ownerPhone,
    bool? hasApp,
    double? defaultQuantity,
    double? pricePerLitre,
    FlatStatus? status,
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
      );
}
