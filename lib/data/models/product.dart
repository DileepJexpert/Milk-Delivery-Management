enum ProductUnit { litre, ml, kg, gram, piece }

extension ProductUnitDisplay on ProductUnit {
  String get short {
    switch (this) {
      case ProductUnit.litre:
        return 'L';
      case ProductUnit.ml:
        return 'ml';
      case ProductUnit.kg:
        return 'kg';
      case ProductUnit.gram:
        return 'g';
      case ProductUnit.piece:
        return 'pc';
    }
  }
}

class Product {
  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.unit,
    required this.defaultPrice,
    this.active = true,
  });

  final String id;
  final String categoryId;
  final String name;
  final ProductUnit unit;
  final double defaultPrice;
  final bool active;

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'unit': unit.name,
        'defaultPrice': defaultPrice,
        'active': active,
      };

  factory Product.fromJson(Map json) => Product(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        unit: ProductUnit.values.firstWhere(
          (u) => u.name == json['unit'],
          orElse: () => ProductUnit.litre,
        ),
        defaultPrice: (json['defaultPrice'] as num).toDouble(),
        active: json['active'] as bool? ?? true,
      );

  Product copyWith({
    String? categoryId,
    String? name,
    ProductUnit? unit,
    double? defaultPrice,
    bool? active,
  }) =>
      Product(
        id: id,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        defaultPrice: defaultPrice ?? this.defaultPrice,
        active: active ?? this.active,
      );
}
