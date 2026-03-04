import 'dart:io';

void logDebug(String message) {
  try {
    final file = File('debug_log.txt');
    final timestamp = DateTime.now().toUtc().toIso8601String();
    file.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
  } catch (e) {
    // Ignore
  }
}
