/// Schedule Engine for MyStreamTV (Dart port from Python)
/// Generates and manages the EPG schedule using a global content pool

import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'mystreamtv_dart_models.dart';

class ScheduleEngine {
  late List<Channel> channels;
  late List<ContentMetadata> globalPool;
  final Map<String, List<Program>> scheduleCache = {};
  
  // Track content usage to prevent repetition
  final Map<String, Set<int>> contentUsage = {}; // {date_hour: {tmdb_ids}}
  
  // Track recently played content for cooldown (7 days for movies)
  final Map<String, Map<int, DateTime>> recentlyPlayed = {}; // {channel_id: {tmdb_id: last_date}}

  ScheduleEngine() {
    channels = [];
    globalPool = [];
  }

  /// Load persisted content pool from JSON
  Future<void> loadContentPool(String poolJson) async {
    try {
      final data = jsonDecode(poolJson) as List;
      globalPool = data
          .map((item) => ContentMetadata.fromJson(item as Map<String, dynamic>))
          .toList();
      print('📦 Loaded ${globalPool.length} items from persistent pool.');
    } catch (e) {
      print('⚠️ Error loading content pool: $e');
    }
  }

  /// Load cooldown data from JSON
  Future<void> loadCooldownData(String cooldownJson) async {
    try {
      final data = jsonDecode(cooldownJson) as Map<String, dynamic>;
      for (final channelId in data.keys) {
        recentlyPlayed[channelId] = {};
        final channelData = data[channelId] as Map<String, dynamic>;
        for (final tmdbIdStr in channelData.keys) {
          final tmdbId = int.parse(tmdbIdStr as String);
          final dateStr = channelData[tmdbIdStr] as String;
          recentlyPlayed[channelId]![tmdbId] = DateTime.parse(dateStr);
        }
      }
      print('✅ Loaded cooldown data.');
    } catch (e) {
      print('⚠️ Error loading cooldown data: $e');
    }
  }

  /// Save cooldown data to JSON string
  String saveCooldownData() {
    final data = <String, dynamic>{};
    for (final channelId in recentlyPlayed.keys) {
      data[channelId] = {};
      for (final tmdbId in recentlyPlayed[channelId]!.keys) {
        data[channelId][tmdbId.toString()] = 
            recentlyPlayed[channelId]![tmdbId]!.toIso8601String();
      }
    }
    return jsonEncode(data);
  }

