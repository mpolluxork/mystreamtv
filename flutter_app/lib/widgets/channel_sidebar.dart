import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/channel.dart';
import '../providers/focus_provider.dart';
import 'package:provider/provider.dart';

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
                  color: isActive ? kAccentColor.withOpacity(0.18) : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: isActive ? kAccentColor : Colors.transparent,
                      width: 3,
                    ),
                    bottom: BorderSide(color: kBorderColor, width: 0.5),
                    right: BorderSide(color: kBorderColor, width: 1),
                  ),
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
                        style: TextStyle(
                          color: isActive ? kTextPrimary : kTextSecondary,
                          fontSize: isActive ? 14 : 13,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
