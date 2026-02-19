/// A streaming provider with deep link info.
class ProviderInfo {
  final String providerName;
  final String? logoPath;
  final String? deepLink;

  const ProviderInfo({
    required this.providerName,
    this.logoPath,
    this.deepLink,
  });

  factory ProviderInfo.fromJson(Map<String, dynamic> json) => ProviderInfo(
        providerName: json['provider_name'] as String,
        logoPath: json['logo_path'] as String?,
        deepLink: json['deep_link'] as String?,
      );
}

/// Full response from GET /api/epg/program/{id}/providers
class ProvidersResponse {
  final int tmdbId;
  final String contentType;
  final List<ProviderInfo> providers;
  final String? tmdbLink;

  const ProvidersResponse({
    required this.tmdbId,
    required this.contentType,
    required this.providers,
    this.tmdbLink,
  });

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) =>
      ProvidersResponse(
        tmdbId: json['tmdb_id'] as int,
        contentType: json['content_type'] as String,
        providers: (json['providers'] as List<dynamic>)
            .map((p) => ProviderInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
        tmdbLink: json['tmdb_link'] as String?,
      );
}
