import 'dart:convert';

import 'package:isar/isar.dart';

import '../../domain/core/local_cache.dart';
import '../models/cache_entry.dart';

/// Isar implementation of local cache
class IsarCache implements LocalCache {
  final Isar _isar;

  IsarCache(this._isar);

  @override
  Future<void> initialize() async {
    // Isar is already initialized by the time we get here
  }

  @override
  Future<T?> get<T>(String key) async {
    final entry = await _isar.cacheEntries.get(key);
    if (entry == null) return null;

    final value = json.decode(entry.value);
    return value as T;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    final entry = CacheEntry()
      ..key = key
      ..value = json.encode(value)
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.cacheEntries.put(entry);
    });
  }

  @override
  Future<void> remove(String key) async {
    await _isar.writeTxn(() async {
      await _isar.cacheEntries.delete(key);
    });
  }

  @override
  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.cacheEntries.clear();
    });
  }

  @override
  Future<bool> has(String key) async {
    return await _isar.cacheEntries.get(key) != null;
  }

  @override
  Future<void> dispose() async {
    // Isar is disposed elsewhere
  }
} 