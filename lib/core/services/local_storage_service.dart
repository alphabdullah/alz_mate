import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // String operations
  Future<void> setString(String key, String value) async {
    await initialize();
    await _prefs!.setString(key, value);
  }

  Future<String?> getString(String key) async {
    await initialize();
    return _prefs!.getString(key);
  }

  // Integer operations
  Future<void> setInt(String key, int value) async {
    await initialize();
    await _prefs!.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    await initialize();
    return _prefs!.getInt(key);
  }

  // Boolean operations
  Future<void> setBool(String key, bool value) async {
    await initialize();
    await _prefs!.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    await initialize();
    return _prefs!.getBool(key);
  }

  // Double operations
  Future<void> setDouble(String key, double value) async {
    await initialize();
    await _prefs!.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    await initialize();
    return _prefs!.getDouble(key);
  }

  // List operations
  Future<void> setStringList(String key, List<String> value) async {
    await initialize();
    await _prefs!.setStringList(key, value);
  }

  Future<List<String>?> getStringList(String key) async {
    await initialize();
    return _prefs!.getStringList(key);
  }

  // JSON operations
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await initialize();
    final jsonString = json.encode(value);
    await _prefs!.setString(key, jsonString);
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    await initialize();
    final jsonString = _prefs!.getString(key);
    if (jsonString != null) {
      try {
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        print('Error decoding JSON for key $key: $e');
        return null;
      }
    }
    return null;
  }

  // List of JSON objects
  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    await initialize();
    final jsonString = json.encode(value);
    await _prefs!.setString(key, jsonString);
  }

  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    await initialize();
    final jsonString = _prefs!.getString(key);
    if (jsonString != null) {
      try {
        final decoded = json.decode(jsonString) as List;
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Error decoding JSON list for key $key: $e');
        return null;
      }
    }
    return null;
  }

  // Remove operations
  Future<void> remove(String key) async {
    await initialize();
    await _prefs!.remove(key);
  }

  Future<void> clear() async {
    await initialize();
    await _prefs!.clear();
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    await initialize();
    return _prefs!.containsKey(key);
  }

  // Get all keys
  Future<Set<String>> getAllKeys() async {
    await initialize();
    return _prefs!.getKeys();
  }

  // User-specific storage methods
  Future<void> setUserData(String userId, String key, dynamic value) async {
    final userKey = 'user_${userId}_$key';
    
    if (value is String) {
      await setString(userKey, value);
    } else if (value is int) {
      await setInt(userKey, value);
    } else if (value is bool) {
      await setBool(userKey, value);
    } else if (value is double) {
      await setDouble(userKey, value);
    } else if (value is List<String>) {
      await setStringList(userKey, value);
    } else if (value is Map<String, dynamic>) {
      await setJson(userKey, value);
    } else if (value is List<Map<String, dynamic>>) {
      await setJsonList(userKey, value);
    } else {
      throw ArgumentError('Unsupported value type: ${value.runtimeType}');
    }
  }

  Future<T?> getUserData<T>(String userId, String key) async {
    final userKey = 'user_${userId}_$key';
    
    if (T == String) {
      return await getString(userKey) as T?;
    } else if (T == int) {
      return await getInt(userKey) as T?;
    } else if (T == bool) {
      return await getBool(userKey) as T?;
    } else if (T == double) {
      return await getDouble(userKey) as T?;
    } else {
      throw ArgumentError('Unsupported type: $T');
    }
  }

  Future<Map<String, dynamic>?> getUserJson(String userId, String key) async {
    final userKey = 'user_${userId}_$key';
    return await getJson(userKey);
  }

  Future<List<Map<String, dynamic>>?> getUserJsonList(String userId, String key) async {
    final userKey = 'user_${userId}_$key';
    return await getJsonList(userKey);
  }

  Future<void> removeUserData(String userId, String key) async {
    final userKey = 'user_${userId}_$key';
    await remove(userKey);
  }

  Future<void> clearUserData(String userId) async {
    await initialize();
    final keys = _prefs!.getKeys();
    final userKeys = keys.where((key) => key.startsWith('user_${userId}_'));
    
    for (final key in userKeys) {
      await _prefs!.remove(key);
    }
  }

  // App settings
  Future<void> setAppSetting(String key, dynamic value) async {
    await setUserData('app', key, value);
  }

  Future<T?> getAppSetting<T>(String key) async {
    return await getUserData<T>('app', key);
  }

  // Cache management
  Future<void> setCacheData(String key, Map<String, dynamic> data, {Duration? expiry}) async {
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };
    
    await setJson('cache_$key', cacheData);
  }

  Future<Map<String, dynamic>?> getCacheData(String key) async {
    final cacheData = await getJson('cache_$key');
    
    if (cacheData == null) return null;
    
    final timestamp = cacheData['timestamp'] as int?;
    final expiry = cacheData['expiry'] as int?;
    
    if (timestamp != null && expiry != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > expiry) {
        // Cache expired, remove it
        await remove('cache_$key');
        return null;
      }
    }
    
    return cacheData['data'] as Map<String, dynamic>?;
  }

  Future<void> clearCache() async {
    await initialize();
    final keys = _prefs!.getKeys();
    final cacheKeys = keys.where((key) => key.startsWith('cache_'));
    
    for (final key in cacheKeys) {
      await _prefs!.remove(key);
    }
  }

  // Backup and restore
  Future<Map<String, dynamic>> exportData() async {
    await initialize();
    final keys = _prefs!.getKeys();
    final data = <String, dynamic>{};
    
    for (final key in keys) {
      final value = _prefs!.get(key);
      data[key] = value;
    }
    
    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
  }

  Future<void> importData(Map<String, dynamic> backupData) async {
    await initialize();
    
    final data = backupData['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ArgumentError('Invalid backup data format');
    }
    
    // Clear existing data
    await _prefs!.clear();
    
    // Import data
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is String) {
        await _prefs!.setString(key, value);
      } else if (value is int) {
        await _prefs!.setInt(key, value);
      } else if (value is bool) {
        await _prefs!.setBool(key, value);
      } else if (value is double) {
        await _prefs!.setDouble(key, value);
      } else if (value is List<String>) {
        await _prefs!.setStringList(key, value);
      }
    }
  }

  // Statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    await initialize();
    final keys = _prefs!.getKeys();
    
    int totalKeys = keys.length;
    int userDataKeys = 0;
    int cacheKeys = 0;
    int appSettingKeys = 0;
    
    for (final key in keys) {
      if (key.startsWith('user_')) {
        userDataKeys++;
      } else if (key.startsWith('cache_')) {
        cacheKeys++;
      } else if (key.startsWith('app_')) {
        appSettingKeys++;
      }
    }
    
    return {
      'totalKeys': totalKeys,
      'userDataKeys': userDataKeys,
      'cacheKeys': cacheKeys,
      'appSettingKeys': appSettingKeys,
      'otherKeys': totalKeys - userDataKeys - cacheKeys - appSettingKeys,
    };
  }

  // Utility methods
  Future<void> incrementCounter(String key) async {
    final current = await getInt(key) ?? 0;
    await setInt(key, current + 1);
  }

  Future<void> decrementCounter(String key) async {
    final current = await getInt(key) ?? 0;
    await setInt(key, current - 1);
  }

  Future<void> addToList(String key, String value) async {
    final list = await getStringList(key) ?? <String>[];
    if (!list.contains(value)) {
      list.add(value);
      await setStringList(key, list);
    }
  }

  Future<void> removeFromList(String key, String value) async {
    final list = await getStringList(key) ?? <String>[];
    list.remove(value);
    await setStringList(key, list);
  }

  Future<void> toggleBool(String key) async {
    final current = await getBool(key) ?? false;
    await setBool(key, !current);
  }

  // Batch operations
  Future<void> setBatch(Map<String, dynamic> data) async {
    await initialize();
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is String) {
        await _prefs!.setString(key, value);
      } else if (value is int) {
        await _prefs!.setInt(key, value);
      } else if (value is bool) {
        await _prefs!.setBool(key, value);
      } else if (value is double) {
        await _prefs!.setDouble(key, value);
      } else if (value is List<String>) {
        await _prefs!.setStringList(key, value);
      }
    }
  }

  Future<Map<String, dynamic>> getBatch(List<String> keys) async {
    await initialize();
    final result = <String, dynamic>{};
    
    for (final key in keys) {
      final value = _prefs!.get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    
    return result;
  }
}
