import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';

import '../../../data/models/case_attachment_model.dart';
import '../../../data/repositories/case_attachment_repository.dart';
import '../../../core/services/attachment_service.dart';

/// Reusable widget to display & manage attachments for a case service
class CaseAttachmentsWidget extends StatefulWidget {
  final String caseId;
  final String? caseServiceId;
  final String? serviceName;
  final String? clinicId;
  final bool readOnly;

  const CaseAttachmentsWidget({
    super.key,
    required this.caseId,
    this.caseServiceId,
    this.serviceName,
    this.clinicId,
    this.readOnly = false,
  });

  @override
  State<CaseAttachmentsWidget> createState() => _CaseAttachmentsWidgetState();
}

class _CaseAttachmentsWidgetState extends State<CaseAttachmentsWidget> {
  List<CaseAttachmentModel> _attachments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    try {
      final repo = Get.find<CaseAttachmentRepository>();
      final list = widget.caseServiceId != null
          ? await repo.getByService(widget.caseServiceId!)
          : await repo.getByCase(widget.caseId);
      if (mounted)
        setState(() {
          _attachments = list;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Thêm kết quả CLS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.camera_alt, color: Colors.orange),
              ),
              title: const Text('Chụp ảnh'),
              subtitle: const Text('Chụp trực tiếp từ camera'),
              onTap: () async {
                Navigator.pop(ctx);
                await _captureImage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: const Text('Chọn ảnh từ thư viện'),
              subtitle: const Text('Chọn ảnh có sẵn trong máy'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickImage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.attach_file, color: Colors.green),
              ),
              title: const Text('Chọn file (PDF, ảnh)'),
              subtitle: const Text('PDF xét nghiệm, ảnh X-quang...'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickFile();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    try {
      final attachment = await AttachmentService.to.captureImage(
        caseId: widget.caseId,
        caseServiceId: widget.caseServiceId,
        serviceName: widget.serviceName,
        clinicId: widget.clinicId,
      );
      if (attachment != null) {
        setState(() => _attachments.insert(0, attachment));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chụp ảnh: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final attachment = await AttachmentService.to.pickImage(
        caseId: widget.caseId,
        caseServiceId: widget.caseServiceId,
        serviceName: widget.serviceName,
        clinicId: widget.clinicId,
      );
      if (attachment != null) {
        setState(() => _attachments.insert(0, attachment));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final attachment = await AttachmentService.to.pickFile(
        caseId: widget.caseId,
        caseServiceId: widget.caseServiceId,
        serviceName: widget.serviceName,
        clinicId: widget.clinicId,
      );
      if (attachment != null) {
        setState(() => _attachments.insert(0, attachment));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn file: $e')));
      }
    }
  }

  Future<void> _deleteAttachment(CaseAttachmentModel attachment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa file?'),
        content: Text('Bạn có chắc muốn xóa "${attachment.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AttachmentService.to.deleteAttachment(attachment);
      setState(() => _attachments.removeWhere((a) => a.id == attachment.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa file'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _viewAttachment(CaseAttachmentModel attachment) async {
    if (!attachment.isImage) {
      final localFile = File(attachment.localPath);
      if (await localFile.exists()) {
        try {
          await OpenFile.open(attachment.localPath);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Không thể mở file: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File chưa được tải xuống hoặc không tồn tại'),
            ),
          );
        }
      }
      return;
    }

    // Is Image
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(attachment: attachment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Kết quả CLS (${_attachments.length})',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (!widget.readOnly)
              InkWell(
                onTap: _showAddMenu,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.orange),
                      SizedBox(width: 2),
                      Text(
                        'Thêm',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Gallery grid
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => _AttachmentThumbnail(
                attachment: _attachments[i],
                onTap: () => _viewAttachment(_attachments[i]),
                onDelete: widget.readOnly
                    ? null
                    : () => _deleteAttachment(_attachments[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Single attachment thumbnail tile
class _AttachmentThumbnail extends StatelessWidget {
  final CaseAttachmentModel attachment;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AttachmentThumbnail({
    required this.attachment,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Stack(
          children: [
            // Image or file icon — try local first, fallback to cloud URL
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: attachment.isImage ? _buildImageWidget() : _fileIcon(),
            ),

            // Category badge
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  attachment.categoryLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Sync status indicator
            Positioned(
              bottom: 4,
              right: 4,
              child: Icon(
                attachment.isSynced ? Icons.cloud_done : Icons.phone_android,
                size: 14,
                color: attachment.isSynced ? Colors.green : Colors.grey,
              ),
            ),

            // Delete button
            if (onDelete != null)
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Try local file first, fallback to cloud URL for cross-device support
  Widget _buildImageWidget() {
    final localFile = File(attachment.thumbnailPath ?? attachment.localPath);

    // If remote URL is available and it's synced, prefer network image
    // This handles cross-device scenarios (e.g., phone pulling cloud data)
    if (attachment.remoteUrl != null && attachment.remoteUrl!.isNotEmpty) {
      return Image.file(
        localFile,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.network(
          attachment.remoteUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fileIcon(),
        ),
      );
    }

    // Local only — no cloud fallback available
    return Image.file(
      localFile,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fileIcon(),
    );
  }

  Widget _fileIcon() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            attachment.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
            size: 28,
            color: attachment.isPdf ? Colors.red : Colors.blue,
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              attachment.fileName,
              style: const TextStyle(fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Color get _categoryColor {
    switch (attachment.category) {
      case 'xray':
        return Colors.indigo;
      case 'ultrasound':
        return Colors.teal;
      case 'lab_result':
        return Colors.purple;
      case 'photo':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

/// Full-screen image viewer with zoom/pan
class _FullScreenImageViewer extends StatelessWidget {
  final CaseAttachmentModel attachment;

  const _FullScreenImageViewer({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(attachment.fileName, style: const TextStyle(fontSize: 14)),
            Text(
              '${attachment.categoryLabel} • ${_formatFileSize(attachment.fileSize)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          // Sync status
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              attachment.isSynced ? Icons.cloud_done : Icons.cloud_off,
              color: attachment.isSynced ? Colors.green : Colors.grey,
              size: 20,
            ),
          ),
        ],
      ),
      body: Center(
        child: attachment.isImage
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: _buildFullImage(),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    attachment.isPdf
                        ? Icons.picture_as_pdf
                        : Icons.insert_drive_file,
                    color: Colors.white54,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    attachment.fileName,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatFileSize(attachment.fileSize),
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
      ),
    );
  }

  /// Build full-size image — try local first, fallback to cloud URL
  Widget _buildFullImage() {
    final localFile = File(attachment.localPath);

    if (attachment.remoteUrl != null && attachment.remoteUrl!.isNotEmpty) {
      return Image.file(
        localFile,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.network(
          attachment.remoteUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
                color: Colors.white54,
              ),
            );
          },
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: Colors.grey, size: 64),
        ),
      );
    }

    return Image.file(
      localFile,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, color: Colors.grey, size: 64),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
