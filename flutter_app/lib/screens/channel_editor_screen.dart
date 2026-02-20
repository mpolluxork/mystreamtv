import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/storage_service.dart';
import '../models/standalone_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class ChannelEditorScreen extends StatefulWidget {
  final Channel? channel;
  const ChannelEditorScreen({super.key, this.channel});

  @override
  State<ChannelEditorScreen> createState() => _ChannelEditorScreenState();
}

class _ChannelEditorScreenState extends State<ChannelEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocalStorageService _storage = LocalStorageService();
  
  late TextEditingController _nameController;
  late TextEditingController _iconController;
  late TextEditingController _priorityController;
  late TextEditingController _descriptionController;
  
  List<TimeSlot> _slots = [];
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _isNew = widget.channel == null;
    _nameController = TextEditingController(text: widget.channel?.name ?? '');
    _iconController = TextEditingController(text: widget.channel?.icon ?? '📺');
    _priorityController = TextEditingController(text: (widget.channel?.priority ?? 50).toString());
    _descriptionController = TextEditingController(text: widget.channel?.description ?? '');
    _slots = widget.channel != null ? List.from(widget.channel!.slots) : [];
    
    // Default slot if new
    if (_isNew && _slots.isEmpty) {
      _slots.add(TimeSlot(
        startTime: TimeOfDay(hour: 0, minute: 0),
        endTime: TimeOfDay(hour: 23, minute: 59),
        label: 'Programación General',
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _priorityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final channelId = widget.channel?.id ?? const Uuid().v4();
    final newChannel = Channel(
      id: channelId,
      name: _nameController.text.trim(),
      icon: _iconController.text.trim(),
      slots: _slots,
      priority: int.tryParse(_priorityController.text) ?? 50,
      description: _descriptionController.text.trim(),
      enabled: widget.channel?.enabled ?? true,
      createdAt: widget.channel?.createdAt,
      updatedAt: DateTime.now(),
    );

    await _storage.initialize();
    final currentJson = await _storage.loadChannels();
    final currentData = jsonDecode(currentJson) as Map<String, dynamic>;
    final List<dynamic> channelsList = currentData['channels'] ?? [];
    
    final index = channelsList.indexWhere((c) => c['id'] == channelId);
    if (index != -1) {
      channelsList[index] = newChannel.toJson();
    } else {
      channelsList.add(newChannel.toJson());
    }

    await _storage.saveChannels(jsonEncode({'channels': channelsList}));
    if (mounted) Navigator.pop(context);
  }

  void _addSlot() {
    setState(() {
      _slots.add(TimeSlot(
        startTime: TimeOfDay(hour: 0, minute: 0),
        endTime: TimeOfDay(hour: 4, minute: 0),
        label: 'Nuevo Segmento',
      ));
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTV(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        title: Text(_isNew ? '✨ NUEVO CANAL' : '✏️ EDITAR CANAL', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: kAccentColor, size: 28),
            onPressed: _save,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            vertical: 24,
            horizontal: tv ? 150 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Información General'),
              _buildGeneralInfo(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Segmentos Horarios (Slots)'),
                  TextButton.icon(
                    onPressed: _addSlot,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Añadir Slot'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._slots.asMap().entries.map((entry) => _buildSlotCard(entry.key, entry.value)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.orbitron(
          color: kAccentColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _iconController,
                  decoration: const InputDecoration(labelText: 'Icono'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre del Canal'),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _priorityController,
                  decoration: const InputDecoration(labelText: 'Prioridad (0-100)'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(int index, TimeSlot slot) {
    return Card(
      color: kCardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Etiqueta de Slot'),
                    controller: TextEditingController(text: slot.label),
                    onChanged: (v) => _updateSlot(index, label: v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _removeSlot(index),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildTimePicker('Inicia', slot.startTime, (t) => _updateSlot(index, start: t)),
                const SizedBox(width: 24),
                _buildTimePicker('Termina', slot.endTime, (t) => _updateSlot(index, end: t)),
                const Spacer(),
                DropdownButton<ContentType?>(
                  value: slot.contentType,
                  dropdownColor: kSurfaceColor,
                  hint: const Text('Tipo Contenido'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Cualquier tipo')),
                    DropdownMenuItem(value: ContentType.movie, child: Text('🎬 Películas')),
                    DropdownMenuItem(value: ContentType.tv, child: Text('📺 Series')),
                  ],
                  onChanged: (v) => _updateSlot(index, type: v),
                ),
              ],
            ),
            const Divider(height: 32, color: kBorderColor),
            // Advanced Filters Summary/Button
            ExpansionTile(
              title: Text('Filtros Avanzados', style: GoogleFonts.shareTechMono(fontSize: 14, color: kTextPrimary)),
              subtitle: Text(
                _getSlotSummary(slot),
                style: GoogleFonts.shareTechMono(fontSize: 12, color: kTextDim),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                _buildFilterItem('Géneros TMDB IDs (comas)', slot.genreIds.join(', '), 
                    (v) => _updateSlot(index, genres: v.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterItem('Min Rating', slot.voteAverageMin?.toString() ?? '', 
                          (v) => _updateSlot(index, rating: double.tryParse(v))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFilterItem('Década (ej: 1980)', slot.decade?.$1.toString() ?? '', 
                          (v) {
                            final year = int.tryParse(v);
                            if (year != null) {
                              _updateSlot(index, decade: (year, year + 9));
                            } else {
                              _updateSlot(index, decade: null);
                            }
                          }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFilterItem('Keywords (comas)', slot.keywords.join(', '), 
                    (v) => _updateSlot(index, keywords: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList())),
                const SizedBox(height: 12),
                _buildFilterItem('Universos (Star Wars, Marvel...)', slot.universes.join(', '), 
                    (v) => _updateSlot(index, universes: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList())),
                const SizedBox(height: 12),
                _buildFilterItem('Título contiene...', slot.titleContains.join(', '), 
                    (v) => _updateSlot(index, titleContains: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, Function(TimeOfDay) onSelected) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: flutterTime(time),
        );
        if (picked != null) onSelected(dartTime(picked));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextDim, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.shareTechMono(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem(String label, String initialValue, Function(String) onChanged) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.shareTechMono(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: GoogleFonts.shareTechMono(fontSize: 14),
      onChanged: onChanged,
    );
  }

  String _getSlotSummary(TimeSlot slot) {
    List<String> activeList = [];
    if (slot.genreIds.isNotEmpty) activeList.add('${slot.genreIds.length} géneros');
    if (slot.decade != null) activeList.add('${slot.decade!.$1}s');
    if (slot.voteAverageMin != null) activeList.add('> ${slot.voteAverageMin}★');
    if (slot.keywords.isNotEmpty) activeList.add('${slot.keywords.length} keywords');
    if (slot.universes.isNotEmpty) activeList.add('${slot.universes.length} universos');
    
    return activeList.isEmpty ? 'Sin filtros avanzados' : 'Filtros: ${activeList.join(', ')}';
  }

  void _updateSlot(int index, {
    String? label,
    TimeOfDay? start,
    TimeOfDay? end,
    ContentType? type,
    List<int>? genres,
    double? rating,
    (int, int)? decade,
    List<String>? keywords,
    List<String>? universes,
    List<String>? titleContains,
  }) {
    final old = _slots[index];
    setState(() {
      _slots[index] = TimeSlot(
        startTime: start ?? old.startTime,
        endTime: end ?? old.endTime,
        label: label ?? old.label,
        contentType: type ?? old.contentType,
        genreIds: genres ?? old.genreIds,
        voteAverageMin: rating ?? old.voteAverageMin,
        decade: decade ?? old.decade,
        keywords: keywords ?? old.keywords,
        universes: universes ?? old.universes,
        titleContains: titleContains ?? old.titleContains,
        excludeKeywords: old.excludeKeywords,
        withPeople: old.withPeople,
        collections: old.collections,
        originalLanguage: old.originalLanguage,
        productionCountries: old.productionCountries,
        isFavoritesOnly: old.isFavoritesOnly,
      );
    });
  }

  // Helpers to convert Between our TimeOfDay and Flutter's
  flutterTime(TimeOfDay t) => TimeOfDay(hour: t.hour, minute: t.minute);
  dartTime(tp) => TimeOfDay(hour: tp.hour, minute: tp.minute);
}
