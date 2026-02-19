import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        decoration: BoxDecoration(
          color: isFocused
              ? kAccentColor.withOpacity(0.25)
              : isNow
                  ? kNowPlayingColor.withOpacity(0.08)
                  : kCardColor.withOpacity(0.6),
          border: Border(
            left: BorderSide(color: kBorderColor, width: 0.5),
            top: BorderSide(
              color: isFocused
                  ? kAccentColor
                  : isNow
                      ? kNowPlayingColor
                      : Colors.transparent,
              width: isFocused ? 2.5 : 2,
            ),
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: kAccentGlow, blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        child: Stack(
          children: [
            // Progress bar for now-playing
            if (isNow)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: program.progressFraction,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(kNowPlayingColor.withOpacity(0.5)),
                  minHeight: 2,
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  // Poster thumbnail (only if card is wide enough)
                  if (width > 160 && program.posterPath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
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
                      children: [
                        if (program.slotLabel.isNotEmpty)
                          Text(
                            program.slotLabel.toUpperCase(),
                            style: TextStyle(
                              color: isFocused ? kAccentColor : kTextDim,
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
                          style: TextStyle(
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EN VIVO',
                        style: TextStyle(
                          color: Colors.white,
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
