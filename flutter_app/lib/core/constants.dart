import 'package:flutter/material.dart';
import 'device_info.dart';

// ── TMDB ──────────────────────────────────────────────────────────────────────
const String kTmdbImageBase = 'https://image.tmdb.org/t/p';

String tmdbPoster(String? path, {String size = 'w342'}) =>
    path != null ? '$kTmdbImageBase/$size$path' : '';

String tmdbBackdrop(String? path, {String size = 'w1280'}) =>
    path != null ? '$kTmdbImageBase/$size$path' : '';

String tmdbLogo(String? path, {String size = 'w92'}) =>
    path != null ? '$kTmdbImageBase/$size$path' : '';

// ── COLORS ────────────────────────────────────────────────────────────────────
const Color kBackgroundColor = Color(0xFF0A0A12); // --epg-bg-dark
const Color kSurfaceColor    = Color(0xFF12121E); // --epg-bg-medium
const Color kCardColor       = Color(0xFF1A1A2E); // --epg-bg-light / card base
const Color kAccentColor     = Color(0xFF00D9FF); // --epg-accent-cyan
const Color kAccentGlow      = Color(0x6600D9FF);
const Color kAccentPink      = Color(0xFFE94560); // --epg-accent-pink
const Color kNowPlayingColor = Color(0xFF00FF41); // --epg-accent-green
const Color kTextPrimary     = Color(0xFFFFFFFF);
const Color kTextSecondary   = Color(0xFFA0AEC0);
const Color kTextDim         = Color(0xFF64748B);
const Color kBorderColor     = Color(0xFF334155); // --epg-time-line

// ── LAYOUT ────────────────────────────────────────────────────────────────────
/// Width of the channel sidebar in pixels
const double kSidebarWidth = 220.0;

/// Height of each channel row in the EPG grid
const double kChannelRowHeight = 70.0;

/// Height of the time ruler
const double kTimeRulerHeight = 40.0;

/// Pixels per minute in the EPG grid
const double kMinuteWidth = 4.0;

/// Minimum card width (for very short programs)
const double kMinCardWidth = 100.0;

// ── TV vs MOBILE ──────────────────────────────────────────────────────────────
/// Returns true when the app is running on an Android TV / Google TV device.
/// Detection is two-layered:
///   1. Native: UiModeManager reports UI_MODE_TYPE_TELEVISION (see DeviceInfo).
///   2. Fallback: screen width ≥ 1280 px (raised from 1200 to reduce
///      false-positives on large tablets in landscape).
bool isTV(BuildContext context) =>
    DeviceInfo.isTV || MediaQuery.of(context).size.width >= 1280;

bool isTablet(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  return w >= 600 && w < 1200;
}

// ── FONT SIZES ────────────────────────────────────────────────────────────────
double titleSize(BuildContext context)    => isTV(context) ? 32.0 : 20.0;
double subtitleSize(BuildContext context) => isTV(context) ? 20.0 : 14.0;
double bodySize(BuildContext context)     => isTV(context) ? 18.0 : 13.0;
double metaSize(BuildContext context)     => isTV(context) ? 16.0 : 12.0;
