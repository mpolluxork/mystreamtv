import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../models/guide_response.dart';
import '../models/provider_info.dart';

enum EpgStatus { idle, loading, loaded, error }

class EpgProvider extends ChangeNotifier {
  EpgStatus _status = EpgStatus.idle;
  GuideResponse? _guide;
  String? _errorMessage;

  // Providers cache: tmdbId -> ProvidersResponse
  final Map<int, ProvidersResponse> _providersCache = {};
  final Set<int> _loadingProviders = {};

  EpgStatus get status => _status;
  GuideResponse? get guide => _guide;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == EpgStatus.loading;

  /// Load the full EPG guide (6 hours).
  Future<void> loadGuide({int hours = 6}) async {
    _status = EpgStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final json = await ApiService.getGuide(hours: hours);
      _guide = GuideResponse.fromJson(json);
      _status = EpgStatus.loaded;
    } catch (e) {
      _status = EpgStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Get providers for a program, using cache.
  Future<ProvidersResponse?> getProviders(int tmdbId, String contentType) async {
    if (_providersCache.containsKey(tmdbId)) {
      return _providersCache[tmdbId];
    }
    if (_loadingProviders.contains(tmdbId)) return null;

    _loadingProviders.add(tmdbId);
    try {
      final json = await ApiService.getProgramProviders(tmdbId, contentType);
      final result = ProvidersResponse.fromJson(json);
      _providersCache[tmdbId] = result;
      return result;
    } catch (_) {
      return null;
    } finally {
      _loadingProviders.remove(tmdbId);
    }
  }
}
