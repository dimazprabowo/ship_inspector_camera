class InspectionPresetItem {
  final int? id;
  final int presetId;
  final String title;
  final String description;
  final int sortOrder;
  final int createdAt;
  final int? parentId;
  final String? parentName; // For display purposes when parent is deleted

  InspectionPresetItem({
    this.id,
    required this.presetId,
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.createdAt,
    this.parentId,
    this.parentName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'preset_id': presetId,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'parent_id': parentId,
    };
  }

  factory InspectionPresetItem.fromMap(Map<String, dynamic> map) {
    return InspectionPresetItem(
      id: map['id'],
      presetId: map['preset_id'],
      title: map['title'],
      description: map['description'],
      sortOrder: map['sort_order'],
      createdAt: map['created_at'],
      parentId: map['parent_id'],
      parentName: map['parent_name'], // This will be populated via JOIN queries
    );
  }

  InspectionPresetItem copyWith({
    int? id,
    int? presetId,
    String? title,
    String? description,
    int? sortOrder,
    int? createdAt,
    int? parentId,
    String? parentName,
  }) {
    return InspectionPresetItem(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
    );
  }
}
