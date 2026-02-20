import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../models/program.dart';
import '../providers/epg_provider.dart';
import '../providers/focus_provider.dart';
import '../widgets/channel_sidebar.dart';
import '../widgets/time_ruler.dart';
import '../widgets/program_card.dart';
import '../widgets/program_detail_overlay.dart';
import 'settings_screen.dart';
import 'channel_list_screen.dart';

class EpgScreen extends StatefulWidget {
  const EpgScreen({super.key});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  final _gridScrollH = ScrollController(); // horizontal (time)
  final _gridScrollV = ScrollController(); // vertical (channels)
  final _sidebarScroll = ScrollController();
  final _focusNode = FocusNode();
  
  // Top bar focus nodes
  final _settingsFocusNode = FocusNode();
  final _adminFocusNode = FocusNode();
  final _refreshFocusNode = FocusNode();

  Program? _selectedProgram;
  bool _detailOpen = false;

  @override
  void initState() {
    super.initState();
    // Sync vertical scroll between sidebar and grid
    _gridScrollV.addListener(() {
      if (_sidebarScroll.hasClients) {
        _sidebarScroll.jumpTo(_gridScrollV.offset);
      }
    });
    // Load guide on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EpgProvider>().loadGuide();
      // Request focus via FocusScope so the scope owns the focus anchor.
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _gridScrollH.dispose();
    _gridScrollV.dispose();
    _sidebarScroll.dispose();
    _focusNode.dispose();
    _settingsFocusNode.dispose();
    _adminFocusNode.dispose();
    _refreshFocusNode.dispose();
    super.dispose();
  }

