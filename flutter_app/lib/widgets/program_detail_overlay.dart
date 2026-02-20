import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../models/program.dart';
import '../models/provider_info.dart';
import '../providers/epg_provider.dart';

class ProgramDetailOverlay extends StatefulWidget {
  final Program program;
  final VoidCallback onClose;

  const ProgramDetailOverlay({
    super.key,
    required this.program,
    required this.onClose,
  });

  @override
  State<ProgramDetailOverlay> createState() => _ProgramDetailOverlayState();
}

class _ProgramDetailOverlayState extends State<ProgramDetailOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // GAP-4 fix: named FocusNode with proper lifecycle (replaces the previous
  // anonymous `FocusNode()..requestFocus()` that was never disposed).
  late FocusNode _overlayFocusNode;

  ProvidersResponse? _providers;
  bool _loadingProviders = true;

  // GAP-2: one FocusNode per provider button for D-pad navigation.
  List<FocusNode> _providerFocusNodes = [];
  int _focusedProviderIndex = 0;

  @override
  void initState() {
    super.initState();

    // GAP-4: proper lifecycle
    _overlayFocusNode = FocusNode();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();

    _loadProviders();

    // Capture keyboard focus when the overlay appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    // GAP-4: properly release overlay focus node
    _overlayFocusNode.dispose();
    // GAP-2: release all per-provider focus nodes
    for (final fn in _providerFocusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProviders() async {
    final result = await context.read<EpgProvider>().getProviders(
          widget.program.tmdbId,
          widget.program.contentType,
        );
    if (!mounted) return;

    // GAP-2: build one FocusNode per returned provider
    final newNodes = List.generate(
      result?.providers.length ?? 0,
      (_) => FocusNode(),
    );

    setState(() {
      _providers = result;
      _loadingProviders = false;
      for (final fn in _providerFocusNodes) fn.dispose();
      _providerFocusNodes = newNodes;
      _focusedProviderIndex = 0;
    });

    // Auto-focus first provider button on TV
    if (newNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) newNodes[0].requestFocus();
      });
    }
  }

  Future<void> _close() async {
    await _anim.reverse();
    widget.onClose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // GAP-2: D-pad handler for the overlay keyboard events.
  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;

    // Close overlay
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _close();
      return;
    }

    final providers = _providers?.providers ?? [];
    if (providers.isEmpty) return;

    if (key == LogicalKeyboardKey.arrowLeft) {
      final next = (_focusedProviderIndex - 1).clamp(0, providers.length - 1);
      setState(() => _focusedProviderIndex = next);
      _providerFocusNodes[next].requestFocus();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final next = (_focusedProviderIndex + 1).clamp(0, providers.length - 1);
      setState(() => _focusedProviderIndex = next);
      _providerFocusNodes[next].requestFocus();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      final deepLink = providers[_focusedProviderIndex].deepLink;
      if (deepLink != null) _openLink(deepLink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTV(context);
    final p = widget.program;

    return KeyboardListener(
      focusNode: _overlayFocusNode, // GAP-4: named node, properly disposed
      onKeyEvent: _handleKey,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black.withOpacity(0.75),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // prevent close when tapping inside
                child: SlideTransition(
                  position: _slide,
                  child: Container(
                    width: tv ? 900 : double.infinity,
                    margin: EdgeInsets.all(tv ? 0 : 16),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: kSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBackdrop(p, tv),
                          Flexible(child: _buildContent(p, tv)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackdrop(Program p, bool tv) {
    return Stack(
      children: [
        SizedBox(
          height: tv ? 220 : 160, // Reduced from 280
          width: double.infinity,
          child: p.backdropPath != null
              ? CachedNetworkImage(
                  imageUrl: tmdbBackdrop(p.backdropPath),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: kCardColor),
                  errorWidget: (_, __, ___) => Container(color: kCardColor),
                )
              : Container(color: kCardColor),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  kSurfaceColor.withOpacity(0.8),
                  kSurfaceColor,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            onPressed: _close,
          ),
        ),
        Positioned(
          bottom: 16,
          left: 20,
          right: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.slotLabel.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kAccentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.slotLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              Text(
                p.title,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: tv ? 28 : 20,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    const Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                    Shadow(color: kAccentColor.withOpacity(0.5), blurRadius: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Program p, bool tv) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, tv ? 40 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (p.releaseYear != null)
                _metaChip(Icons.calendar_today_rounded, '${p.releaseYear}'),
              _metaChip(Icons.schedule_rounded, '${p.runtimeMinutes} min'),
              _metaChip(Icons.access_time_rounded, p.formattedTime),
              if (p.voteAverage > 0)
                _metaChip(Icons.star_rounded, p.voteAverage.toStringAsFixed(1),
                    color: Colors.amber),
              if (p.genres.isNotEmpty)
                _metaChip(Icons.label_rounded, p.genres.take(2).join(', ')),
            ],
          ),
          SizedBox(height: tv ? 12 : 16),
          if (p.overview.isNotEmpty) ...[
            Text(
              p.overview,
              style: GoogleFonts.shareTechMono(
                color: kTextSecondary,
                fontSize: tv ? 16 : 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'DISPONIBLE EN',
            style: TextStyle(
              color: kTextDim,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingProviders)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_providers == null || _providers!.providers.isEmpty)
            Text(
              'No hay plataformas disponibles en México para este título.',
              style: TextStyle(color: kTextDim, fontSize: tv ? 14 : 12),
            )
          else
            // GAP-2: each button gets its own managed FocusNode
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int i = 0; i < _providers!.providers.length; i++)
                  _ProviderButton(
                    provider: _providers!.providers[i],
                    focusNode: _providerFocusNodes[i],
                    onTap: _providers!.providers[i].deepLink != null
                        ? () => _openLink(_providers!.providers[i].deepLink!)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? kTextDim),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: color ?? kTextSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

// ── Provider Button ────────────────────────────────────────────────────────────

/// GAP-2: Accepts an external [focusNode] managed by the overlay so the parent
/// can drive D-pad navigation with left/right arrows.
/// GAP-2: Visual feedback uses [Focus.of(context).hasFocus] instead of the
/// previous mouse-only [MouseRegion] — works with both remote and pointer.
class _ProviderButton extends StatelessWidget {
  final ProviderInfo provider;
  final FocusNode focusNode;
  final VoidCallback? onTap;

  const _ProviderButton({
    required this.provider,
    required this.focusNode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return MouseRegion(
            // Keep mouse hover working for desktop/mobile
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: focused 
                      ? const LinearGradient(colors: [kAccentColor, kAccentPink])
                      : LinearGradient(colors: [kCardColor, kCardColor.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: focused ? Colors.white : kBorderColor,
                    width: focused ? 1.5 : 1,
                  ),
                  boxShadow: focused
                      ? [BoxShadow(color: kAccentColor.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.logoPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: tmdbLogo(provider.logoPath),
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    if (provider.logoPath != null) const SizedBox(width: 8),
                    Text(
                      'VER EN ${provider.providerName.toUpperCase()}',
                      style: GoogleFonts.orbitron(
                        color: focused ? Colors.white : kTextPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: focused ? Colors.white70 : kTextDim,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
