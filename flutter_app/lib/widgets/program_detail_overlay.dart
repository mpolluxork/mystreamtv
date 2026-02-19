import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

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

  ProvidersResponse? _providers;
  bool _loadingProviders = true;

  @override
  void initState() {
    super.initState();
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
  }

  Future<void> _loadProviders() async {
    final result = await context.read<EpgProvider>().getProviders(
          widget.program.tmdbId,
          widget.program.contentType,
        );
    if (mounted) {
      setState(() {
        _providers = result;
        _loadingProviders = false;
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final tv = isTV(context);
    final p = widget.program;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack)) {
          _close();
        }
      },
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
        // Backdrop image
        SizedBox(
          height: tv ? 280 : 180,
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
        // Gradient overlay
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
        // Close button
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
            ),
            onPressed: _close,
          ),
        ),
        // Title overlay at bottom of backdrop
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tv ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta row
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

          const SizedBox(height: 16),

          // Overview
          if (p.overview.isNotEmpty) ...[
            Text(
              p.overview,
              style: TextStyle(
                color: kTextSecondary,
                fontSize: tv ? 16 : 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Providers section
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _providers!.providers
                  .map((prov) => _ProviderButton(
                        provider: prov,
                        onTap: prov.deepLink != null
                            ? () => _openLink(prov.deepLink!)
                            : null,
                      ))
                  .toList(),
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
          style: TextStyle(color: color ?? kTextSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatefulWidget {
  final ProviderInfo provider;
  final VoidCallback? onTap;

  const _ProviderButton({required this.provider, this.onTap});

  @override
  State<_ProviderButton> createState() => _ProviderButtonState();
}

class _ProviderButtonState extends State<_ProviderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? kAccentColor : kCardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? kAccentColor : kBorderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.provider.logoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: tmdbLogo(widget.provider.logoPath),
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (widget.provider.logoPath != null) const SizedBox(width: 8),
              Text(
                'Ver en ${widget.provider.providerName}',
                style: TextStyle(
                  color: _hovered ? Colors.white : kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: _hovered ? Colors.white70 : kTextDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
