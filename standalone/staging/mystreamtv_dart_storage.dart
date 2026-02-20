/// Local storage service for MyStreamTV
/// Handles JSON persistence for pools, channels, and cooldown data

import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const String poolFileName = 'content_pool.json';
  static const String cooldownFileName = 'cooldown.json';
  static const String channelsFileName = 'channels.json';
  static const String dataFolderName = 'mystreamtv_data';

  late Directory _dataDirectory;

  /// Initialize storage directory
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _dataDirectory = Directory('${appDir.path}/$dataFolderName');
      
      if (!await _dataDirectory.exists()) {
        await _dataDirectory.create(recursive: true);
      }
      
      print('✅ Storage initialized at: ${_dataDirectory.path}');
    } catch (e) {
      print('⚠️ Error initializing storage: $e');
      rethrow;
    }
  }

  /// Save content pool
  Future<void> saveContentPool(List<Map<String, dynamic>> poolData) async {
    try {
      final file = File('${_dataDirectory.path}/$poolFileName');
      final json = jsonEncode(poolData);
      await file.writeAsString(json);
      print('✅ Content pool saved (${poolData.length} items)');
    } catch (e) {
      print('⚠️ Error saving content pool: $e');
      rethrow;
    }
  }

  /// Load content pool
  Future<String> loadContentPool() async {
    try {
      final file = File('${_dataDirectory.path}/$poolFileName');
      if (await file.exists()) {
        final json = await file.readAsString();
        print('✅ Content pool loaded');
        return json;
      }
      return '[]'; // Return empty array if doesn't exist
    } catch (e) {
      print('⚠️ Error loading content pool: $e');
      return '[]';
    }
  }

  /// Save cooldown data
  Future<void> saveCooldownData(String cooldownJson) async {
    try {
      final file = File('${_dataDirectory.path}/$cooldownFileName');
      await file.writeAsString(cooldownJson);
      print('✅ Cooldown data saved');
    } catch (e) {
      print('⚠️ Error saving cooldown data: $e');
      rethrow;
    }
  }

  /// Load cooldown data
  Future<String> loadCooldownData() async {
    try {
      final file = File('${_dataDirectory.path}/$cooldownFileName');
      if (await file.exists()) {
        final json = await file.readAsString();
        print('✅ Cooldown data loaded');
        return json;
      }
      return '{}'; // Return empty object if doesn't exist
    } catch (e) {
      print('⚠️ Error loading cooldown data: $e');
      return '{}';
    }
  }

  /// Save channels configuration
  Future<void> saveChannels(String channelsJson) async {
    try {
      final file = File('${_dataDirectory.path}/$channelsFileName');
      await file.writeAsString(channelsJson);
      print('✅ Channels configuration saved');
    } catch (e) {
      print('⚠️ Error saving channels: $e');
      rethrow;
    }
  }

  /// Load channels configuration
  Future<String> loadChannels() async {
    try {
      final file = File('${_dataDirectory.path}/$channelsFileName');
      if (await file.exists()) {
        final json = await file.readAsString();
        print('✅ Channels configuration loaded');
        return json;
      }
      // Return default structure if doesn't exist
      return jsonEncode({'channels': []});
    } catch (e) {
      print('⚠️ Error loading channels: $e');
      return jsonEncode({'channels': []});
    }
  }

  /// Get storage directory size
  Future<int> getStorageSize() async {
    try {
      var totalSize = 0;
      if (await _dataDirectory.exists()) {
        final files = _dataDirectory.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      return totalSize;
    } catch (e) {
      print('⚠️ Error getting storage size: $e');
      return 0;
    }
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    try {
      if (await _dataDirectory.exists()) {
        await _dataDirectory.delete(recursive: true);
        await _dataDirectory.create(recursive: true);
      }
      print('✅ All data cleared');
    } catch (e) {
      print('⚠️ Error clearing data: $e');
      rethrow;
    }
  }

  /// Get data directory path (useful for debugging)
  String getDataPath() => _dataDirectory.path;
}
