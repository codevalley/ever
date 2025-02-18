/// Interface for local caching
abstract class LocalCache {
  /// Initialize the cache
  Future<void> initialize();

  /// Get a value from cache
  Future<T?> get<T>(String key);

  /// Set a value in cache
  Future<void> set<T>(String key, T value);

  /// Remove a value from cache
  Future<void> remove(String key);

  /// Clear all values from cache
  Future<void> clear();

  /// Check if a key exists in cache
  Future<bool> has(String key);

  /// Dispose resources
  Future<void> dispose();
} 