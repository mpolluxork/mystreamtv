import 'package:flutter/material.dart';

// ── TMDB ──────────────────────────────────────────────────────────────────────
const String kTmdbImageBase = 'https://image.tmdb.org/t/p';

String tmdbPoster(String? path, {String size = 'w342'}) =>
    path != null ? '$kTmdbImageBase/$size$path' : '';

String tmdbBackdrop(String? path, {String size = 'w1280'}) =>
    path != null ? '$kTmdbImageBase/$size$path' : '';

String tmdbLogo(String? path, {String size = 'w92'}) =>
    path != null ? '$kTmdbImageBase/$size$path' : '';

// ── COLORS ────────────────────────────────────────────────────────────────────
const Color kBackgroundColor = Color(0xFF080818);
const Color kSurfaceColor    = Color(0xFF12122A);
const Color kCardColor       = Color(0xFF1A1A35);
const Color kAccentColor     = Color(0xFF7C3AED); // violet
const Color kAccentGlow      = Color(0x557C3AED);
const Color kNowPlayingColor = Color(0xFF10B981); // emerald
const Color kTextPrimary     = Color(0xFFEEEEFF);
const Color kTextSecondary   = Color(0xFF9999BB);
const Color kTextDim         = Color(0xFF555577);
const Color kBorderColor     = Color(0xFF2A2A4A);

// ── LAYOUT ────────────────────────────────────────────────────────────────────
/// Width of the channel sidebar in pixels
const double kSidebarWidth = 220.0;

/// Height of each channel row in the EPG grid
const double kChannelRowHeight = 80.0;

/// Height of the time ruler
const double kTimeRulerHeight = 40.0;

/// Pixels per minute in the EPG grid
const double kMinuteWidth = 5.0;

/// Minimum card width (for very short programs)
const double kMinCardWidth = 120.0;

// ── TV vs MOBILE ──────────────────────────────────────────────────────────────
bool isTV(BuildContext context) =>
    MediaQuery.of(context).size.width >= 1200;

bool isTablet(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  return w >= 600 && w < 1200;
}

// ── FONT SIZES ────────────────────────────────────────────────────────────────
double titleSize(BuildContext context)    => isTV(context) ? 32.0 : 20.0;
double subtitleSize(BuildContext context) => isTV(context) ? 20.0 : 14.0;
double bodySize(BuildContext context)     => isTV(context) ? 18.0 : 13.0;
double metaSize(BuildContext context)     => isTV(context) ? 16.0 : 12.0;
