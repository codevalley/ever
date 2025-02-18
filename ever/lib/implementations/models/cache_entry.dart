import 'package:isar/isar.dart';

part 'cache_entry.g.dart';

/// Model for cache entries in Isar
@Collection(inheritance: false)
class CacheEntry {
  Id get id => Isar.autoIncrement; // Isar id

  @Index(unique: true, replace: true)
  late String key;

  late String value;

  @Index()
  late DateTime updatedAt;

  CacheEntry();

  @override
  String toString() {
    return 'CacheEntry{key: $key, value: $value, updatedAt: $updatedAt}';
  }
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