  /// Load channels from JSON
  Future<void> loadChannels(String channelJson) async {
    try {
      final data = jsonDecode(channelJson) as Map<String, dynamic>;
      final channelsList = (data['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      channels = channelsList
          .map((ch) => Channel.fromJson(ch))
          .toList();
      
      // Sort by priority
      channels.sort((a, b) => b.priority.compareTo(a.priority));
      
      print('✅ Loaded ${channels.length} channels.');
      scheduleCache.clear();
    } catch (e) {
      print('⚠️ Error loading channels: $e');
    }
  }

  /// Get seed for deterministic randomness (same seed = same order each day)
  int _getSeed(String channelId, DateTime targetDate, int slotIndex) {
    final dateStr = targetDate.toString().split(' ')[0]; // YYYY-MM-DD
    final combined = '$channelId:$dateStr:$slotIndex';
    return combined.codeUnits.fold(0, (a, b) => a + b);
  }

  /// Filter pool by slot criteria
  List<ContentMetadata> _filterPoolBySlot(
    List<ContentMetadata> pool,
    TimeSlot slot,
    {required String channelId},
  ) {
    return pool.where((content) {
      // Content type check
      if (slot.contentType != null && content.mediaType != slot.contentType!.value) {
        return false;
      }

      // Decade check
      if (slot.decade != null) {
        if (content.decade == null || 
            content.decade! < slot.decade!.$1 || 
            content.decade! > slot.decade!.$2) {
          return false;
        }
      }

      // Vote average check
      if (slot.voteAverageMin != null && content.voteAverage < slot.voteAverageMin!) {
        return false;
      }

      // Genre check
      if (slot.genreIds.isNotEmpty) {
        if (!slot.genreIds.any((g) => content.genres.contains(g))) {
          return false;
        }
      }

      // Keywords check
      if (slot.keywords.isNotEmpty) {
        final matched = slot.keywords.any((kw) {
          final kwLower = kw.toLowerCase();
          return content.title.toLowerCase().contains(kwLower) ||
              content.overview.toLowerCase().contains(kwLower) ||
              content.keywords.any((k) => k.toLowerCase().contains(kwLower));
        });
        if (!matched) return false;
      }

      // Exclude keywords check
      for (final kw in slot.excludeKeywords) {
        final kwLower = kw.toLowerCase();
        if (content.title.toLowerCase().contains(kwLower) ||
            content.overview.toLowerCase().contains(kwLower) ||
            content.keywords.any((k) => k.toLowerCase().contains(kwLower))) {
          return false;
        }
      }

      // Universe check
      if (slot.universes.isNotEmpty) {
        final matched = slot.universes.any((u) => content.universes.contains(u));
        if (!matched) return false;
      }

      // Title contains check
      if (slot.titleContains.isNotEmpty) {
        final matched = slot.titleContains.any((pattern) {
          final patternLower = pattern.toLowerCase();
          return content.title.toLowerCase().contains(patternLower) ||
              content.originalTitle.toLowerCase().contains(patternLower) ||
              content.universes.any((u) => u.toLowerCase().contains(patternLower));
        });
        if (!matched) return false;
      }

      // Provider availability check
      if (content.providers.isEmpty) {
        return false;
      }

      // Cooldown check (7 days for movies)
      if (content.mediaType == 'movie') {
        if (!recentlyPlayed.containsKey(channelId)) {
          recentlyPlayed[channelId] = {};
        }
        
        final lastPlayed = recentlyPlayed[channelId]![content.tmdbId];
        if (lastPlayed != null) {
          final daysSincePlay = DateTime.now().difference(lastPlayed).inDays;
          if (daysSincePlay < 7) {
            return false; // Still in cooldown
          }
        }
      }

      // No deduplication here - that's handled at slot level
      return true;
    }).toList();
  }

  /// Fill a time slot with content
  List<Program> _fillSlotWithContent({
    required TimeSlot slot,
    required List<ContentMetadata> eligibleContent,
    required DateTime slotStart,
    required DateTime slotEnd,
    required int seed,
    required String channelId,
    int? lastContentId,
  }) {
    final programs = <Program>[];
    var currentTime = slotStart;
    final random = math.Random(seed);

    // Shuffle content deterministically using seed
    final shuffled = List<ContentMetadata>.from(eligibleContent);
    shuffled.shuffle(random);

    for (final content in shuffled) {
      if (currentTime >= slotEnd) break;

      // Skip if already used in this hour (deduplication)
      final hourKey = '${currentTime.year}-${currentTime.month}-${currentTime.day}:${currentTime.hour}';
      if (contentUsage.containsKey(hourKey) && 
          contentUsage[hourKey]!.contains(content.tmdbId)) {
        continue;
      }

      // Calculate runtime
      int runtime = content.runtime ?? 90;
      if (content.mediaType == 'tv' && runtime < 30) {
        runtime = 45; // Default TV episode
      }

      final programEnd = currentTime.add(Duration(minutes: runtime));

      // Check if fits in slot
      if (programEnd > slotEnd) {
        continue; // Skip if doesn't fit
      }

      // Track usage
      contentUsage.putIfAbsent(hourKey, () => {}).add(content.tmdbId);

      // Track cooldown for movies
      if (content.mediaType == 'movie') {
        recentlyPlayed.putIfAbsent(channelId, () => {})[content.tmdbId] = currentTime;
      }

      // Get provider
      String? providerName;
      String? providerLogo;
      if (content.providers.isNotEmpty) {
        final provider = content.providers[0];
        providerName = provider['provider_name'] as String?;
        providerLogo = provider['logo_path'] as String?;
      }

      // Create program
      final programId = '${channelId}_${currentTime.millisecondsSinceEpoch}_${content.tmdbId}';
      final program = Program(
        id: programId,
        tmdbId: content.tmdbId,
        contentType: ContentType.fromString(content.mediaType),
        title: content.title,
        originalTitle: content.originalTitle,
        overview: content.overview,
        runtimeMinutes: runtime,
        startTime: currentTime,
        endTime: programEnd,
        posterPath: content.posterPath,
        backdropPath: content.backdropPath,
        genres: content.genres,
        releaseYear: content.year,
        voteAverage: content.voteAverage,
        slotLabel: slot.label,
        providerName: providerName,
        providerLogo: providerLogo,
        deepLink: generateDeepLink(providerName, content.tmdbId, content.title),
      );

      programs.add(program);
      currentTime = programEnd;
    }

    return programs;
  }

  /// Generate full day schedule for a channel
  Future<List<Program>> generateScheduleForDate({
    required Channel channel,
    required DateTime targetDate,
  }) async {
    if (globalPool.isEmpty) {
      print('⚠️ Global pool is empty');
      return [];
    }

    final cacheKey = '${channel.id}:${targetDate.toString().split(' ')[0]}';

    if (scheduleCache.containsKey(cacheKey)) {
      return scheduleCache[cacheKey]!;
    }

    final allPrograms = <Program>[];
    var lastEndTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0);

    for (var slotIndex = 0; slotIndex < channel.slots.length; slotIndex++) {
      final slot = channel.slots[slotIndex];
      final seed = _getSeed(channel.id, targetDate, slotIndex);

      // Calculate slot datetime
      var slotStart = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        slot.startTime.hour,
        slot.startTime.minute,
      );
      var slotEnd = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        slot.endTime.hour,
        slot.endTime.minute,
      );

      // Handle midnight crossing
      if (slot.endTime <= slot.startTime) {
        slotEnd = slotEnd.add(const Duration(days: 1));
      }

      // Filter pool for this slot
      final eligibleContent = _filterPoolBySlot(globalPool, slot, channelId: channel.id);

      if (eligibleContent.isEmpty) {
        print('⚠️ No eligible content for ${channel.name} - ${slot.label}');
        continue;
      }

      // Start from where previous slot ended
      final actualStart = lastEndTime.isAfter(slotStart) ? lastEndTime : slotStart;

      // Skip if already past this slot
      if (actualStart.isAfter(slotEnd) || actualStart == slotEnd) {
        continue;
      }

      // Fill slot
      final programs = _fillSlotWithContent(
        slot: slot,
        eligibleContent: eligibleContent,
        slotStart: actualStart,
        slotEnd: slotEnd,
        seed: seed,
        channelId: channel.id,
      );

      if (programs.isNotEmpty) {
        lastEndTime = programs.last.endTime;
        allPrograms.addAll(programs);
      }
    }

