import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../domain/core/local_cache.dart';

/// File-based implementation of local cache
class FileCache implements LocalCache {
  final String _cacheDir;
  final Map<String, dynamic> _memoryCache = {};
  bool _initialized = false;

  FileCache(this._cacheDir);

  String _getPath(String key) => path.join(_cacheDir, '$key.json');

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Create cache directory if it doesn't exist
    await Directory(_cacheDir).create(recursive: true);
    
    // Load all cached values into memory
    final dir = Directory(_cacheDir);
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        final key = path.basenameWithoutExtension(file.path);
        final content = await file.readAsString();
        _memoryCache[key] = json.decode(content);
      }
    }
    
    _initialized = true;
  }

  @override
  Future<T?> get<T>(String key) async {
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key] as T?;
    }

    // Check file system
    final file = File(_getPath(key));
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final value = json.decode(content);
    _memoryCache[key] = value;
    return value as T?;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    // Update memory cache
    _memoryCache[key] = value;

    // Write to file
    final file = File(_getPath(key));
    await file.writeAsString(json.encode(value));
  }

  @override
  Future<void> remove(String key) async {
    // Remove from memory cache
    _memoryCache.remove(key);

    // Remove file
    final file = File(_getPath(key));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> clear() async {
    // Clear memory cache
    _memoryCache.clear();

    // Delete all cache files
    final dir = Directory(_cacheDir);
    if (await dir.exists()) {
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          await file.delete();
        }
      }
    }
  }

  @override
  Future<bool> has(String key) async {
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      return true;
    }

    // Check file system
    final file = File(_getPath(key));
    return await file.exists();
  }

  @override
  Future<void> dispose() async {
    _memoryCache.clear();
    _initialized = false;
  }
} 