class InspectionPresetItem {
  final int? id;
  final int presetId;
  final String title;
  final String description;
  final int sortOrder;
  final int createdAt;

  InspectionPresetItem({
    this.id,
    required this.presetId,
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'preset_id': presetId,
      'title': title,
      'description': description,
      'sort_order': sortOrder,
      'created_at': createdAt,
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
    );
  }
}
