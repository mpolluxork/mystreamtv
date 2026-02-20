import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/storage_service.dart';
import '../models/standalone_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'channel_editor_screen.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  final LocalStorageService _storage = LocalStorageService();
  List<Channel> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    await _storage.initialize();
    final jsonStr = await _storage.loadChannels();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final channelsList = (data['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    setState(() {
      _channels = channelsList.map((ch) => Channel.fromJson(ch)).toList();
      _channels.sort((a, b) => b.priority.compareTo(a.priority));
      _isLoading = false;
    });
  }

  Future<void> _saveChannels() async {
    final data = {'channels': _channels.map((c) => c.toJson()).toList()};
    await _storage.saveChannels(jsonEncode(data));
  }

  Future<void> _toggleChannel(Channel channel) async {
    final index = _channels.indexWhere((c) => c.id == channel.id);
    if (index != -1) {
      setState(() {
        _channels[index] = Channel(
          id: channel.id,
          name: channel.name,
          icon: channel.icon,
          slots: channel.slots,
          enabled: !channel.enabled,
          priority: channel.priority,
          description: channel.description,
          createdAt: channel.createdAt,
          updatedAt: DateTime.now(),
        );
      });
      await _saveChannels();
    }
  }

  Future<void> _deleteChannel(Channel channel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: const Text('¿Eliminar Canal?', style: TextStyle(color: kTextPrimary)),
        content: Text('¿Estás seguro de que quieres eliminar "${channel.name}"?',
            style: const TextStyle(color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _channels.removeWhere((c) => c.id == channel.id);
      });
      await _saveChannels();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTV(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        title: Text('📺 GESTIÓN DE CANALES', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChannelEditorScreen(),
              ),
            ).then((_) => _loadChannels()),
            tooltip: 'Nuevo Canal',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _channels.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: tv ? 100 : 16,
                  ),
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final channel = _channels[index];
                    return _buildChannelCard(channel);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: Main HEART_CENTER,
        children: [
          const Icon(Icons.tv_off_rounded, size: 64, color: kTextDim),
          const SizedBox(height: 16),
          Text('No hay canales configurados',
              style: GoogleFonts.shareTechMono(color: kTextPrimary, fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear Primer Canal'),
            style: ElevatedButton.styleFrom(backgroundColor: kAccentColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChannelEditorScreen(),
              ),
            ).then((_) => _loadChannels()),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard(Channel channel) {
    return Card(
      color: kCardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: channel.enabled ? kAccentColor.withOpacity(0.5) : kBorderColor,
          width: channel.enabled ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Text(
          channel.icon,
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(
          channel.name,
          style: GoogleFonts.shareTechMono(
            color: channel.enabled ? kTextPrimary : kTextDim,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: ${channel.id} | Prioridad: ${channel.priority}',
              style: GoogleFonts.shareTechMono(color: kTextSecondary, fontSize: 12),
            ),
            if (channel.description != null && channel.description!.isNotEmpty)
              Text(
                channel.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextDim, fontSize: 13),
              ),
            Text(
              '${channel.slots.length} slots definidos',
              style: const TextStyle(color: kAccentColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: channel.enabled,
              activeColor: kAccentColor,
              onChanged: (_) => _toggleChannel(channel),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: kTextSecondary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChannelEditorScreen(channel: channel),
                ),
              ).then((_) => _loadChannels()),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: () => _deleteChannel(channel),
            ),
          ],
        ),
      ),
    );
  }
}
