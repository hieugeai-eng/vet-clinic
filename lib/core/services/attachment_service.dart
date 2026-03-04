import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/models/case_attachment_model.dart';
import '../../data/repositories/case_attachment_repository.dart';
import '../config/supabase_config.dart';
import 'supabase_storage_service.dart';

/// Attachment Service — orchestrates file pick, save, thumbnail, and cloud sync
class AttachmentService extends GetxService {
  static AttachmentService get to => Get.find();

  final _uuid = const Uuid();
  final _picker = ImagePicker();
  final Set<String> _deletedIds = {};

  CaseAttachmentRepository get _repo => Get.find<CaseAttachmentRepository>();

  /// Get app attachments directory
  Future<Directory> getAttachmentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'okada_attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Pick image from gallery and attach
  Future<CaseAttachmentModel?> pickImage({
    required String caseId,
    String? caseServiceId,
    String? serviceName,
    String? clinicId,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return null;

    return _saveFile(
      sourcePath: picked.path,
      caseId: caseId,
      caseServiceId: caseServiceId,
      serviceName: serviceName,
      clinicId: clinicId,
      fileType: 'image/jpeg',
    );
  }

  /// Capture from camera and attach
  Future<CaseAttachmentModel?> captureImage({
    required String caseId,
    String? caseServiceId,
    String? serviceName,
    String? clinicId,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null) return null;

    return _saveFile(
      sourcePath: picked.path,
      caseId: caseId,
      caseServiceId: caseServiceId,
      serviceName: serviceName,
      clinicId: clinicId,
      fileType: 'image/jpeg',
    );
  }

  /// Pick any file (PDF, image, etc.)
  Future<CaseAttachmentModel?> pickFile({
    required String caseId,
    String? caseServiceId,
    String? serviceName,
    String? clinicId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.path == null) return null;

    final ext = p.extension(file.path!).toLowerCase();
    String fileType;
    if (['.jpg', '.jpeg'].contains(ext))
      fileType = 'image/jpeg';
    else if (ext == '.png')
      fileType = 'image/png';
    else if (ext == '.webp')
      fileType = 'image/webp';
    else if (ext == '.heic')
      fileType = 'image/heic';
    else if (ext == '.pdf')
      fileType = 'application/pdf';
    else
      fileType = 'application/octet-stream';

    return _saveFile(
      sourcePath: file.path!,
      caseId: caseId,
      caseServiceId: caseServiceId,
      serviceName: serviceName,
      clinicId: clinicId,
      fileType: fileType,
    );
  }

  /// Internal: save source file to app directory and create DB record
  Future<CaseAttachmentModel> _saveFile({
    required String sourcePath,
    required String caseId,
    String? caseServiceId,
    String? serviceName,
    String? clinicId,
    required String fileType,
  }) async {
    final id = _uuid.v4();
    final dir = await getAttachmentsDir();
    final ext = p.extension(sourcePath);
    final fileName = '${id}$ext';
    final destPath = p.join(dir.path, fileName);

    // Copy file to app directory
    final sourceFile = File(sourcePath);
    await sourceFile.copy(destPath);

    final fileSize = await sourceFile.length();

    // Generate thumbnail for images
    String? thumbnailPath;
    if (fileType.startsWith('image/')) {
      thumbnailPath = await _generateThumbnail(destPath, dir.path, id);
    }

    final category = CaseAttachmentModel.detectCategory(serviceName);

    final model = CaseAttachmentModel(
      id: id,
      clinicId: clinicId,
      caseId: caseId,
      caseServiceId: caseServiceId,
      fileName: p.basename(sourcePath),
      fileType: fileType,
      category: category,
      localPath: destPath,
      thumbnailPath: thumbnailPath,
      fileSize: fileSize,
      syncStatus: 'local_only',
    );

    await _repo.addAttachment(model);
    debugPrint(
      '📎 AttachmentService: Saved $fileName (${fileSize}B) for case $caseId, serviceId=$caseServiceId',
    );

    // Try background upload
    _tryUpload(model);

    return model;
  }

  /// Generate thumbnail (simple copy with smaller name for now)
  Future<String?> _generateThumbnail(
    String imagePath,
    String dirPath,
    String id,
  ) async {
    try {
      // For Windows/desktop: use a simple file copy as thumbnail
      // In production, use image package to resize
      final thumbPath = p.join(dirPath, 'thumb_$id.jpg');
      await File(imagePath).copy(thumbPath);
      return thumbPath;
    } catch (e) {
      debugPrint('Thumbnail generation failed: $e');
      return null;
    }
  }

  /// Try to upload a single attachment to cloud (fire-and-forget)
  void _tryUpload(CaseAttachmentModel attachment) async {
    debugPrint('📎 _tryUpload: START for ${attachment.fileName}');
    debugPrint(
      '📎 _tryUpload: SupabaseConfig.isConfigured=${SupabaseConfig.isConfigured}',
    );
    if (!SupabaseConfig.isConfigured) {
      debugPrint('📎 _tryUpload: SKIP — Supabase not configured');
      return;
    }

    try {
      final storageRegistered = Get.isRegistered<SupabaseStorageService>();
      debugPrint(
        '📎 _tryUpload: SupabaseStorageService registered=$storageRegistered',
      );
      if (!storageRegistered) {
        debugPrint('📎 _tryUpload: SKIP — StorageService not registered');
        return;
      }

      if (_deletedIds.contains(attachment.id)) {
        debugPrint('📎 _tryUpload: SKIP — Attachment already deleted');
        _deletedIds.remove(attachment.id);
        return;
      }

      final storage = SupabaseStorageService.to;
      final clinicId = attachment.clinicId ?? SupabaseConfig.clinicId;
      final storagePath =
          '$clinicId/${attachment.caseId}/${attachment.id}${p.extension(attachment.localPath)}';
      debugPrint('📎 _tryUpload: storagePath=$storagePath');
      debugPrint('📎 _tryUpload: localPath=${attachment.localPath}');

      // Update status to syncing
      await _repo.updateSyncStatus(attachment.id, 'syncing');

      final remoteUrl = await storage.uploadFromPath(
        localPath: attachment.localPath,
        storagePath: storagePath,
        contentType: attachment.fileType ?? 'application/octet-stream',
      );

      // Check if deleted during upload
      if (_deletedIds.contains(attachment.id)) {
        debugPrint(
          '📎 _tryUpload: Attachment was deleted during upload. Cleaning up cloud...',
        );
        await storage.deleteFile(storagePath);
        _deletedIds.remove(attachment.id);
        return;
      }

      await _repo.updateSyncStatus(
        attachment.id,
        'synced',
        remoteUrl: remoteUrl,
      );
      debugPrint('📎 _tryUpload: SUCCESS → $remoteUrl');
    } catch (e, stack) {
      // Revert to local_only on failure — will retry on next sync
      await _repo.updateSyncStatus(attachment.id, 'local_only');
      debugPrint('📎 _tryUpload: FAILED for ${attachment.fileName}: $e');
      debugPrint('📎 _tryUpload: Stack: $stack');
    }
  }

  /// Sync all pending uploads (called by SyncEngine or manually)
  Future<int> syncPendingUploads() async {
    if (!SupabaseConfig.isConfigured) return 0;

    final pending = await _repo.getPendingUploads();
    int uploaded = 0;

    for (final attachment in pending) {
      try {
        final file = File(attachment.localPath);
        if (!await file.exists()) {
          debugPrint(
            'AttachmentService: File missing, skipping ${attachment.id}',
          );
          continue;
        }

        final storage = SupabaseStorageService.to;
        final clinicId = attachment.clinicId ?? SupabaseConfig.clinicId;
        final storagePath =
            '$clinicId/${attachment.caseId}/${attachment.id}${p.extension(attachment.localPath)}';

        await _repo.updateSyncStatus(attachment.id, 'syncing');

        final remoteUrl = await storage.uploadFromPath(
          localPath: attachment.localPath,
          storagePath: storagePath,
          contentType: attachment.fileType ?? 'application/octet-stream',
        );

        await _repo.updateSyncStatus(
          attachment.id,
          'synced',
          remoteUrl: remoteUrl,
        );
        uploaded++;
      } catch (e) {
        await _repo.updateSyncStatus(attachment.id, 'local_only');
        debugPrint('AttachmentService: Sync failed for ${attachment.id}: $e');
      }
    }

    if (uploaded > 0) {
      debugPrint(
        'AttachmentService: Synced $uploaded/${pending.length} attachments',
      );
    }
    return uploaded;
  }

  /// Delete attachment (file + DB record)
  Future<void> deleteAttachment(CaseAttachmentModel attachment) async {
    _deletedIds.add(attachment.id);

    // Delete local file
    try {
      final file = File(attachment.localPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    // Delete thumbnail
    if (attachment.thumbnailPath != null) {
      try {
        final thumb = File(attachment.thumbnailPath!);
        if (await thumb.exists()) await thumb.delete();
      } catch (_) {}
    }

    // Delete from cloud
    if (SupabaseConfig.isConfigured) {
      try {
        final clinicId = attachment.clinicId ?? SupabaseConfig.clinicId;
        final storagePath =
            '$clinicId/${attachment.caseId}/${attachment.id}${p.extension(attachment.localPath)}';
        await SupabaseStorageService.to.deleteFile(storagePath);
      } catch (_) {}
    }

    // Delete DB record
    await _repo.deleteAttachment(attachment.id);
  }

  /// Delete ALL attachments for a case (cascade cleanup)
  Future<int> deleteByCase(String caseId) async {
    final attachments = await _repo.getByCase(caseId);
    int deleted = 0;

    for (final attachment in attachments) {
      try {
        await deleteAttachment(attachment);
        deleted++;
      } catch (e) {
        debugPrint('📎 deleteByCase: Failed to delete ${attachment.id}: $e');
      }
    }

    debugPrint(
      '📎 deleteByCase: Deleted $deleted/${attachments.length} attachments for case $caseId',
    );
    return deleted;
  }
}
