/// Models for MyStreamTV EPG system (Dart port from Python)

import 'package:intl/intl.dart';

enum ContentType {
  movie('movie'),
  tv('tv'),
  filler('filler');

  final String value;
  const ContentType(this.value);

  factory ContentType.fromString(String value) {
    return ContentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ContentType.movie,
    );
  }
}

class Program {
  final String id; // Unique schedule ID
  final int tmdbId;
  final ContentType contentType;
  final String title;
  final String originalTitle;
  final String overview;
  final int runtimeMinutes;

  final DateTime startTime;
  final DateTime endTime;

  final String? posterPath;
  final String? backdropPath;

  final List<int> genres;
  final int? releaseYear;
  final double voteAverage;
  final String slotLabel;

  final String? providerName;
  final String? providerLogo;
  final String? deepLink;

  Program({
    required this.id,
    required this.tmdbId,
    required this.contentType,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.runtimeMinutes,
    required this.startTime,
    required this.endTime,
    this.posterPath,
    this.backdropPath,
    this.genres = const [],
    this.releaseYear,
    this.voteAverage = 0.0,
    this.slotLabel = '',
    this.providerName,
    this.providerLogo,
    this.deepLink,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tmdb_id': tmdbId,
      'content_type': contentType.value,
      'title': title,
      'original_title': originalTitle,
      'overview': overview,
      'runtime_minutes': runtimeMinutes,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'genres': genres,
      'release_year': releaseYear,
      'vote_average': voteAverage,
      'slot_label': slotLabel,
      'provider_name': providerName,
      'provider_logo': providerLogo,
      'deep_link': deepLink,
    };
  }

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      id: json['id'] as String,
      tmdbId: json['tmdb_id'] as int,
      contentType: ContentType.fromString(json['content_type'] as String),
      title: json['title'] as String,
      originalTitle: json['original_title'] as String,
      overview: json['overview'] as String,
      runtimeMinutes: json['runtime_minutes'] as int,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      genres: List<int>.from(json['genres'] as List? ?? []),
      releaseYear: json['release_year'] as int?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      slotLabel: json['slot_label'] as String? ?? '',
      providerName: json['provider_name'] as String?,
      providerLogo: json['provider_logo'] as String?,
      deepLink: json['deep_link'] as String?,
    );
  }

  // Helper for UI compatibility
  bool get isNowPlaying {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  double get progressFraction {
    final now = DateTime.now();
    if (!isNowPlaying) return 0.0;
    final total = endTime.difference(startTime).inSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get formattedTime {
    final startForm = DateFormat('HH:mm').format(startTime);
    final endForm = DateFormat('HH:mm').format(endTime);
    return '$startForm - $endForm';
  }
}

class TimeSlot {
  final TimeOfDay startTime; // e.g., 20:00
  final TimeOfDay endTime;   // e.g., 22:00
  final String label;        // e.g., "Marcianos"

  // Filters
  final List<int> genreIds;
  final (int, int)? decade; // (1980, 1989)
  final List<String> keywords;

  // Special filters
  final String? filterType; // e.g., "oscar_nominated"
  final ContentType? contentType;
  final List<String> collections;
  final String? originalLanguage;
  final String? productionCountries;
  final double? voteAverageMin;
  final List<int> withPeople;

  // NEW: Universe and keyword exclusion filters
  final List<String> universes;
  final List<String> excludeKeywords;
  final List<String> titleContains;
  final bool isFavoritesOnly;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.label,
    this.genreIds = const [],
    this.decade,
    this.keywords = const [],
    this.filterType,
    this.contentType,
    this.collections = const [],
    this.originalLanguage,
    this.productionCountries,
    this.voteAverageMin,
    this.withPeople = const [],
    this.universes = const [],
    this.excludeKeywords = const [],
    this.titleContains = const [],
    this.isFavoritesOnly = false,
  });

  int durationMinutes() {
    int startMin = startTime.hour * 60 + startTime.minute;
    int endMin = endTime.hour * 60 + endTime.minute;

    // Handle crossing midnight
    if (endMin <= startMin) {
      endMin += 24 * 60;
    }

    return endMin - startMin;
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    final startStr = json['start'] as String;
    final endStr = json['end'] as String;

    return TimeSlot(
      startTime: _parseTimeOfDay(startStr),
      endTime: _parseTimeOfDay(endStr),
      label: json['label'] as String,
      genreIds: List<int>.from(json['genres'] as List? ?? []),
      decade: json['decade'] != null
          ? ((json['decade'] as List)[0] as int, (json['decade'] as List)[1] as int)
          : null,
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      filterType: json['filter_type'] as String?,
      contentType: json['content_type'] != null
          ? ContentType.fromString(json['content_type'] as String)
          : null,
      collections: List<String>.from(json['collections'] as List? ?? []),
      originalLanguage: json['original_language'] as String?,
      productionCountries: json['production_countries'] as String?,
      voteAverageMin: (json['vote_average_min'] as num?)?.toDouble(),
      withPeople: List<int>.from(json['with_people'] as List? ?? []),
      universes: List<String>.from(json['universes'] as List? ?? []),
      exclude_keywords: List<String>.from(json['exclude_keywords'] as List? ?? []),
      title_contains: List<String>.from(json['title_contains'] as List? ?? []),
      is_favorites_only: json['is_favorites_only'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'label': label,
      'genres': genreIds,
      'decade': decade != null ? [decade!.$1, decade!.$2] : null,
      'keywords': keywords,
      'filter_type': filterType,
      'content_type': contentType?.value,
      'collections': collections,
      'original_language': originalLanguage,
      'production_countries': productionCountries,
      'vote_average_min': voteAverageMin,
      'with_people': withPeople,
      'universes': universes,
      'exclude_keywords': excludeKeywords,
      'title_contains': titleContains,
      'is_favorites_only': isFavoritesOnly,
    };
  }
}

