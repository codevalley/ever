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
    final entry = await _isar.collection<CacheEntry>().filter().keyEqualTo(key).findFirst();
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
      await _isar.collection<CacheEntry>().put(entry);
    });
  }

  @override
  Future<void> remove(String key) async {
    await _isar.writeTxn(() async {
      await _isar.collection<CacheEntry>().filter().keyEqualTo(key).deleteAll();
    });
  }

  @override
  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.collection<CacheEntry>().clear();
    });
  }

  @override
  Future<bool> has(String key) async {
    return await _isar.collection<CacheEntry>().filter().keyEqualTo(key).findFirst() != null;
  }

  @override
  Future<void> dispose() async {
    // Isar is disposed elsewhere
  }
} 