class InspectionItem {
  final int? id;
  final String title;
  final int shipTypeId;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;

  InspectionItem({
    this.id,
    required this.title,
    required this.shipTypeId,
    this.description,
    required this.sortOrder,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ship_type_id': shipTypeId,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory InspectionItem.fromMap(Map<String, dynamic> map) {
    return InspectionItem(
      id: map['id'],
      title: map['title'],
      shipTypeId: map['ship_type_id'],
      description: map['description'],
      sortOrder: map['sort_order'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  InspectionItem copyWith({
    int? id,
    String? title,
    int? shipTypeId,
    String? description,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return InspectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      shipTypeId: shipTypeId ?? this.shipTypeId,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
