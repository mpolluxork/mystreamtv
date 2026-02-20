import 'package:shared_preferences/shared_preferences.dart';

/// Manages the backend server URL, persisted across app launches.
class ServerConfig {
  static const _key = 'server_base_url';
  static SharedPreferences? _prefs;

  /// Must be called once in main() before runApp().
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// The saved base URL, e.g. "http://192.168.1.50:8000".
  /// Returns null if not yet configured.
  static String? get baseUrl => _prefs?.getString(_key);

  /// Save a new server URL. Normalizes the input.
  static Future<void> save(String url) async {
    final normalized = _normalize(url);
    await _prefs!.setString(_key, normalized);
  }

  /// Clear the saved URL (forces setup screen on next launch).
  static Future<void> clear() async {
    await _prefs!.remove(_key);
  }

  /// Normalize user input: add http:// if missing, add :8000 if no port.
  static String _normalize(String input) {
    var url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    // If no port specified and it's a plain IP/hostname, add :8000
    final uri = Uri.tryParse(url);
    if (uri != null && !uri.hasPort) {
      url = '${url.trimRight().replaceAll(RegExp(r'/+$'), '')}:8000';
    }
    return url;
  }
}
