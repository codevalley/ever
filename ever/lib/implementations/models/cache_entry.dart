import 'package:isar/isar.dart';

part 'cache_entry.g.dart';

/// Model for cache entries in Isar
@collection
class CacheEntry {
  /// The key is used as the ID
  Id get id => fastHash(key);
  
  /// The key for the cache entry
  @Index(unique: true, replace: true)
  String key = '';

  /// The value stored as a JSON string
  String value = '';

  /// When the entry was last updated
  DateTime updatedAt = DateTime.now();
}

/// Fast string hash function
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
} 