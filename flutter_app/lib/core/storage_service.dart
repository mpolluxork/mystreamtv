/// Local Storage Service for MyStreamTV (Standalone)
/// Manages saving and loading JSON data to the device's persistent storage

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalStorageService {
  static const String poolFile = 'content_pool.json';
  static const String cooldownFile = 'cooldown.json';
  static const String channelsFile = 'channels.json';

  bool _isInitialized = false;
  late Directory _appDir;

  /// Initialize the storage service by getting the app documents directory
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _appDir = await getApplicationDocumentsDirectory();
      _isInitialized = true;
      print('💾 Storage initialized at: ${_appDir.path}');
    } catch (e) {
      print('⚠️ Error initializing storage: $e');
    }
  }

  // ── Content Pool ────────────────────────────────────────────────────────────

  Future<void> saveContentPool(List<Map<String, dynamic>> data) async {
    await _saveFile(poolFile, jsonEncode(data));
  }

  Future<String> loadContentPool() async {
    // Try to load from documents first
    final local = await _readFile(poolFile);
    if (local != null) return local;

    // Fallback to assets for first run
    try {
      print('ℹ️ Loading content pool from assets...');
      return await rootBundle.loadString('assets/data/$poolFile');
    } catch (e) {
      print('⚠️ Content pool not found in documents or assets');
      return '[]';
    }
  }

  // ── Cooldown Data ───────────────────────────────────────────────────────────

  Future<void> saveCooldownData(String json) async {
    await _saveFile(cooldownFile, json);
  }

  Future<String> loadCooldownData() async {
    final local = await _readFile(cooldownFile);
    if (local != null) return local;

    // Cooldown is always empty on first run
    return '{}';
  }

  // ── Channels ────────────────────────────────────────────────────────────────

  Future<void> saveChannels(String json) async {
    await _saveFile(channelsFile, json);
  }

  Future<String> loadChannels() async {
    // Try to load from documents first
    final local = await _readFile(channelsFile);
    if (local != null) return local;

    // Fallback to assets for first run
    try {
      print('ℹ️ Loading channels from assets...');
      return await rootBundle.loadString('assets/data/$channelsFile');
    } catch (e) {
      print('⚠️ Channels not found in documents or assets');
      return '{"channels": []}';
    }
  }

  // ── Internal Helpers ────────────────────────────────────────────────────────

  Future<void> _saveFile(String fileName, String content) async {
    if (!_isInitialized) await initialize();
    try {
      final file = File('${_appDir.path}/$fileName');
      await file.writeAsString(content);
    } catch (e) {
      print('⚠️ Error saving $fileName: $e');
    }
  }

  Future<String?> _readFile(String fileName) async {
    if (!_isInitialized) await initialize();
    try {
      final file = File('${_appDir.path}/$fileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('⚠️ Error reading $fileName: $e');
    }
    return null;
  }

  Future<int> getStorageSize() async {
    if (!_isInitialized) await initialize();
    int total = 0;
    try {
      final files = [poolFile, cooldownFile, channelsFile];
      for (final name in files) {
        final f = File('${_appDir.path}/$name');
        if (await f.exists()) {
          total += await f.length();
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> clearAll() async {
    if (!_isInitialized) await initialize();
    final files = [poolFile, cooldownFile, channelsFile];
    for (final name in files) {
      final f = File('${_appDir.path}/$name');
      if (await f.exists()) {
        await f.delete();
      }
    }
  }
}
