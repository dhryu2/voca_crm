class BusinessPlace {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessPlace({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessPlace.fromJson(Map<String, dynamic> json) {
    return BusinessPlace(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
