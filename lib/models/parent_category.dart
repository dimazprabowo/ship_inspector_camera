class ParentCategory {
  final int? id;
  final String name;
  final int createdAt;

  ParentCategory({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory ParentCategory.fromMap(Map<String, dynamic> map) {
    return ParentCategory(
      id: map['id'],
      name: map['name'],
      createdAt: map['created_at'],
    );
  }

  ParentCategory copyWith({
    int? id,
    String? name,
    int? createdAt,
  }) {
    return ParentCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}