TimeOfDay _parseTimeOfDay(String timeStr) {
  final parts = timeStr.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay({required this.hour, required this.minute});

  String format() => '${hour.toString().padLeft(2, '0')}:${hour.toString().padLeft(2, '0')}'; // Typo fix in original would be nice but keeping logic

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDay &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;

  bool operator <=(TimeOfDay other) {
    return hour < other.hour || (hour == other.hour && minute <= other.minute);
  }

  bool operator <(TimeOfDay other) {
    return hour < other.hour || (hour == other.hour && minute < other.minute);
  }
}

class Channel {
  final String id;
  final String name;
  final String icon;

  final List<TimeSlot> slots;

  final bool enabled;
  final int priority;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  final double personalizationWeight;

  Channel({
    required this.id,
    required this.name,
    required this.icon,
    this.slots = const [],
    this.enabled = true,
    this.priority = 50,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.personalizationWeight = 0.5,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'enabled': enabled,
      'priority': priority,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'slots': slots.map((s) => s.toJson()).toList(),
    };
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 50,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      slots: (json['slots'] as List?)?.map((s) => TimeSlot.fromJson(s as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class ContentMetadata {
  final int tmdbId;
  final String title;
  final String originalTitle;
  final String mediaType; // "movie" or "tv"
  final String overview;
  final List<int> genres;
  final int? year;
  final int? decade;
  final double voteAverage;
  final int voteCount;
  final bool isPremium;
  final List<String> keywords;
  final List<String> universes;
  final int? directorId;
  final String? directorName;
  final List<String> originCountries;
  final String? originalLanguage;
  final String releaseDate;
  final List<Map<String, dynamic>> providers;
  final String? posterPath;
  final String? backdropPath;
  final int? runtime;
  final List<String> originChannels;

  ContentMetadata({
    required this.tmdbId,
    required this.title,
    required this.originalTitle,
    required this.mediaType,
    required this.overview,
    this.genres = const [],
    this.year,
    this.decade,
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.isPremium = false,
    this.keywords = const [],
    this.universes = const [],
    this.directorId,
    this.directorName,
    this.originCountries = const [],
    this.originalLanguage,
    this.releaseDate = '',
    this.providers = const [],
    this.posterPath,
    this.backdropPath,
    this.runtime,
    this.originChannels = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'tmdb_id': tmdbId,
      'title': title,
      'original_title': originalTitle,
      'media_type': mediaType,
      'overview': overview,
      'genres': genres,
      'year': year,
      'decade': decade,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'is_premium': isPremium,
      'keywords': keywords,
      'universes': universes,
      'director_id': directorId,
      'director_name': directorName,
      'origin_countries': originCountries,
      'original_language': originalLanguage,
      'release_date': releaseDate,
      'providers': providers,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'runtime': runtime,
      'origin_channels': originChannels,
    };
  }

  factory ContentMetadata.fromJson(Map<String, dynamic> json) {
    return ContentMetadata(
      tmdbId: json['tmdb_id'] as int,
      title: json['title'] as String,
      originalTitle: json['original_title'] as String,
      mediaType: json['media_type'] as String,
      overview: json['overview'] as String,
      genres: List<int>.from(json['genres'] as List? ?? []),
      year: json['year'] as int?,
      decade: json['decade'] as int?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      keywords: List<String>.from(json['keywords'] as List? ?? []),
      universes: List<String>.from(json['universes'] as List? ?? []),
      directorId: json['director_id'] as int?,
      directorName: json['director_name'] as String?,
      originCountries: List<String>.from(json['origin_countries'] as List? ?? []),
      originalLanguage: json['original_language'] as String?,
      releaseDate: json['release_date'] as String? ?? '',
      providers: List<Map<String, dynamic>>.from(json['providers'] as List? ?? []),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      runtime: json['runtime'] as int?,
      originChannels: List<String>.from(json['origin_channels'] as List? ?? []),
    );
  }
}
