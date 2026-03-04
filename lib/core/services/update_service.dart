import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../config/app_version.dart';

/// Auto-Update Service
///
/// Checks GitHub Releases for new versions, downloads installer,
/// and runs silent update via Inno Setup.
class UpdateService extends GetxService {
  static UpdateService get to => Get.find();

  final isChecking = false.obs;
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;
  final updateAvailable = false.obs;
  final latestVersion = ''.obs;
  final releaseNotes = ''.obs;
  final downloadUrl = ''.obs;

  /// Check for updates from GitHub Releases
  Future<bool> checkForUpdate() async {
    // Only check on Windows desktop
    if (!Platform.isWindows) return false;

    if (isChecking.value) return false;
    isChecking.value = true;

    try {
      debugPrint('🔄 UpdateService: Checking for updates...');
      debugPrint('🔄 UpdateService: API URL = ${AppVersion.releasesApiUrl}');

      final response = await http.get(
        Uri.parse(AppVersion.releasesApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'OkadaVetClinic/${AppVersion.current}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? '';
        final body = data['body'] as String? ?? '';
        final assets = data['assets'] as List<dynamic>? ?? [];

        debugPrint('🔄 UpdateService: Latest release = $tagName');
        debugPrint('🔄 UpdateService: Current version = v${AppVersion.current}');

        if (AppVersion.isNewer(tagName)) {
          latestVersion.value = tagName.replaceAll('v', '');
          releaseNotes.value = body;
          updateAvailable.value = true;

          // Find .exe installer asset
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.exe') || name.endsWith('.msi')) {
              downloadUrl.value = asset['browser_download_url'] as String? ?? '';
              break;
            }
          }

          debugPrint('🔄 UpdateService: Update available! v${latestVersion.value}');
          debugPrint('🔄 UpdateService: Download URL = ${downloadUrl.value}');
          return true;
        } else {
          debugPrint('🔄 UpdateService: App is up to date');
          updateAvailable.value = false;
          return false;
        }
      } else if (response.statusCode == 404) {
        debugPrint('🔄 UpdateService: No releases found yet');
        return false;
      } else {
        debugPrint('🔄 UpdateService: API error ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('🔄 UpdateService: Check failed - $e');
      return false;
    } finally {
      isChecking.value = false;
    }
  }

  /// Download the update installer
  Future<String?> downloadUpdate() async {
    if (downloadUrl.value.isEmpty) {
      debugPrint('🔄 UpdateService: No download URL');
      return null;
    }

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      debugPrint('🔄 UpdateService: Downloading ${downloadUrl.value}');

      final request = http.Request('GET', Uri.parse(downloadUrl.value));
      request.headers['User-Agent'] = 'OkadaVetClinic/${AppVersion.current}';

      final streamedResponse = await http.Client().send(request);
      final totalBytes = streamedResponse.contentLength ?? 0;
      var receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, 'OkadaVetClinicSetup.exe');
      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          downloadProgress.value = receivedBytes / totalBytes;
        }
      }

      await sink.close();

      debugPrint('🔄 UpdateService: Download complete -> $filePath');
      return filePath;
    } catch (e) {
      debugPrint('🔄 UpdateService: Download failed - $e');
      return null;
    } finally {
      isDownloading.value = false;
    }
  }

  /// Run the installer in silent mode and close the app
  Future<void> installUpdate(String installerPath) async {
    try {
      debugPrint('🔄 UpdateService: Running installer $installerPath');

      // Inno Setup silent install flags:
      // /SILENT - minimal UI, shows progress
      // /VERYSILENT - no UI at all
      // /CLOSEAPPLICATIONS - close running app first
      // /RESTARTAPPLICATIONS - restart app after install
      await Process.start(
        installerPath,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );

      // Give installer time to start before we exit
      await Future.delayed(const Duration(seconds: 1));

      // Exit the app so installer can replace files
      exit(0);
    } catch (e) {
      debugPrint('🔄 UpdateService: Install failed - $e');
    }
  }
}
