import 'package:flutter/foundation.dart';
import '../core/schedule_engine.dart';
import '../core/storage_service.dart';
import '../models/guide_response.dart';
import '../models/channel.dart' as app_models;
import '../models/program.dart' as app_models;
import '../models/provider_info.dart';
import '../models/standalone_models.dart' as standalone;

enum EpgStatus { idle, loading, loaded, error }

class EpgProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();
  final ScheduleEngine _engine = ScheduleEngine();

  EpgStatus _status = EpgStatus.idle;
  GuideResponse? _guide;
  String? _errorMessage;

  // Providers cache: tmdbId -> ProvidersResponse
  final Map<int, ProvidersResponse> _providersCache = {};

  EpgStatus get status => _status;
  GuideResponse? get guide => _guide;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == EpgStatus.loading;

  /// Initialize and load the full EPG guide locally.
  Future<void> loadGuide({int hours = 6}) async {
    _status = EpgStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _storage.initialize();
      
      // Load data into engine
      final poolJson = await _storage.loadContentPool();
      final channelsJson = await _storage.loadChannels();
      final cooldownJson = await _storage.loadCooldownData();

      await _engine.loadContentPool(poolJson);
      await _engine.loadChannels(channelsJson);
      await _engine.loadCooldownData(cooldownJson);

      final now = DateTime.now();
      final endTime = now.add(Duration(hours: hours));
      final channels = _engine.getAllChannels();
      
      final List<ChannelGuide> channelGuides = [];

      for (final channel in channels) {
        final schedule = await _engine.generateScheduleForDate(
          channel: channel,
          targetDate: now,
        );

        // Map standalone programs to app programs
        final programs = schedule.map((p) => _mapProgram(p)).toList();
        final nowPlaying = _engine.getNowPlaying(channel, schedule);

        channelGuides.add(ChannelGuide(
          channel: _mapChannel(channel),
          programs: programs,
          nowPlaying: nowPlaying != null ? _mapProgram(nowPlaying) : null,
        ));
      }

      _guide = GuideResponse(
        startTime: now,
        endTime: endTime,
        currentTime: now,
        guide: channelGuides,
      );

      _status = EpgStatus.loaded;
    } catch (e) {
      _status = EpgStatus.error;
      _errorMessage = 'Error local: $e';
      print('⚠️ EpgProvider Error: $e');
    }
    notifyListeners();
  }

  /// Get providers for a program from the local engine's pool.
  Future<ProvidersResponse?> getProviders(int tmdbId, String contentType) async {
    if (_providersCache.containsKey(tmdbId)) {
      return _providersCache[tmdbId];
    }

    try {
      // Find content in pool to get its providers
      final content = _engine.globalPool.firstWhere((c) => c.tmdbId == tmdbId);
      final providers = content.providers.map((p) => ProviderInfo.fromJson(p)).toList();
      
      final result = ProvidersResponse(providers: providers);
      _providersCache[tmdbId] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  // ── Mappers ─────────────────────────────────────────────────────────────────

  app_models.Program _mapProgram(standalone.Program p) {
    return app_models.Program(
      id: p.id,
      tmdbId: p.tmdbId,
      contentType: p.contentType.value,
      title: p.title,
      originalTitle: p.originalTitle,
      overview: p.overview,
      runtimeMinutes: p.runtimeMinutes,
      startTime: p.startTime,
      endTime: p.endTime,
      posterPath: p.posterPath,
      backdropPath: p.backdropPath,
      genres: p.genres.map((g) => g.toString()).toList(),
      releaseYear: p.releaseYear,
      voteAverage: p.voteAverage,
      slotLabel: p.slotLabel,
      providerName: p.providerName,
      providerLogo: p.providerLogo,
      deepLink: p.deepLink,
    );
  }

  app_models.Channel _mapChannel(standalone.Channel c) {
    return app_models.Channel(
      id: c.id,
      name: c.name,
      icon: c.icon,
      description: c.description,
    );
  }
}
