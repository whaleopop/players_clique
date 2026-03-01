import 'dart:collection';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  final Map<String, Map<String, dynamic>> _cache = LinkedHashMap();
  final Duration _cacheDuration;
  static const String _cacheKey = 'app_cache';

  CacheService({Duration cacheDuration = const Duration(minutes: 5)})
      : _cacheDuration = cacheDuration {
    _loadCache();
  }

  // Existing methods...
  bool isCached(String key) {
    return _cache.containsKey(key);
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = jsonEncode(_cache);
    await prefs.setString(_cacheKey, cacheJson);
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString(_cacheKey);
    if (cacheJson != null) {
      final cacheData = jsonDecode(cacheJson) as Map<String, dynamic>;
      _cache.addAll(cacheData.map((key, value) => MapEntry(key, value as Map<String, dynamic>)));
    }
  }

  // Modify addToCache and addStringToCache to save cache after adding an item
  void addToCache(String key, DocumentSnapshot value) {
    if (_cache.length == 100) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = {'snapshot': value, 'addedAt': DateTime.now().toIso8601String()};
    // Note: not persisted to SharedPreferences as DocumentSnapshot is not JSON-serializable
  }


  void addStringToCache(String key, String value) {
    if (_cache.length == 100) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = {'value': value, 'addedAt': DateTime.now()};
    _saveCache(); // Save cache after adding an item
  }

  // Add a method to clear the cache and save the empty state
  void clearCache() {
    _cache.clear();
    _saveCache(); // Save the empty state
  }

  // Add a method to remove an item from the cache and save the updated state
  void removeFromCache(String key) {
    _cache.remove(key);
    _saveCache(); // Save the updated state
  }
  DocumentSnapshot? getFromCache(String key) {
    if (_cache.containsKey(key)) {
      final cacheEntry = _cache[key];
      if (cacheEntry != null) {
        return cacheEntry['snapshot'] as DocumentSnapshot?;
      }
    }
    return null;
  }

}