    // Sort by start time
    allPrograms.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Cache
    scheduleCache[cacheKey] = allPrograms;

    return allPrograms;
  }

  /// Find what's currently playing
  Program? getNowPlaying(
    Channel channel,
    List<Program> schedule, {
    DateTime? currentTime,
  }) {
    currentTime ??= DateTime.now();

    try {
      return schedule.firstWhere(
        (p) => p.startTime.isBefore(currentTime!) && p.endTime.isAfter(currentTime),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get programs in time range
  List<Program> getProgramsInRange(
    List<Program> schedule,
    DateTime startTime,
    DateTime endTime,
  ) {
    return schedule
        .where((p) => p.endTime.isAfter(startTime) && p.startTime.isBefore(endTime))
        .toList();
  }

  /// Get all channels
  List<Channel> getAllChannels({bool includeDisabled = false}) {
    final filtered = includeDisabled 
        ? channels 
        : channels.where((c) => c.enabled).toList();
    
    filtered.sort((a, b) => b.priority.compareTo(a.priority));
    return filtered;
  }

  /// Export schedule for a channel to JSON
  String exportScheduleToJson(List<Program> schedule) {
    return jsonEncode(
      schedule.map((p) => p.toJson()).toList(),
    );
  }
}

/// Generate deep link for streaming provider
String? generateDeepLink(String? providerName, int contentId, String title) {
  if (providerName == null) return null;

  const providerUrls = {
    'netflix': 'https://www.netflix.com/search?q={title}',
    'disney_plus': 'https://www.disneyplus.com/search?q={title}',
    'hbo_max': 'https://www.hbomax.com/search?q={title}',
    'prime_video': 'https://www.amazon.com/s?k={title}',
    'paramount_plus': 'https://www.paramountplus.com/search?q={title}',
    'mubi': 'https://mubi.com/search?q={title}',
    'apple_tv': 'https://tv.apple.com/search?term={title}',
  };

  final providerKey = providerName.toLowerCase();
  String? template;

  // Find matching provider
  for (final key in providerUrls.keys) {
    if (providerKey.contains(key)) {
      template = providerUrls[key];
      break;
    }
  }

  if (template == null) return null;

  // Replace {title} if present
  if (template.contains('{title}')) {
    final encodedTitle = Uri.encodeComponent(title);
    return template.replaceAll('{title}', encodedTitle);
  }

  return template;
}
