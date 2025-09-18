class ShipType {
  final int? id;
  final String name;
  final int companyId;
  final String? description;
  final DateTime? inspectionDate;
  final DateTime createdAt;

  ShipType({
    this.id,
    required this.name,
    required this.companyId,
    this.description,
    this.inspectionDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company_id': companyId,
      'description': description,
      'inspection_date': inspectionDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ShipType.fromMap(Map<String, dynamic> map) {
    return ShipType(
      id: map['id'],
      name: map['name'],
      companyId: map['company_id'],
      description: map['description'],
      inspectionDate: map['inspection_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['inspection_date'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  ShipType copyWith({
    int? id,
    String? name,
    int? companyId,
    String? description,
    DateTime? inspectionDate,
    DateTime? createdAt,
  }) {
    return ShipType(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      description: description ?? this.description,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
