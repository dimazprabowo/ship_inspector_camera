class InspectionPhoto {
  final int? id;
  final int inspectionItemId;
  final String fileName;
  final String filePath;
  final DateTime capturedAt;

  InspectionPhoto({
    this.id,
    required this.inspectionItemId,
    required this.fileName,
    required this.filePath,
    required this.capturedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspection_item_id': inspectionItemId,
      'file_name': fileName,
      'file_path': filePath,
      'captured_at': capturedAt.millisecondsSinceEpoch,
    };
  }

  factory InspectionPhoto.fromMap(Map<String, dynamic> map) {
    return InspectionPhoto(
      id: map['id'],
      inspectionItemId: map['inspection_item_id'],
      fileName: map['file_name'],
      filePath: map['file_path'],
      capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at']),
    );
  }

  InspectionPhoto copyWith({
    int? id,
    int? inspectionItemId,
    String? fileName,
    String? filePath,
    DateTime? capturedAt,
  }) {
    return InspectionPhoto(
      id: id ?? this.id,
      inspectionItemId: inspectionItemId ?? this.inspectionItemId,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}
