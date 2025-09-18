class InspectionItem {
  final int? id;
  final String title;
  final int shipTypeId;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  final int? parentId;
  final String? parentName; // For display purposes when parent is deleted

  InspectionItem({
    this.id,
    required this.title,
    required this.shipTypeId,
    this.description,
    required this.sortOrder,
    required this.createdAt,
    this.parentId,
    this.parentName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ship_type_id': shipTypeId,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'parent_id': parentId,
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
      parentId: map['parent_id'],
      parentName: map['parent_name'], // This will be populated via JOIN queries
    );
  }

  InspectionItem copyWith({
    int? id,
    String? title,
    int? shipTypeId,
    String? description,
    int? sortOrder,
    DateTime? createdAt,
    int? parentId,
    String? parentName,
  }) {
    return InspectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      shipTypeId: shipTypeId ?? this.shipTypeId,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
    );
  }
}
