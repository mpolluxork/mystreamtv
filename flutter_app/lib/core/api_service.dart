import 'dart:convert';
import 'package:http/http.dart' as http;
import 'server_config.dart';

/// Central HTTP client for the MyStreamTV API.
class ApiService {
  static String get _base => ServerConfig.baseUrl ?? 'http://localhost:8000';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ── Health ──────────────────────────────────────────────────────────────────

  /// Validates connectivity. Returns true if server responds OK.
  static Future<bool> checkHealth(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── EPG ─────────────────────────────────────────────────────────────────────

  /// GET /api/epg/channels
  static Future<Map<String, dynamic>> getChannels() async {
    return _get('/api/epg/channels');
  }

  /// GET /api/epg/guide?hours=6
  static Future<Map<String, dynamic>> getGuide({int hours = 6}) async {
    return _get('/api/epg/guide?hours=$hours');
  }

  /// GET /api/epg/now-playing
  static Future<Map<String, dynamic>> getNowPlaying() async {
    return _get('/api/epg/now-playing');
  }

  /// GET /api/epg/channel/{channelId}/schedule?target_date=YYYY-MM-DD
  static Future<Map<String, dynamic>> getChannelSchedule(
    String channelId, {
    String? targetDate,
  }) async {
    final query = targetDate != null ? '?target_date=$targetDate' : '';
    return _get('/api/epg/channel/$channelId/schedule$query');
  }

  /// GET /api/epg/program/{tmdbId}/providers?content_type=movie|tv
  static Future<Map<String, dynamic>> getProgramProviders(
    int tmdbId,
    String contentType,
  ) async {
    return _get('/api/epg/program/$tmdbId/providers?content_type=$contentType');
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw ApiException(res.statusCode, res.body);
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
