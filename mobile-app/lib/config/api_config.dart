/// API base URL configuration.
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000
///
/// Defaults:
///   • Android emulator : http://10.0.2.2:5000
///   • iOS simulator    : http://localhost:5000
library;

import 'dart:io' show Platform;

const String _kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String get apiBaseUrl {
  if (_kApiBaseUrl.isNotEmpty) return _kApiBaseUrl;
  // Runtime fallback – only works on non-web targets
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
  } catch (_) {}
  return 'http://localhost:5000';
}
