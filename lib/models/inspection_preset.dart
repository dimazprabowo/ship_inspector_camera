class InspectionPreset {
  final int? id;
  final String name;
  final String description;
  final int companyId;
  final int createdAt;

  InspectionPreset({
    this.id,
    required this.name,
    required this.description,
    required this.companyId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'company_id': companyId,
      'created_at': createdAt,
    };
  }

  factory InspectionPreset.fromMap(Map<String, dynamic> map) {
    return InspectionPreset(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      companyId: map['company_id'],
      createdAt: map['created_at'],
    );
  }
}
