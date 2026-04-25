enum UserRole { milkman, subscriber }

class AppUser {
  AppUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
  });

  final String id;
  final String phone;
  final String name;
  final UserRole role;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role.name,
      };

  factory AppUser.fromJson(Map json) => AppUser(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.subscriber,
        ),
      );

  AppUser copyWith({String? name, UserRole? role}) => AppUser(
        id: id,
        phone: phone,
        name: name ?? this.name,
        role: role ?? this.role,
      );
}
