/// Case Attachment Model — file đính kèm kết quả CLS
class CaseAttachmentModel {
  final String id;
  final String? clinicId;
  final String caseId;
  final String? caseServiceId;
  final String fileName;
  final String? fileType; // 'image/jpeg', 'application/pdf'
  final String category; // 'xray', 'ultrasound', 'lab_result', 'photo', 'other'
  final String localPath;
  final String? remoteUrl;
  final String? thumbnailPath;
  final String? note;
  final int? fileSize;
  final String? uploadedBy;
  final String syncStatus; // 'local_only', 'syncing', 'synced'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CaseAttachmentModel({
    required this.id,
    this.clinicId,
    required this.caseId,
    this.caseServiceId,
    required this.fileName,
    this.fileType,
    this.category = 'other',
    required this.localPath,
    this.remoteUrl,
    this.thumbnailPath,
    this.note,
    this.fileSize,
    this.uploadedBy,
    this.syncStatus = 'local_only',
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory CaseAttachmentModel.fromJson(Map<String, dynamic> json) {
    return CaseAttachmentModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      caseId: json['case_id'] as String,
      caseServiceId: json['case_service_id'] as String?,
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String?,
      category: json['category'] as String? ?? 'other',
      localPath: json['local_path'] as String? ?? '',
      remoteUrl: json['remote_url'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      note: json['note'] as String?,
      fileSize: json['file_size'] as int?,
      uploadedBy: json['uploaded_by'] as String?,
      syncStatus: json['sync_status'] as String? ?? 'local_only',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'case_id': caseId,
      'case_service_id': caseServiceId,
      'file_name': fileName,
      'file_type': fileType,
      'category': category,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'thumbnail_path': thumbnailPath,
      'note': note,
      'file_size': fileSize,
      'uploaded_by': uploadedBy,
      'sync_status': syncStatus,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  CaseAttachmentModel copyWith({
    String? id,
    String? clinicId,
    String? caseId,
    String? caseServiceId,
    String? fileName,
    String? fileType,
    String? category,
    String? localPath,
    String? remoteUrl,
    String? thumbnailPath,
    String? note,
    int? fileSize,
    String? uploadedBy,
    String? syncStatus,
    bool? isActive,
  }) {
    return CaseAttachmentModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      caseId: caseId ?? this.caseId,
      caseServiceId: caseServiceId ?? this.caseServiceId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      category: category ?? this.category,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      note: note ?? this.note,
      fileSize: fileSize ?? this.fileSize,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      syncStatus: syncStatus ?? this.syncStatus,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helpers
  bool get isImage => fileType?.startsWith('image/') == true;
  bool get isPdf => fileType == 'application/pdf';
  bool get isSynced => syncStatus == 'synced';
  bool get isLocalOnly => syncStatus == 'local_only';

  String get categoryLabel {
    switch (category) {
      case 'xray':
        return 'X-quang';
      case 'ultrasound':
        return 'Siêu âm';
      case 'lab_result':
        return 'Xét nghiệm';
      case 'photo':
        return 'Ảnh';
      default:
        return 'Khác';
    }
  }

  /// Auto-detect category from service name
  static String detectCategory(String? serviceName) {
    if (serviceName == null) return 'other';
    final lower = serviceName.toLowerCase();
    if (lower.contains('x-quang') ||
        lower.contains('xquang') ||
        lower.contains('x ray'))
      return 'xray';
    if (lower.contains('siêu âm') || lower.contains('ultra'))
      return 'ultrasound';
    if (lower.contains('xét nghiệm') ||
        lower.contains('lab') ||
        lower.contains('máu') ||
        lower.contains('nước tiểu'))
      return 'lab_result';
    return 'photo';
  }
}
