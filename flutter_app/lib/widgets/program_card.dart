import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/program.dart';

class ProgramCard extends StatelessWidget {
  final Program program;
  final DateTime guideStart;
  final bool isFocused;
  final VoidCallback onTap;

  const ProgramCard({
    super.key,
    required this.program,
    required this.guideStart,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = (program.runtimeMinutes * kMinuteWidth).clamp(kMinCardWidth, 9999.0);
    final isNow = program.isNowPlaying;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: kChannelRowHeight,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          // Sleek cyberpunk background gradient
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isFocused
                ? [kCardColor.withOpacity(0.9), kCardColor.withOpacity(0.7)]
                : isNow
                    ? [kCardColor.withOpacity(0.6), kNowPlayingColor.withOpacity(0.1)]
                    : [kCardColor.withOpacity(0.6), kCardColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isFocused
                ? kAccentColor
                : isNow
                    ? kNowPlayingColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(color: kAccentGlow, blurRadius: 15, spreadRadius: 1),
                  BoxShadow(color: kAccentColor.withOpacity(0.1), blurRadius: 30, inset: true),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Top gradient line for focused items (Cyberpunk specific)
            if (isFocused)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                    gradient: LinearGradient(
                      colors: [kAccentColor, kAccentPink],
                    ),
                  ),
                ),
              ),

            // Progress bar for now-playing
            if (isNow)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
                  child: LinearProgressIndicator(
                    value: program.progressFraction,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(kNowPlayingColor.withOpacity(0.5)),
                    minHeight: 2,
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  // Poster thumbnail
                  if (width > 100 && program.posterPath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: CachedNetworkImage(
                        imageUrl: tmdbPoster(program.posterPath, size: 'w92'),
                        width: 40,
                        height: 58,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 40, height: 58,
                          color: kBorderColor,
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Text info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (program.slotLabel.isNotEmpty)
                          Text(
                            program.slotLabel.toUpperCase(),
                            style: GoogleFonts.shareTechMono(
                              color: isFocused ? kAccentColor : kAccentPink,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          program.title,
                          style: TextStyle(
                            color: isFocused ? kTextPrimary : kTextSecondary,
                            fontSize: 13,
                            fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          program.formattedTime,
                          style: GoogleFonts.shareTechMono(
                            color: kTextDim,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Now playing indicator
                  if (isNow)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: kNowPlayingColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'EN VIVO',
                        style: GoogleFonts.orbitron(
                          color: kBackgroundColor,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
