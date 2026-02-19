/// A single program in the EPG schedule.
class Program {
  final String id;
  final int tmdbId;
  final String contentType; // 'movie' | 'tv'
  final String title;
  final String originalTitle;
  final String overview;
  final int runtimeMinutes;
  final DateTime startTime;
  final DateTime endTime;
  final String? posterPath;
  final String? backdropPath;
  final List<String> genres;
  final int? releaseYear;
  final double voteAverage;
  final String slotLabel;
  final String? providerName;
  final String? providerLogo;
  final String? deepLink;

  const Program({
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
    required this.genres,
    this.releaseYear,
    required this.voteAverage,
    required this.slotLabel,
    this.providerName,
    this.providerLogo,
    this.deepLink,
  });

  factory Program.fromJson(Map<String, dynamic> json) => Program(
        id: json['id'] as String,
        tmdbId: json['tmdb_id'] as int,
        contentType: json['content_type'] as String? ?? 'movie',
        title: json['title'] as String,
        originalTitle: json['original_title'] as String? ?? '',
        overview: json['overview'] as String? ?? '',
        runtimeMinutes: json['runtime_minutes'] as int? ?? 90,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        posterPath: json['poster_path'] as String?,
        backdropPath: json['backdrop_path'] as String?,
        genres: (json['genres'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        releaseYear: json['release_year'] as int?,
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
        slotLabel: json['slot_label'] as String? ?? '',
        providerName: json['provider_name'] as String?,
        providerLogo: json['provider_logo'] as String?,
        deepLink: json['deep_link'] as String?,
      );

  bool get isNowPlaying {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  double get progressFraction {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return 0.0;
    if (now.isAfter(endTime)) return 1.0;
    final total = endTime.difference(startTime).inSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    return elapsed / total;
  }

  String get formattedTime {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(startTime.hour)}:${pad(startTime.minute)} – '
        '${pad(endTime.hour)}:${pad(endTime.minute)}';
  }
}
