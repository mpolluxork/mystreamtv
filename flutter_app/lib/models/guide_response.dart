import 'channel.dart';
import 'program.dart';

/// One entry in the EPG guide: a channel + its programs in the time window.
class ChannelGuide {
  final Channel channel;
  final List<Program> programs;
  final Program? nowPlaying;

  const ChannelGuide({
    required this.channel,
    required this.programs,
    this.nowPlaying,
  });

  factory ChannelGuide.fromJson(Map<String, dynamic> json) => ChannelGuide(
        channel: Channel.fromJson(json['channel'] as Map<String, dynamic>),
        programs: (json['programs'] as List<dynamic>)
            .map((p) => Program.fromJson(p as Map<String, dynamic>))
            .toList(),
        nowPlaying: json['now_playing'] != null
            ? Program.fromJson(json['now_playing'] as Map<String, dynamic>)
            : null,
      );
}

/// Full response from GET /api/epg/guide
class GuideResponse {
  final DateTime startTime;
  final DateTime endTime;
  final DateTime currentTime;
  final List<ChannelGuide> guide;

  const GuideResponse({
    required this.startTime,
    required this.endTime,
    required this.currentTime,
    required this.guide,
  });

  factory GuideResponse.fromJson(Map<String, dynamic> json) => GuideResponse(
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        currentTime: DateTime.parse(json['current_time'] as String),
        guide: (json['guide'] as List<dynamic>)
            .map((g) => ChannelGuide.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}
