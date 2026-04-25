class Society {
  Society({
    required this.id,
    required this.milkmanId,
    required this.name,
    required this.address,
  });

  final String id;
  final String milkmanId;
  final String name;
  final String address;

  Map<String, dynamic> toJson() => {
        'id': id,
        'milkmanId': milkmanId,
        'name': name,
        'address': address,
      };

  factory Society.fromJson(Map json) => Society(
        id: json['id'] as String,
        milkmanId: json['milkmanId'] as String,
        name: json['name'] as String,
        address: (json['address'] ?? '') as String,
      );

  Society copyWith({String? name, String? address}) => Society(
        id: id,
        milkmanId: milkmanId,
        name: name ?? this.name,
        address: address ?? this.address,
      );
}
