import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/channel.dart';
import '../providers/focus_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ChannelSidebar extends StatelessWidget {
  final List<Channel> channels;
  final ScrollController scrollController;
  final void Function(int index) onChannelTap;

  const ChannelSidebar({
    super.key,
    required this.channels,
    required this.scrollController,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (context, focus, _) {
        return ListView.builder(
          controller: scrollController,
          itemCount: channels.length,
          itemExtent: kChannelRowHeight,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, idx) {
            final ch = channels[idx];
            final isActive = focus.channelIndex == idx;
            return GestureDetector(
              onTap: () => onChannelTap(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isActive ? kCardColor.withOpacity(0.5) : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: isActive ? kAccentColor : Colors.transparent,
                      width: isActive ? 4 : 0,
                    ),
                    bottom: BorderSide(color: kBorderColor, width: 0.5),
                    right: BorderSide(color: kBorderColor, width: 1),
                  ),
                  boxShadow: isActive ? [BoxShadow(color: kAccentGlow, blurRadius: 15)] : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      ch.icon,
                      style: TextStyle(fontSize: isActive ? 26 : 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ch.name,
                        style: GoogleFonts.shareTechMono(
                          color: isActive ? kAccentColor : kTextSecondary,
                          fontSize: isActive ? 14 : 12,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          shadows: isActive ? [Shadow(color: kAccentGlow, blurRadius: 4)] : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