  // ── D-pad navigation ────────────────────────────────────────────────────────

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    if (_detailOpen) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _closeDetail();
      }
      return;
    }

    final guide = context.read<EpgProvider>().guide;
    if (guide == null) return;
    final focus = context.read<FocusProvider>();
    final maxChannels = guide.guide.length;
    final maxPrograms = guide.guide[focus.channelIndex].programs.length;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (focus.channelIndex == 0) {
        // Move to top bar
        _settingsFocusNode.requestFocus();
      } else {
        focus.moveUp(maxChannels);
        _scrollToFocused(focus);
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      focus.moveDown(maxChannels);
      _scrollToFocused(focus);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      focus.moveLeft();
      _scrollToFocused(focus);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      focus.moveRight(maxPrograms);
      _scrollToFocused(focus);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      final programs = guide.guide[focus.channelIndex].programs;
      if (programs.isNotEmpty && focus.programIndex < programs.length) {
        _openDetail(programs[focus.programIndex]);
      }
    }
  }

  void _scrollToFocused(FocusProvider focus) {
    // Scroll channel row into view vertically
    final targetV = focus.channelIndex * kChannelRowHeight;
    if (_gridScrollV.hasClients) {
      _gridScrollV.animateTo(
        targetV,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _openDetail(Program program) {
    setState(() {
      _selectedProgram = program;
      _detailOpen = true;
    });
  }

  void _closeDetail() {
    setState(() {
      _detailOpen = false;
      _selectedProgram = null;
    });
    _focusNode.requestFocus();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
                child: PopScope(
                  canPop: !_detailOpen,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    if (_detailOpen) {
                      _closeDetail();
                    }
                  },
                  child: Scaffold(
                    backgroundColor: kBackgroundColor,
                    body: Stack(
                      children: [
                        Column(
                          children: [
                            _buildTopBar(context),
                            Expanded(child: _buildBody(context)),
                          ],
                        ),
                        // Detail overlay
                        if (_detailOpen && _selectedProgram != null)
                          ProgramDetailOverlay(
                            program: _selectedProgram!,
                            onClose: _closeDetail,
                          ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final tv = isTV(context);
    return Container(
      height: tv ? 64 : 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        border: Border(bottom: BorderSide(color: kBorderColor)),
      ),
      child: Row(
        children: [
          const Text('📺', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Text(
            'MyStreamTV',
            style: GoogleFonts.orbitron(
              color: kTextPrimary,
              fontSize: tv ? 24 : 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          _ClockWidget(),
          const SizedBox(width: 16),
          IconButton(
            focusNode: _settingsFocusNode,
            icon: const Icon(Icons.settings_rounded, color: kTextSecondary),
            style: IconButton.styleFrom(
              focusColor: kAccentColor.withOpacity(0.3),
            ),
            tooltip: 'Configuración',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _focusNode.requestFocus()),
          ),
          IconButton(
            focusNode: _adminFocusNode,
            icon: const Icon(Icons.playlist_add_check_rounded, color: kTextSecondary),
            style: IconButton.styleFrom(
              focusColor: kAccentColor.withOpacity(0.3),
            ),
            tooltip: 'Gestionar Canales',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChannelListScreen()),
            ).then((_) {
              _focusNode.requestFocus();
              context.read<EpgProvider>().loadGuide();
            }),
          ),
          IconButton(
            focusNode: _refreshFocusNode,
            icon: const Icon(Icons.refresh_rounded, color: kTextSecondary),
            style: IconButton.styleFrom(
              focusColor: kAccentColor.withOpacity(0.3),
            ),
            tooltip: 'Actualizar',
            onPressed: () => context.read<EpgProvider>().loadGuide(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<EpgProvider>(
      builder: (context, epg, _) {
        if (epg.isLoading) return _buildLoading();
        if (epg.status == EpgStatus.error) return _buildError(epg.errorMessage);
        if (epg.guide == null) return _buildLoading();
        return _buildEpgGrid(context, epg);
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: kAccentColor),
          const SizedBox(height: 24),
          Text(
            'Cargando guía de programación...',
            style: TextStyle(color: kTextSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String? message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_wifi_off_rounded, color: Colors.redAccent, size: 64),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar la guía',
            style: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'Error desconocido',
            style: TextStyle(color: kTextDim, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<EpgProvider>().loadGuide(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEpgGrid(BuildContext context, EpgProvider epg) {
    final guide = epg.guide!;
    final channels = guide.guide;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sidebar: channel list ──────────────────────────────────────────
        SizedBox(
          width: kSidebarWidth,
          child: Column(
            children: [
              // Spacer matching time ruler height
              Container(
                height: kTimeRulerHeight,
                color: kSurfaceColor,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'CANAL',
                  style: GoogleFonts.orbitron(
                    color: kAccentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                child: ChannelSidebar(
                  channels: channels.map((g) => g.channel).toList(),
                  scrollController: _sidebarScroll,
                  onChannelTap: (idx) {
                    context.read<FocusProvider>().moveTo(idx, 0);
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Main grid: time ruler + program rows ───────────────────────────
        Expanded(
          child: Column(
            children: [
              // Time ruler (horizontal scroll synced with grid)
              SizedBox(
                height: kTimeRulerHeight,
                child: TimeRuler(
                  startTime: guide.startTime,
                  scrollController: _gridScrollH,
                ),
              ),
              // Program rows — virtualized with ListView.builder
              Expanded(
                child: ListView.builder(
                  controller: _gridScrollV,
                  itemCount: channels.length,
                  itemExtent: kChannelRowHeight,
                  itemBuilder: (context, channelIdx) {
                    final channelGuide = channels[channelIdx];
                    return Consumer<FocusProvider>(
                      builder: (context, focus, _) {
                        final isActiveChannel = focus.channelIndex == channelIdx;
                        return Container(
                          decoration: BoxDecoration(
                            color: isActiveChannel
                                ? kAccentColor.withOpacity(0.05)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: kBorderColor, width: 0.5),
                            ),
                          ),
                          child: SingleChildScrollView(
                            controller: _gridScrollH, // FIXED: Use the global controller to sync all rows
                            scrollDirection: Axis.horizontal,
                            physics: isActiveChannel
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: Row(
                              children: [
                                for (int pi = 0; pi < channelGuide.programs.length; pi++)
                                  ProgramCard(
                                    program: channelGuide.programs[pi],
                                    guideStart: guide.startTime,
                                    isFocused: isActiveChannel && focus.programIndex == pi,
                                    onTap: () {
                                      context.read<FocusProvider>().moveTo(channelIdx, pi);
                                      _openDetail(channelGuide.programs[pi]);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Clock widget ──────────────────────────────────────────────────────────────

class _ClockWidget extends StatefulWidget {
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late String _time;
  late String _date;

  @override
  void initState() {
    super.initState();
    _update();
    // Refresh every second
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(_update);
    });
  }

  void _update() {
    final now = DateTime.now();
    _time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _date = _formatDate(now);
  }

  String _formatDate(DateTime d) {
    const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(_time,
            style: GoogleFonts.orbitron(
                color: kNowPlayingColor, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: kNowPlayingColor.withOpacity(0.5), blurRadius: 10)],
            )),
        Text(_date,
            style: GoogleFonts.shareTechMono(color: kTextSecondary, fontSize: 11)),
      ],
    );
  }
}
