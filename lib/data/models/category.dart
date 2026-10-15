class ProductCategory {
  ProductCategory({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? icon;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sortOrder': sortOrder,
      };

  factory ProductCategory.fromJson(Map json) => ProductCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  ProductCategory copyWith({String? name, String? icon, int? sortOrder}) =>
      ProductCategory(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
