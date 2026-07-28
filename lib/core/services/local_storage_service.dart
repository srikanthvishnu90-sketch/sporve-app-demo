import 'package:get_storage/get_storage.dart';

class LocalStorageService {
  static final GetStorage _box = GetStorage();

  static String? getCache(String key) {
    return _box.read<String>('cache_$key');
  }

  static Future<void> saveCache(String key, String data) async {
    await _box.write('cache_$key', data);
  }

  static Future<void> clearCache() async {
    // Clear all keys starting with cache_
    final keys = _box.getKeys();
    for (final key in keys) {
      if (key.startsWith('cache_')) {
        await _box.remove(key);
      }
    }
  }
}
