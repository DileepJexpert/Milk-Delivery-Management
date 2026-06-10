enum FlatStatus { active, paused, stopped }

enum BillingMode { prepaid, postpaid }

/// A delivery point. Originally modelled as a flat in a society, now also
/// supports standalone houses / shops — `societyId` may be null, and
/// `addressLine` carries free-form location info (sector, street, landmark).
/// `flatNumber` is the customer label the milkman writes down — for society
/// flats it's the flat number ("A-101"), for standalone customers it can be
/// anything ("House 42", "Sharma Stores", "Krishna Nilaya").
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
    this.addressLine,
    this.status = FlatStatus.active,
    this.billingMode = BillingMode.postpaid,
    this.walletBalance = 0,
    this.vacationFromKey,
    this.vacationToKey,
    this.pauseOnFestivals = false,
  });

  final String id;

  /// Null for standalone customers (houses with no society).
  final String? societyId;

  final String flatNumber;
  final String ownerName;
  final String ownerPhone;
  final bool hasApp;

  /// Free-form address (used mainly for standalone customers, optional for
  /// society flats too).
  final String? addressLine;

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

  /// Vacation mode: subscriber away from `vacationFromKey` to `vacationToKey`
  /// (inclusive, yyyy-MM-dd). All products pause for these dates.
  final String? vacationFromKey;
  final String? vacationToKey;

  /// When true, deliveries are auto-paused on major Indian festivals
  /// (see IndianHolidays utility).
  final bool pauseOnFestivals;

  bool get isStandalone => societyId == null || societyId!.isEmpty;

  /// True if [date] (yyyy-MM-dd) falls inside the vacation range.
  bool isOnVacation(String dateKey) {
    if (vacationFromKey == null || vacationToKey == null) return false;
    return dateKey.compareTo(vacationFromKey!) >= 0 &&
        dateKey.compareTo(vacationToKey!) <= 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'societyId': societyId,
        'flatNumber': flatNumber,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'hasApp': hasApp,
        'addressLine': addressLine,
        'defaultQuantity': defaultQuantity,
        'pricePerLitre': pricePerLitre,
        'status': status.name,
        'billingMode': billingMode.name,
        'walletBalance': walletBalance,
        'vacationFromKey': vacationFromKey,
        'vacationToKey': vacationToKey,
        'pauseOnFestivals': pauseOnFestivals,
      };

  factory Flat.fromJson(Map json) {
    final raw = json['societyId'];
    final society = raw is String && raw.isNotEmpty ? raw : null;
    return Flat(
      id: json['id'] as String,
      societyId: society,
      flatNumber: json['flatNumber'] as String,
      ownerName: json['ownerName'] as String,
      ownerPhone: json['ownerPhone'] as String,
      hasApp: json['hasApp'] as bool? ?? false,
      addressLine: json['addressLine'] as String?,
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
      vacationFromKey: json['vacationFromKey'] as String?,
      vacationToKey: json['vacationToKey'] as String?,
      pauseOnFestivals: json['pauseOnFestivals'] as bool? ?? false,
    );
  }

  Flat copyWith({
    String? flatNumber,
    String? ownerName,
    String? ownerPhone,
    bool? hasApp,
    String? addressLine,
    double? defaultQuantity,
    double? pricePerLitre,
    FlatStatus? status,
    BillingMode? billingMode,
    double? walletBalance,
    Object? societyId = _sentinel,
    Object? vacationFromKey = _sentinel,
    Object? vacationToKey = _sentinel,
    bool? pauseOnFestivals,
  }) =>
      Flat(
        id: id,
        societyId:
            identical(societyId, _sentinel) ? this.societyId : societyId as String?,
        flatNumber: flatNumber ?? this.flatNumber,
        ownerName: ownerName ?? this.ownerName,
        ownerPhone: ownerPhone ?? this.ownerPhone,
        hasApp: hasApp ?? this.hasApp,
        addressLine: addressLine ?? this.addressLine,
        defaultQuantity: defaultQuantity ?? this.defaultQuantity,
        pricePerLitre: pricePerLitre ?? this.pricePerLitre,
        status: status ?? this.status,
        billingMode: billingMode ?? this.billingMode,
        walletBalance: walletBalance ?? this.walletBalance,
        vacationFromKey: identical(vacationFromKey, _sentinel)
            ? this.vacationFromKey
            : vacationFromKey as String?,
        vacationToKey: identical(vacationToKey, _sentinel)
            ? this.vacationToKey
            : vacationToKey as String?,
        pauseOnFestivals: pauseOnFestivals ?? this.pauseOnFestivals,
      );

  static const _sentinel = Object();
}
