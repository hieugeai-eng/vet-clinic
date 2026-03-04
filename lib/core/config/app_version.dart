/// App Version Configuration
///
/// Manages current version and comparison logic for auto-update.
/// Version follows semver: MAJOR.MINOR.PATCH
class AppVersion {
  /// Current app version — MUST match pubspec.yaml version
  static const String current = '2.0.0';

  /// Build number for internal tracking
  static const int buildNumber = 1;

  /// GitHub repository info for update checks
  static const String githubOwner =
      String.fromEnvironment('GITHUB_OWNER', defaultValue: 'hieugeai-eng');
  static const String githubRepo =
      String.fromEnvironment('GITHUB_REPO', defaultValue: 'vet-clinic');

  /// GitHub Releases API URL
  static String get releasesApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// Compare two version strings (semver)
  /// Returns: positive if remote > local, 0 if equal, negative if local > remote
  static int compare(String local, String remote) {
    final localParts = local.replaceAll('v', '').split('.').map(int.parse).toList();
    final remoteParts = remote.replaceAll('v', '').split('.').map(int.parse).toList();

    // Pad shorter version with zeros
    while (localParts.length < 3) {
      localParts.add(0);
    }
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] != localParts[i]) {
        return remoteParts[i] - localParts[i];
      }
    }
    return 0;
  }

  /// Check if remote version is newer
  static bool isNewer(String remoteVersion) {
    return compare(current, remoteVersion) > 0;
  }
}
