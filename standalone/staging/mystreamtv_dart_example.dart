/// Example integration in a Flutter application
/// This shows how to use ScheduleEngine + LocalStorageService

import 'package:flutter/material.dart';
import 'dart:convert';
import 'mystreamtv_dart_models.dart';
import 'mystreamtv_dart_schedule_engine.dart';
import 'mystreamtv_dart_storage.dart';

class EPGViewModel extends ChangeNotifier {
  final LocalStorageService storage;
  late ScheduleEngine scheduleEngine;

  List<Channel> channels = [];
  Map<String, List<Program>> schedules = {}; // channelId -> schedule
  bool isLoading = true;
  String? errorMessage;

  DateTime selectedDate = DateTime.now();

  EPGViewModel({required this.storage}) {
    scheduleEngine = ScheduleEngine();
  }

  /// Initialize the EPG system
  Future<void> initialize() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // Load all data from storage
      final poolJson = await storage.loadContentPool();
      final cooldownJson = await storage.loadCooldownData();
      final channelsJson = await storage.loadChannels();

      // Initialize schedule engine
      await scheduleEngine.loadContentPool(poolJson);
      await scheduleEngine.loadCooldownData(cooldownJson);
      await scheduleEngine.loadChannels(channelsJson);

      channels = scheduleEngine.getAllChannels();

      print('✅ EPG initialized with ${channels.length} channels');
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error initializing EPG: $e';
      isLoading = false;
      notifyListeners();
      print('⚠️ Initialization error: $e');
    }
  }

  /// Generate schedule for a specific channel and date
  Future<List<Program>> getScheduleForChannel(
    Channel channel,
    DateTime date,
  ) async {
    try {
      final cacheKey = '${channel.id}:${date.toString().split(' ')[0]}';

      if (schedules.containsKey(cacheKey)) {
        return schedules[cacheKey]!;
      }

      final schedule = await scheduleEngine.generateScheduleForDate(
        channel: channel,
        targetDate: date,
      );

      schedules[cacheKey] = schedule;
      notifyListeners();

      // Save cooldown data after generation
      final cooldownJson = scheduleEngine.saveCooldownData();
      await storage.saveCooldownData(cooldownJson);

      return schedule;
    } catch (e) {
      print('⚠️ Error generating schedule: $e');
      return [];
    }
  }

  /// Get currently playing program on a channel
  Future<Program?> getNowPlaying(Channel channel) async {
    try {
      final schedule = await getScheduleForChannel(channel, DateTime.now());
      return scheduleEngine.getNowPlaying(channel, schedule);
    } catch (e) {
      print('⚠️ Error getting now playing: $e');
      return null;
    }
  }

  /// Get programs in next N hours
  Future<List<Program>> getUpcomingPrograms(
    Channel channel,
    int hoursAhead,
  ) async {
    try {
      final now = DateTime.now();
      final endTime = now.add(Duration(hours: hoursAhead));

      final schedule = await getScheduleForChannel(channel, now);
      return scheduleEngine.getProgramsInRange(schedule, now, endTime);
    } catch (e) {
      print('⚠️ Error getting upcoming programs: $e');
      return [];
    }
  }

  /// Update channels configuration
  Future<void> updateChannels(List<Channel> newChannels) async {
    try {
      channels = newChannels;
      
      // Save to storage
      final channelsJson = jsonEncode({
        'channels': channels.map((c) => c.toJson()).toList(),
      });
      await storage.saveChannels(channelsJson);

      // Reload schedule engine
      await scheduleEngine.loadChannels(channelsJson);
      
      // Clear schedule cache to force regeneration
      schedules.clear();
      scheduleEngine.scheduleCache.clear();

      notifyListeners();
      print('✅ Channels updated');
    } catch (e) {
      errorMessage = 'Error updating channels: $e';
      notifyListeners();
      print('⚠️ Error updating channels: $e');
    }
  }

  /// Refresh content pool from external source
  Future<void> refreshContentPool(List<Map<String, dynamic>> newPoolData) async {
    try {
      isLoading = true;
      notifyListeners();

      // Save new pool
      await storage.saveContentPool(newPoolData);

      // Reload in schedule engine
      await scheduleEngine.loadContentPool(jsonEncode(newPoolData));

      // Clear caches
      schedules.clear();
      scheduleEngine.scheduleCache.clear();

      isLoading = false;
      notifyListeners();
      print('✅ Content pool refreshed (${newPoolData.length} items)');
    } catch (e) {
      errorMessage = 'Error refreshing content pool: $e';
      isLoading = false;
      notifyListeners();
      print('⚠️ Error refreshing pool: $e');
    }
  }

  /// Get storage info
  Future<String> getStorageInfo() async {
    try {
      final sizeBytes = await storage.getStorageSize();
      final sizeMB = sizeBytes / (1024 * 1024);
      return '${sizeMB.toStringAsFixed(2)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Clear all data
  Future<void> clearAll() async {
    try {
      await storage.clearAll();
      scheduleEngine = ScheduleEngine();
      channels = [];
      schedules.clear();
      
      notifyListeners();
      print('✅ All data cleared');
    } catch (e) {
      errorMessage = 'Error clearing data: $e';
      notifyListeners();
    }
  }
}

/// Example Widget that uses the EPG
class EPGGridScreen extends StatefulWidget {
  @override
  State<EPGGridScreen> createState() => _EPGGridScreenState();
}

class _EPGGridScreenState extends State<EPGGridScreen> {
  late EPGViewModel viewModel;

  @override
  void initState() {
    super.initState();
    final storage = LocalStorageService();
    viewModel = EPGViewModel(storage: storage);
    
    // Initialize on first load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await storage.initialize();
      await viewModel.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyStreamTV - EPG'),
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.errorMessage != null) {
            return Center(
              child: Text('Error: ${viewModel.errorMessage}'),
            );
          }

          return ListView.builder(
            itemCount: viewModel.channels.length,
            itemBuilder: (context, index) {
              final channel = viewModel.channels[index];
              return ChannelTile(
                channel: channel,
                viewModel: viewModel,
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget for displaying a single channel
class ChannelTile extends StatefulWidget {
  final Channel channel;
  final EPGViewModel viewModel;

  const ChannelTile({
    required this.channel,
    required this.viewModel,
  });

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  List<Program> schedule = [];
  bool isLoadingSchedule = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => isLoadingSchedule = true);
    
    schedule = await widget.viewModel.getScheduleForChannel(
      widget.channel,
      DateTime.now(),
    );
    
    setState(() => isLoadingSchedule = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Text(
                  widget.channel.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.channel.description != null)
                        Text(
                          widget.channel.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Schedule list
          if (isLoadingSchedule)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(),
            )
          else
            ...schedule.take(5).map((program) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                child: ProgramTile(program: program),
              );
            }).toList(),
        ],
      ),
    );
  }
}

/// Widget for displaying a single program
class ProgramTile extends StatelessWidget {
  final Program program;

  const ProgramTile({required this.program});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Text(
            '${_formatTime(program.startTime)} - ${_formatTime(program.endTime)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          // Title
          Text(
            program.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Provider
          if (program.providerName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                program.providerName!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
