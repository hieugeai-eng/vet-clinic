import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Feature 16: Photo Log Section
/// Allows staff to capture and view recovery progress photos.
class PhotoLogSection extends StatefulWidget {
  final String dailyId;
  final String? currentNotes;
  final ValueChanged<String> onNotesUpdated;

  const PhotoLogSection({
    super.key,
    required this.dailyId,
    this.currentNotes,
    required this.onNotesUpdated,
  });

  @override
  State<PhotoLogSection> createState() => _PhotoLogSectionState();
}

class _PhotoLogSectionState extends State<PhotoLogSection> {
  final _picker = ImagePicker();
  List<String> _photoPaths = [];

  @override
  void initState() {
    super.initState();
    _parsePhotos();
  }

  @override
  void didUpdateWidget(PhotoLogSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentNotes != widget.currentNotes) {
      _parsePhotos();
    }
  }

  void _parsePhotos() {
    _photoPaths = [];
    if (widget.currentNotes == null) return;

    final regex = RegExp(r'\[(?:PHOTO|URL):(.+?)\]');
    for (var match in regex.allMatches(widget.currentNotes!)) {
      final path = match.group(1);
      final tag = match.group(0);
      if (path != null && tag != null) {
        if (tag.startsWith('[URL:')) {
          _photoPaths.add(tag);
        } else if (File(path).existsSync()) {
          _photoPaths.add(tag);
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final photoDir = Directory(
        p.join(appDir.path, 'hospitalization_photos', widget.dailyId),
      );
      if (!photoDir.existsSync()) {
        photoDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(picked.path);
      final destPath = p.join(photoDir.path, 'photo_$timestamp$ext');
      await File(picked.path).copy(destPath);

      String newTag;
      try {
        if (Get.isRegistered<SupabaseStorageService>() &&
            SupabaseStorageService.to.isAvailable) {
          final clinicId = Get.isRegistered<AuthService>()
              ? (AuthService.to.currentProfile.value?.clinicId ?? 'default')
              : 'default';
          final storagePath =
              '$clinicId/hospital/${widget.dailyId}/photo_$timestamp$ext';
          final url = await SupabaseStorageService.to.uploadFromPath(
            localPath: destPath,
            storagePath: storagePath,
            contentType: 'image/jpeg',
          );
          newTag = '[URL:$url]';
        } else {
          newTag = '[PHOTO:$destPath]';
        }
      } catch (e) {
        debugPrint('Failed to upload hospitalization photo: $e');
        newTag = '[PHOTO:$destPath]';
      }

      final updatedNotes =
          widget.currentNotes != null && widget.currentNotes!.isNotEmpty
          ? '${widget.currentNotes}\n$newTag'
          : newTag;

      widget.onNotesUpdated(updatedNotes);

      setState(() {
        _photoPaths.add(newTag);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể thêm ảnh: $e')));
      }
    }
  }

  void _deletePhoto(int index) {
    final tagToRemove = _photoPaths[index];

    if (widget.currentNotes != null) {
      final updatedNotes = widget.currentNotes!
          .replaceFirst(tagToRemove, '')
          .replaceAll('\n\n', '\n')
          .trim();
      widget.onNotesUpdated(updatedNotes);
    }

    setState(() {
      _photoPaths.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.photo_library,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Nhật Ký Ảnh (${_photoPaths.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              PopupMenuButton<ImageSource>(
                onSelected: _addPhoto,
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Thêm',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: ImageSource.camera,
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt),
                        SizedBox(width: 8),
                        Text('Chụp ảnh'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: ImageSource.gallery,
                    child: Row(
                      children: [
                        Icon(Icons.photo_library),
                        SizedBox(width: 8),
                        Text('Chọn từ thư viện'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Photo grid
        if (_photoPaths.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chưa có ảnh theo dõi',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _photoPaths.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullScreen(context, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: _photoPaths[index].startsWith('[URL:')
                              ? Image.network(
                                  _photoPaths[index].substring(
                                    5,
                                    _photoPaths[index].length - 1,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(
                                    _photoPaths[index].substring(
                                      7,
                                      _photoPaths[index].length - 1,
                                    ),
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _deletePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  void _showFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenViewer(photos: _photoPaths, initialIndex: initialIndex),
      ),
    );
  }
}

/// Simple fullscreen photo viewer with swipe
class _FullScreenViewer extends StatelessWidget {
  final List<String> photos;
  final int initialIndex;

  const _FullScreenViewer({required this.photos, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1} / ${photos.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: photos[index].startsWith('[URL:')
                  ? Image.network(
                      photos[index].substring(5, photos[index].length - 1),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    )
                  : Image.file(
                      File(
                        photos[index].substring(7, photos[index].length - 1),
                      ),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
